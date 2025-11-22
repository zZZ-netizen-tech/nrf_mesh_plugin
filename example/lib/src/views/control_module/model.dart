import 'package:flutter/material.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';

class Model extends StatelessWidget {
  final ModelData model;

  const Model(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final modelHex = '0x${model.modelId.toRadixString(16).toUpperCase()}';
    final bound = isAppKeyBound();

    return Tooltip(
      message: bound ? 'Bound app keys: ${model.boundAppKey.length}' : 'No app key bound',
      child: Chip(
        backgroundColor: bound ? Colors.green.shade50 : Colors.grey.shade100,
        avatar: CircleAvatar(
          backgroundColor: bound ? Colors.green.shade300 : Colors.grey.shade400,
          child: const Icon(
            Icons.memory,
            size: 16,
            color: Colors.white,
          ),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              modelHex,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 6),
            Icon(
              bound ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: bound ? Colors.green : Colors.grey,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      ),
    );
  }

  bool isAppKeyBound() {
    return model.boundAppKey.isNotEmpty;
  }
  Icon appKeyBindIcon() {
    return isAppKeyBound()
        ? const Icon(
            Icons.check,
            size: 15,
            color: Colors.green,
          )
        : const Icon(
            Icons.clear,
            size: 15,
            color: Colors.red,
          );
  }
}
