import 'package:flutter/foundation.dart';

/// Provider para compartir el estado del filtro de supervisión entre MapScreen y DevicesScreen
/// 
/// Permite que cuando un admin seleccione un usuario en el Monitor,
/// automáticamente la lista de dispositivos también muestre solo los dispositivos de ese usuario.
class SupervisionFilterProvider with ChangeNotifier {
  int? _usuarioFiltroId;
  String? _usuarioFiltroNombre;

  /// ID del usuario objetivo para el filtro de supervisión
  /// null = ver mis propios dispositivos
  int? get usuarioFiltroId => _usuarioFiltroId;

  /// Nombre del usuario objetivo para mostrar en el banner
  String? get usuarioFiltroNombre => _usuarioFiltroNombre;

  /// Indica si hay un filtro activo
  bool get tieneFiltroActivo => _usuarioFiltroId != null;

  /// Establece el filtro de supervisión
  /// 
  /// [usuarioId] - ID del usuario objetivo (null para ver mis dispositivos)
  /// [nombreUsuario] - Nombre del usuario objetivo para mostrar en el banner
  void setFiltroUsuario(int? usuarioId, String? nombreUsuario) {
    if (_usuarioFiltroId != usuarioId || _usuarioFiltroNombre != nombreUsuario) {
      _usuarioFiltroId = usuarioId;
      _usuarioFiltroNombre = nombreUsuario;
      debugPrint('🔄 SupervisionFilterProvider: Filtro actualizado - Usuario ID: $usuarioId, Nombre: $nombreUsuario');
      notifyListeners();
    }
  }

  /// Limpia el filtro (vuelve a ver mis dispositivos)
  void limpiarFiltro() {
    if (_usuarioFiltroId != null || _usuarioFiltroNombre != null) {
      _usuarioFiltroId = null;
      _usuarioFiltroNombre = null;
      debugPrint('🔄 SupervisionFilterProvider: Filtro limpiado');
      notifyListeners();
    }
  }
}
