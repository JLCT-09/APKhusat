import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/storage_service.dart';
import '../../core/services/profile_service.dart';
import '../../data/user_service.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

/// Pantalla de perfil del usuario con diseño fiel a la referencia.
/// 
/// Muestra:
/// - Header con avatar, nombre y username
/// - Lista de información (Nombre, Celular, Correo)
/// - Sección de configuración (Sonido de Notificaciones, Cambiar Contraseña)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _notificationsSound = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadNotificationsSound();
  }

  /// Carga la preferencia de sonido de notificaciones
  Future<void> _loadNotificationsSound() async {
    final soundEnabled = await ProfileService().getNotificationsSound();
    setState(() {
      _notificationsSound = soundEnabled;
    });
  }

  /// Carga los datos del usuario desde la API
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtener ID del usuario logueado
      final userId = await StorageService.getUserId();
      
      if (userId == null || userId.isEmpty) {
        throw Exception('Usuario no autenticado');
      }

      // Cargar datos desde la API
      final profile = await UserService.obtenerUsuario(userId);
      
      if (profile == null) {
        throw Exception('No se pudieron cargar los datos del usuario');
      }

      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar perfil: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Obtiene el username del usuario (email sin dominio o nombre de usuario)
  String _getUsername() {
    if (_userProfile == null) return '';
    // Extraer username del email (parte antes del @)
    if (_userProfile!.email.isNotEmpty && _userProfile!.email.contains('@')) {
      return _userProfile!.email.split('@')[0];
    }
    // Si no hay email, usar nombre completo en minúsculas sin espacios
    return _userProfile!.nombreCompleto.toLowerCase().replaceAll(' ', '');
  }

  /// Obtiene la inicial del nombre para el avatar
  String _getInitial() {
    if (_userProfile == null || _userProfile!.nombreCompleto.isEmpty) {
      return 'U';
    }
    return _userProfile!.nombreCompleto[0].toUpperCase();
  }

  /// Edita el nombre del usuario
  Future<void> _editName() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Editar Nombre',
        initialValue: _userProfile?.nombreCompleto ?? '',
        hintText: 'Ingrese su nombre completo',
      ),
    );

    if (result != null && result.isNotEmpty) {
      // TODO: Llamar a API para actualizar nombre
      // Por ahora, solo guardar localmente
      await ProfileService().saveName(result);
      
      setState(() {
        _userProfile = UserProfile(
          nombreCompleto: result,
          email: _userProfile?.email ?? '',
          telefono: _userProfile?.telefono ?? '',
        );
      });
      
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

  /// Edita el celular del usuario
  Future<void> _editPhone() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Editar Celular',
        initialValue: _userProfile?.telefono ?? '',
        hintText: 'Ingrese su número de celular',
        keyboardType: TextInputType.phone,
      ),
    );

    if (result != null) {
      // TODO: Llamar a API para actualizar teléfono
      // Por ahora, solo guardar localmente
      await ProfileService().savePhone(result);
      
      setState(() {
        _userProfile = UserProfile(
          nombreCompleto: _userProfile?.nombreCompleto ?? '',
          email: _userProfile?.email ?? '',
          telefono: result,
        );
      });
      
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

  /// Toggle del sonido de notificaciones
  Future<void> _toggleNotificationsSound(bool value) async {
    setState(() {
      _notificationsSound = value;
    });
    await ProfileService().saveNotificationsSound(value);
  }

  /// Cierra sesión y regresa al LoginScreen
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
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Limpiar StorageService
      await StorageService.clearToken();
      await StorageService.clearUserId();
      await StorageService.clearUserRole();
      await StorageService.clearNombreCompleto();
      
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF1A2D)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar perfil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadUserProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF1A2D),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _userProfile == null
                  ? const Center(
                      child: Text('No hay datos disponibles'),
                    )
                  : SafeArea(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          // Header con Avatar, Nombre y Username
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), // Más espacio arriba
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
                                // Avatar con icono de cámara
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundColor: const Color(0xFFEF1A2D),
                                      child: Text(
                                        _getInitial(),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    // Icono de cámara en esquina inferior derecha
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF1A2D),
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
                                const SizedBox(height: 16),
                                // Nombre Principal
                                Text(
                                  _userProfile!.nombreCompleto,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Username
                                Text(
                                  _getUsername(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Lista de Información
                          _buildEditableTile(
                            icon: Icons.person,
                            iconColor: const Color(0xFFEF1A2D),
                            title: 'Nombre',
                            subtitle: _userProfile!.nombreCompleto,
                            onTap: _editName,
                          ),
                          const Divider(height: 1, thickness: 0.8), // Aumentado de 0.5 a 0.8
                          _buildEditableTile(
                            icon: Icons.phone,
                            iconColor: const Color(0xFFEF1A2D),
                            title: 'Celular',
                            subtitle: _userProfile!.telefono.isNotEmpty 
                                ? _userProfile!.telefono 
                                : 'No especificado',
                            onTap: _editPhone,
                          ),
                          const Divider(height: 1, thickness: 0.8), // Aumentado de 0.5 a 0.8
                          _buildReadOnlyTile(
                            icon: Icons.email,
                            iconColor: Colors.grey[600]!,
                            title: 'Correo Electrónico',
                            subtitle: _userProfile!.email,
                          ),

                          const SizedBox(height: 24),

                          // Sección de Configuración
                          _buildSectionTitle('Configuración'),
                          _buildSwitchTile(
                            icon: Icons.notifications_active,
                            iconColor: const Color(0xFFEF1A2D),
                            title: 'Sonido de Notificaciones',
                            subtitle: 'Activar o desactivar el sonido de las alertas',
                            value: _notificationsSound,
                            onChanged: _toggleNotificationsSound,
                          ),
                          const Divider(height: 1, thickness: 0.8), // Aumentado de 0.5 a 0.8
                          _buildActionTile(
                            icon: Icons.lock,
                            iconColor: const Color(0xFFEF1A2D),
                            title: 'Cambiar Contraseña',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const ChangePasswordScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 32),

                          // Botón de Cerrar Sesión
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ElevatedButton.icon(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout, color: Colors.white),
                              label: const Text(
                                'Cerrar Sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF1A2D).withOpacity(0.9), // Color corporativo más suave
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4, // Aumentado de 2 a 4
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  /// Construye un tile editable con icono, título, subtítulo y flecha
  Widget _buildEditableTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  /// Construye un tile de solo lectura (sin flecha ni onTap)
  Widget _buildReadOnlyTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  /// Construye un tile con switch
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFEF1A2D),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  /// Construye un tile de acción (con flecha)
  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  /// Construye el título de sección
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15, // Aumentado de 14 a 15
          fontWeight: FontWeight.w700, // Aumentado de w600 a w700
          color: Colors.grey[800], // Más oscuro
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
            style: TextStyle(color: Color(0xFFEF1A2D)),
          ),
        ),
      ],
    );
  }
}
