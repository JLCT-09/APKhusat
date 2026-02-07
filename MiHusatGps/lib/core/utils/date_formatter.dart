import 'package:intl/intl.dart';

/// Helper centralizado para formateo de fechas y horas
/// 
/// Proporciona formatos consistentes en toda la aplicación
class DateFormatter {
  /// Formato de fecha corta: dd/MM/yyyy
  /// Ejemplo: "19/12/2024"
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Formato de fecha con año corto: dd/MM/yy
  /// Ejemplo: "19/12/24"
  static String formatDateShortYear(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  /// Formato de hora: HH:mm
  /// Ejemplo: "14:30"
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Formato de fecha y hora completa: dd/MM/yyyy HH:mm
  /// Ejemplo: "19/12/2024 14:30"
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  /// Formato de fecha y hora con segundos: dd/MM/yyyy HH:mm:ss
  /// Ejemplo: "19/12/2024 14:30:45"
  static String formatDateTimeWithSeconds(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
  }

  /// Formato de fecha larga: EEEE, dd 'de' MMMM 'de' yyyy
  /// Ejemplo: "jueves, 19 de diciembre de 2024"
  static String formatDateLong(DateTime date) {
    return DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'es_ES').format(date);
  }

  /// Formato relativo de tiempo (hace X minutos/horas/días)
  /// Ejemplo: "hace 5 minutos", "hace 2 horas", "hace 3 días"
  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'hace ${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else {
      return 'ahora';
    }
  }

  /// Formato ISO 8601 para almacenamiento o APIs
  /// Ejemplo: "2024-12-19T14:30:45.000Z"
  static String formatIso8601(DateTime date) {
    return DateFormat('yyyy-MM-ddTHH:mm:ss.SSSZ').format(date.toUtc());
  }
}
