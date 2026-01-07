import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../core/providers/auth_provider.dart';
import '../../core/services/profile_service.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

/// Pantalla de perfil del usuario completamente editable.
/// 
/// Permite:
/// - Editar foto de perfil (galería o cámara)
/// - Editar nombre
/// - Editar celular
/// - Ver correo (solo lectura)
/// - Cambiar contraseña
/// - Configurar alertas (sonido)
/// - Cerrar sesión
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _photoPath;
  String? _name;
  String? _phone;
  bool _notificationsSound = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // Cargar datos guardados localmente
    final savedName = await ProfileService().getName();
    final savedPhone = await ProfileService().getPhone();
    final savedPhotoPath = await ProfileService().getPhotoPath();
    final savedNotificationsSound = await ProfileService().getNotificationsSound();

    setState(() {
      _name = savedName ?? user?.nombre ?? 'Usuario';
      _phone = savedPhone ?? '';
      _photoPath = savedPhotoPath;
      _notificationsSound = savedNotificationsSound;
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Solicitar permisos antes de usar ImagePicker
      PermissionStatus permissionStatus;
      
      if (source == ImageSource.camera) {
        permissionStatus = await Permission.camera.request();
        if (!permissionStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se requiere permiso de cámara para tomar fotos'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      } else {
        // Para galería, verificar permisos de almacenamiento según la versión de Android
        if (await Permission.photos.isGranted || 
            await Permission.storage.isGranted ||
            await Permission.mediaLibrary.isGranted) {
          permissionStatus = PermissionStatus.granted;
        } else {
          // Intentar solicitar permisos
          if (await Permission.photos.request().isGranted ||
              await Permission.storage.request().isGranted ||
              await Permission.mediaLibrary.request().isGranted) {
            permissionStatus = PermissionStatus.granted;
          } else {
            permissionStatus = PermissionStatus.denied;
          }
        }
        
        if (!permissionStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se requiere permiso de almacenamiento para acceder a la galería'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _photoPath = image.path;
        });
        await ProfileService().savePhotoPath(_photoPath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil actualizada'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      // Si el usuario cancela, no hacer nada (no es un error)
    } on Exception catch (e) {
      // Manejar errores específicos
      if (mounted) {
        String errorMessage = 'Error al seleccionar imagen';
        if (e.toString().contains('camera') || e.toString().contains('Camera')) {
          errorMessage = 'Error al acceder a la cámara';
        } else if (e.toString().contains('storage') || e.toString().contains('gallery')) {
          errorMessage = 'Error al acceder a la galería';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Manejar cualquier otro error (incluyendo cancelación del usuario)
      // No mostrar error si el usuario simplemente canceló
      if (mounted && !e.toString().contains('cancel') && !e.toString().contains('Cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showImagePickerDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFD32F2F)),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFD32F2F)),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _photoPath = null;
                  });
                  ProfileService().savePhotoPath(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Editar Nombre',
        initialValue: _name ?? '',
        hintText: 'Ingrese su nombre',
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _name = result;
      });
      await ProfileService().saveName(result);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nombre actualizado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _editPhone() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Editar Celular',
        initialValue: _phone ?? '',
        hintText: 'Ingrese su número de celular',
        keyboardType: TextInputType.phone,
      ),
    );

    if (result != null) {
      setState(() {
        _phone = result;
      });
      await ProfileService().savePhone(result);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Celular actualizado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleNotificationsSound(bool value) async {
    setState(() {
      _notificationsSound = value;
    });
    await ProfileService().saveNotificationsSound(value);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header con foto de perfil
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Foto de perfil editable
                  GestureDetector(
                    onTap: _showImagePickerDialog,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFFD32F2F),
                          backgroundImage: _photoPath != null
                              ? FileImage(File(_photoPath!))
                              : null,
                          child: _photoPath == null
                              ? Text(
                                  (_name ?? 'U').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        // Icono de cámara superpuesto
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD32F2F),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Nombre del usuario
                  Text(
                    _name ?? 'Usuario',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Correo electrónico (solo lectura)
                  Text(
                    user?.email ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Lista de opciones editables
            _buildEditableTile(
              icon: Icons.person,
              title: 'Nombre',
              subtitle: _name ?? 'No especificado',
              onTap: _editName,
            ),
            const Divider(height: 1, thickness: 0.5),
            _buildEditableTile(
              icon: Icons.phone,
              title: 'Celular',
              subtitle: _phone?.isNotEmpty == true ? _phone! : 'No especificado',
              onTap: _editPhone,
            ),
            const Divider(height: 1, thickness: 0.5),
            _buildReadOnlyTile(
              icon: Icons.email,
              title: 'Correo Electrónico',
              subtitle: user?.email ?? 'No disponible',
            ),

            const SizedBox(height: 24),

            // Opciones adicionales
            _buildSectionTitle('Configuración'),
            _buildSwitchTile(
              icon: Icons.notifications_active,
              title: 'Sonido de Notificaciones',
              subtitle: 'Activar o desactivar el sonido de las alertas',
              value: _notificationsSound,
              onChanged: _toggleNotificationsSound,
            ),
            const Divider(height: 1, thickness: 0.5),
            _buildActionTile(
              icon: Icons.lock,
              title: 'Cambiar Contraseña',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Botón de cerrar sesión
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFD32F2F), size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildReadOnlyTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600], size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFD32F2F), size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFD32F2F),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFD32F2F), size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Diálogo para editar campos de texto
class _EditFieldDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final TextInputType? keyboardType;

  const _EditFieldDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    this.keyboardType,
  });

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        keyboardType: widget.keyboardType,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text(
            'Guardar',
            style: TextStyle(color: Color(0xFFD32F2F)),
          ),
        ),
      ],
    );
  }
}
