import 'package:flutter/material.dart';
import '../../domain/models/device_model.dart';
import '../../core/services/coordinate_service.dart';

/// Widget que muestra las coordenadas válidas de un dispositivo.
/// 
/// Si las coordenadas actuales son 0.0, busca en el historial
/// el último registro válido.
class DeviceCoordinatesWidget extends StatefulWidget {
  final DeviceModel device;

  const DeviceCoordinatesWidget({
    super.key,
    required this.device,
  });

  @override
  State<DeviceCoordinatesWidget> createState() => _DeviceCoordinatesWidgetState();
}

class _DeviceCoordinatesWidgetState extends State<DeviceCoordinatesWidget> {
  double? _validLat;
  double? _validLng;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadValidCoordinates();
  }

  Future<void> _loadValidCoordinates() async {
    final coords = await CoordinateService.getValidCoordinates(
      widget.device.idDispositivo.toString(),
      widget.device.latitude,
      widget.device.longitude,
    );
    
    if (mounted) {
      setState(() {
        _validLat = coords['latitude'] as double;
        _validLng = coords['longitude'] as double;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Row(
        children: [
          const Icon(
            Icons.location_on,
            size: 16,
            color: Colors.red,
          ),
          const SizedBox(width: 4),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ],
      );
    }

    final lat = _validLat ?? widget.device.latitude;
    final lng = _validLng ?? widget.device.longitude;

    return Row(
      children: [
        const Icon(
          Icons.location_on,
          size: 16,
          color: Colors.red,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            lat == 0.0 && lng == 0.0
                ? 'Sin ubicación'
                : 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
