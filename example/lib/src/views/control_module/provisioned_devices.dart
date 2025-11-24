import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';
import 'package:nordic_nrf_mesh_example/src/app.dart';
import 'package:nordic_nrf_mesh_example/src/views/control_module/module.dart';
import 'package:nordic_nrf_mesh_example/src/widgets/device.dart';
import 'package:nordic_nrf_mesh_example/src/views/control_module/node_view.dart';

class ProvisionedDevices extends StatefulWidget {
  final NordicNrfMesh nordicNrfMesh;

  const ProvisionedDevices({super.key, required this.nordicNrfMesh});

  @override
  State<ProvisionedDevices> createState() => _ProvisionedDevicesState();
}

class _ProvisionedDevicesState extends State<ProvisionedDevices> {
  late MeshManagerApi _meshManagerApi;
  final _devices = <DiscoveredDevice>{};
  bool isScanning = false;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  DiscoveredDevice? _device;

  @override
  void initState() {
    super.initState();
    _meshManagerApi = widget.nordicNrfMesh.meshManagerApi;
    _scanProvisionned();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isScanning) const LinearProgressIndicator(),
        if (_device == null) ...[
          if (!isScanning && _devices.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No module found'),
              ),
            ),
          if (_devices.isNotEmpty)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  for (var i = 0; i < _devices.length; i++)
                    Device(
                      // use a stable key so Flutter can correctly preserve/recreate widgets
                      key: ValueKey(_devices.elementAt(i).id),
                      device: _devices.elementAt(i),
                      onTap: () async {
                        final selected = _devices.elementAt(i);
                        // stop scanning and update state so UI shows the Module
                        await _stopScan();
                        if (!mounted) {
                          debugPrint('onTap: widget not mounted after stopScan');
                          return;
                        }
                        setState(() {
                          _device = selected;
                        });
                        // return early: we intentionally stop here to let UI switch to Module
                        return;
                        final bleMeshManager = BleMeshManager();
                        final device = _devices.elementAt(i);

                        // 显示连接进度
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          await bleMeshManager.connect(device);
                          Navigator.of(context).pop(); // 关闭进度弹窗

                          // 构造 Node 对象（根据你的 node_view.dart 需求调整参数）
                          final node = Node(
                            name: device.name.isEmpty ? device.id : device.name,
                            primaryUnicastAddress: 1, // 这里用占位，实际可从 meshManagerApi 获取
                          );

                          // 跳转到 NodeViewPage
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => NodeViewPage(node: node)),
                          );

                          // 返回后断开连接
                          await bleMeshManager.disconnect();
                        } catch (e) {
                          Navigator.of(context).pop(); // 关闭进度弹窗
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('连接失败: $e')),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
        ] else
          Expanded(
            child: Module(
                key: ValueKey(_device!.id),
                device: _device!,
                meshManagerApi: _meshManagerApi,
                onDisconnect: () {
                  // clear the selected device and restart scanning
                  setState(() {
                    _device = null;
                  });
                  _scanProvisionned();
                }),
          ),
      ],
    );
  }

  Future<void> _scanProvisionned() async {
    setState(() {
      _devices.clear();
    });
    await checkAndAskPermissions();

    _scanSubscription = widget.nordicNrfMesh.scanForProxy().listen((device) async {
      final sd = device.serviceData;

      // 找到对应的 Mesh Proxy service data bytes
      // Prefer exact meshProxyUuid match if the map keys use Uuid, otherwise fallback to '1828' substring.
      dynamic proxyKey;
      if (sd.containsKey(meshProxyUuid)) {
        proxyKey = meshProxyUuid;
      } else {
        for (final k in sd.keys) {
          if (k.toString().toLowerCase().contains('1828')) {
            proxyKey = k;
            break;
          }
        }
      }
      if (proxyKey == null) return;

      final Uint8List? raw = sd[proxyKey];

      bool belongsToCurrent = false;
      try {
        // Ensure we pass typed Uint8List so platform (Pigeon/Swift) decodes the bytes correctly
        final typed = Uint8List.fromList(raw!);
        belongsToCurrent = await _meshManagerApi.networkIdMatches(typed);
      } catch (e) {
        debugPrint('networkIdMatches call failed: $e');
        belongsToCurrent = false;
      }
      if (!belongsToCurrent) return;

      if (_devices.every((d) => d.id != device.id)) {
        setState(() {
          _devices.add(device);
        });
      }
    });
    setState(() {
      isScanning = true;
    });
    return Future.delayed(const Duration(seconds: 10), _stopScan);
  }

  Future<void> _stopScan() async {
    await _scanSubscription?.cancel();
    isScanning = false;
    if (mounted) {
      setState(() {});
    }
  }
}
