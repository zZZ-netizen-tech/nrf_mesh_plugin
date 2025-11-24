import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';

class SendGenericLevel extends StatefulWidget {
  final MeshManagerApi meshManagerApi;

  const SendGenericLevel({super.key, required this.meshManagerApi});

  @override
  State<SendGenericLevel> createState() => _SendGenericLevelState();
}

class _SendGenericLevelState extends State<SendGenericLevel> {
  int? selectedElementAddress;

  // use a non-nullable int for slider value (default 0)
  int selectedLevel = 0;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const ValueKey('module-send-generic-level-form'),
      title: const Text('Send a generic level set'),
      children: <Widget>[
        TextField(
          key: const ValueKey('module-send-generic-level-address'),
          decoration: const InputDecoration(hintText: 'Element Address'),
          onChanged: (text) {
            // safe parse
            final v = int.tryParse(text);
            selectedElementAddress = v;
          },
        ),
        // Slider instead of manual input for Level Value
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level Value: $selectedLevel', style: const TextStyle(fontSize: 14)),
              Slider(
                value: selectedLevel.toDouble(),
                min: -32768.0,
                max: 32767.0,
                // no divisions to keep slider smooth; we round to int when updating
                onChanged: (double v) {
                  setState(() {
                    selectedLevel = v.round();
                  });
                },
              ),
            ],
          ),
        ),
        TextButton(
          // enable when address is provided (level always has a default)
          onPressed: selectedElementAddress != null
              ? () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  debugPrint('send level $selectedLevel to $selectedElementAddress');
                  try {
                    await widget.meshManagerApi
                        .sendGenericLevelSet(selectedElementAddress!, selectedLevel,ack:true)
                        .timeout(const Duration(seconds: 40));
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('OK')));
                  } on TimeoutException catch (_) {
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Board didn\'t respond')));
                  } on PlatformException catch (e) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('${e.message}')));
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              : null,
          child: const Text('Send level'),
        )
      ],
    );
  }
}
