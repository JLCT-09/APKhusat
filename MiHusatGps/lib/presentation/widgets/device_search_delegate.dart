import 'package:flutter/material.dart';
import '../../domain/models/device_model.dart';

/// Delegate para búsqueda de dispositivos usando showSearch
class DeviceSearchDelegate extends SearchDelegate<DeviceModel?> {
  final List<DeviceModel> devices;

  DeviceSearchDelegate({required this.devices});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildRecentDevices(context);
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final filteredDevices = devices.where((device) {
      final searchLower = query.toLowerCase();
      final placa = (device.placa ?? '').toLowerCase();
      final nombre = device.nombre.toLowerCase();
      final imei = (device.imei ?? '').toLowerCase();

      return placa.contains(searchLower) ||
          nombre.contains(searchLower) ||
          imei.contains(searchLower);
    }).toList();

    if (filteredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron dispositivos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intente con otro término de búsqueda',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredDevices.length,
      itemBuilder: (context, index) {
        final device = filteredDevices[index];
        return ListTile(
          leading: Icon(
            device.iconoVehiculo,
            color: _getStatusColor(device),
            size: 32,
          ),
          title: Text(
            device.placa ?? device.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (device.imei != null) Text('IMEI: ${device.imei}'),
              Text(
                _getStatusText(device),
                style: TextStyle(
                  color: _getStatusColor(device),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
          onTap: () {
            close(context, device);
          },
        );
      },
    );
  }

  Widget _buildRecentDevices(BuildContext context) {
    // Mostrar los primeros 5 dispositivos como sugerencias
    final recentDevices = devices.take(5).toList();

    if (recentDevices.isEmpty) {
      return const Center(
        child: Text('No hay dispositivos disponibles'),
      );
    }

    return ListView.builder(
      itemCount: recentDevices.length,
      itemBuilder: (context, index) {
        final device = recentDevices[index];
        return ListTile(
          leading: Icon(
            device.iconoVehiculo,
            color: _getStatusColor(device),
            size: 32,
          ),
          title: Text(
            device.placa ?? device.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            _getStatusText(device),
            style: TextStyle(
              color: _getStatusColor(device),
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
          onTap: () {
            close(context, device);
          },
        );
      },
    );
  }

  Color _getStatusColor(DeviceModel device) {
    final codigoEstado = device.codigoEstadoOperativo;
    if (codigoEstado == 'OPER_EN_MOVIMIENTO') {
      return Colors.green;
    } else if (codigoEstado == 'OPER_ESTATICO') {
      return Colors.blue;
    } else if (codigoEstado == 'OPER_FUERA_DE_LINEA') {
      return Colors.grey;
    }
    // Fallback
    return device.movimiento == true ? Colors.green : Colors.blue;
  }

  String _getStatusText(DeviceModel device) {
    final codigoEstado = device.codigoEstadoOperativo;
    if (codigoEstado == 'OPER_EN_MOVIMIENTO') {
      return 'EN MOVIMIENTO';
    } else if (codigoEstado == 'OPER_ESTATICO') {
      return 'ESTACIONADO';
    } else if (codigoEstado == 'OPER_FUERA_DE_LINEA') {
      return 'DESCONECTADO';
    }
    // Fallback
    return device.movimiento == true ? 'EN MOVIMIENTO' : 'DETENIDO';
  }
}
