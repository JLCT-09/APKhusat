import 'package:flutter/foundation.dart';
import '../../domain/models/user.dart';
import '../../data/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String usuario, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(usuario, password);
      
      if (user != null) {
        _user = user;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = 'Error de comunicación con Husat';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      // Extraer código de error si está disponible
      String mensajeError = 'Error de comunicación con Husat';
      if (e.toString().contains('Código:')) {
        mensajeError = e.toString().replaceFirst('Exception: ', '');
      }
      _errorMessage = mensajeError;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    
    _user = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
