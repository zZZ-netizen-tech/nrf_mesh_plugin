// dart
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class Device extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback? onTap;

  const Device({Key? key, required this.device, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = (device.name.isNotEmpty) ? device.name : 'Unknown';
    final id = device.id;
    final rssiText = (device.rssi != null) ? '${device.rssi} dBm' : 'N/A';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              id,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [

                Text(
                  rssiText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

