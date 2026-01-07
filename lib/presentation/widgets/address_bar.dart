import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

/// Barra que muestra la dirección actual del vehículo usando reverse geocoding.
class AddressBar extends StatefulWidget {
  final double latitude;
  final double longitude;

  const AddressBar({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  String _address = 'Cargando dirección...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void didUpdateWidget(AddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude) {
      _loadAddress();
    }
  }

  Future<void> _loadAddress() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _address = 'Buscando calle...';
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.latitude,
        widget.longitude,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final street = place.street ?? '';
        final thoroughfare = place.thoroughfare ?? '';
        final subThoroughfare = place.subThoroughfare ?? '';
        
        String address = '';
        if (street.isNotEmpty) {
          address = street;
        } else if (thoroughfare.isNotEmpty) {
          address = thoroughfare;
          if (subThoroughfare.isNotEmpty) {
            address = '$subThoroughfare $address';
          }
        } else {
          address = 'Ubicación desconocida';
        }

        setState(() {
          _address = address;
          _isLoading = false;
        });
      } else {
        setState(() {
          _address = 'Dirección no disponible';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      // Solo mostrar error si no es un timeout (que ya se maneja)
      setState(() {
        _address = 'Dirección no disponible';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
