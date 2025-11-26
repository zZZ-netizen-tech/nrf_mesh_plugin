import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';
import 'package:nordic_nrf_mesh_example/src/views/control_module/module.dart'
    show DoozProvisionedBleMeshManagerCallbacks;
import 'package:nordic_nrf_mesh_example/src/services/global_mesh.dart';
import 'package:nordic_nrf_mesh_example/src/app.dart';

/// 页面：显示当前 mesh 网络下的已 provision 设备列表（支持多选）
class MeshDeviceListPage extends StatefulWidget {
  final IMeshNetwork meshNetwork;
  final int groupAddress;
  const MeshDeviceListPage({super.key, required this.meshNetwork, required this.groupAddress});

  @override
  State<MeshDeviceListPage> createState() => _MeshDeviceListPageState();
}

class _MeshDeviceListPageState extends State<MeshDeviceListPage> {
  // cached node entries
  List<_NodeEntry> _nodes = [];
  final Set<String> _selectedUuids = {}; // use uuid to identify nodes
  bool _loading = true;
  bool _processing = false;
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    // Ensure a GATT Proxy connection exists before loading nodes (config operations
    // require an active proxy). If none is connected, try to find and connect one.
    _ensureProxyConnected().whenComplete(() => _loadNodes());
  }

  @override
  void dispose() {
    // request cancel for any ongoing operations when leaving
    _cancelRequested = true;
    super.dispose();
  }

  Future<void> _loadNodes() async {
    setState(() {
      _loading = true;
      _nodes = [];
      _selectedUuids.clear();
    });
    try {
      final nodes = await widget.meshNetwork.nodes;

      final entries = nodes.map((n) => _NodeEntry(n)).toList();

      final nameFutures = nodes.map((n) => n.name.then<String?>((v) => v).catchError((_) => null)).toList();
      final addrFutures = nodes.map((n) => n.unicastAddress.then<int?>((v) => v).catchError((_) => null)).toList();

      final names = await Future.wait<String?>(nameFutures);
      final addrs = await Future.wait<int?>(addrFutures);

      for (var i = 0; i < entries.length; i++) {
        entries[i].name = names[i];
        entries[i].address = addrs[i];
      }

      setState(() {
        _nodes = entries;
        _selectedUuids.clear();
      });
    } catch (e) {
      debugPrint('Failed to load nodes: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载设备失败：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ensure there is a connected GATT Proxy. If not, scan for proxy-capable
  /// devices belonging to the currently loaded mesh network and connect one.
  Future<void> _ensureProxyConnected() async {
    try {
      final bleMeshManager = BleMeshManager();
      // If already connected to a proxy, nothing to do
      if (bleMeshManager.device != null && bleMeshManager.isProvisioningCompleted) {
        return;
      }

      // Need permissions to scan/connect
      await checkAndAskPermissions();

      final api = nordicNrfMesh.meshManagerApi;
      if (api.meshNetwork == null) return;

      // ensure callbacks are set so BleMeshManager.connect won't throw
      try {
        bleMeshManager.callbacks = DoozProvisionedBleMeshManagerCallbacks(api, bleMeshManager);
      } catch (e) {
        debugPrint('Failed to set bleMeshManager callbacks: $e');
      }

      // Scan for proxy advertisers and pick the first that belongs to our network
      final completer = Completer<void>();
      StreamSubscription<DiscoveredDevice>? sub;
      sub = nordicNrfMesh.scanForProxy().listen((device) async {
        try {
          debugPrint('Discovered proxy device: ${device.id}, rssi: ${device.rssi}');
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
            belongsToCurrent = await api.networkIdMatches(typed);
          } catch (e) {
            debugPrint('networkIdMatches call failed: $e');
            belongsToCurrent = false;
          }
          if (!belongsToCurrent) return;

          // Found a candidate for our network. Stop scanning and attempt connect.
          await sub?.cancel();
          try {
            debugPrint('Attempting to connect to proxy device ${device.id}');
            await bleMeshManager.connect(device);
            // connect() completes after GATT init
            if (!completer.isCompleted) completer.complete();
          } catch (e) {
            debugPrint('Failed to connect to proxy device ${device.id}: $e');
            if (!completer.isCompleted) completer.complete();
          }
        } catch (e) {
          debugPrint('Error while scanning for proxy: $e');
        }
      });

      // Stop scanning after timeout if nothing found
      Future.delayed(const Duration(seconds: 10), () async {
        await sub?.cancel();
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;
    } catch (e) {
      debugPrint('ensureProxyConnected error: $e');
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedUuids.length == _nodes.length) {
        _selectedUuids.clear();
      } else {
        _selectedUuids.clear();
        for (final n in _nodes) _selectedUuids.add(n.node.uuid);
      }
    });
  }

  void _toggleSelected(String uuid) {
    setState(() {
      if (_selectedUuids.contains(uuid))
        _selectedUuids.remove(uuid);
      else
        _selectedUuids.add(uuid);
    });
  }

  Future<void> _addSelectedToGroup() async {
    if (_processing) return;
    setState(() => _processing = true);
    final api = nordicNrfMesh.meshManagerApi;
    int success = 0;
    int fail = 0;
    final List<String> errors = [];

    try {
      if (api.meshNetwork == null) throw Exception('Mesh network not loaded');

      nodeLoop:
      for (final uuid in List<String>.from(_selectedUuids)) {
        if (_cancelRequested) break nodeLoop;
        _NodeEntry? entry;
        try {
          entry = _nodes.firstWhere((e) => e.node.uuid == uuid);
        } catch (_) {
          entry = null;
        }
        if (entry == null) {
          fail++;
          errors.add('Node not found: $uuid');
          continue;
        }
        try {
          final node = entry.node;
          final elements = await node.elements;
          for (final el in elements) {
            if (_cancelRequested) break nodeLoop;
            final addr = el.address;
            for (final m in el.models) {
              if (_cancelRequested) break nodeLoop;
              try {
                final status = await api
                    .sendConfigModelSubscriptionAdd(addr, widget.groupAddress, m.modelId)
                    .timeout(const Duration(seconds: 12));
                if (_cancelRequested) {
                  // ignore result if canceled
                  break nodeLoop;
                }
                if (status.subscriptionAddress == widget.groupAddress) {
                  success++;
                } else {
                  fail++;
                  errors.add('Subscribe rejected for model ${m.modelId} on element 0x${addr.toRadixString(16)}');
                }
              } catch (e) {
                if (_cancelRequested) {
                  break nodeLoop;
                }
                fail++;
                errors.add(e.toString());
              }
            }
          }
        } catch (e) {
          if (_cancelRequested) break nodeLoop;
          fail++;
          errors.add('Failed node ${uuid}: $e');
        }
      }
    } catch (e) {
      errors.add(e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
      if (_cancelRequested) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作已取消')));
        debugPrint('Add to group cancelled by user');
      } else {
        final msg = '完成：成功 $success，失败 $fail';
        if (errors.isNotEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg（部分错误，请查看日志）')));
          debugPrint('Add to group errors: ${errors.join("; ")}');
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备列表')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _nodes.isEmpty
              ? const Center(child: Text('无已配置设备'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88), // leave space for bottom bar
                  itemCount: _nodes.length,
                  itemBuilder: (context, index) {
                    final entry = _nodes[index];
                    final node = entry.node;
                    final selected = _selectedUuids.contains(node.uuid);
                    final nameText = entry.name ?? 'Unnamed';
                    final addrText = entry.address != null ? '地址: ${entry.address}' : '地址未知';
                    return ListTile(
                      leading: Checkbox(value: selected, onChanged: (_) => _toggleSelected(node.uuid)),
                      title: Text(nameText),
                      subtitle: Text(addrText),
                      trailing: const Icon(Icons.devices),
                      onTap: () => _toggleSelected(node.uuid),
                      onLongPress: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设备详情未实现')));
                      },
                    );
                  },
                ),
      // Bottom bar covers the full safe area (extends into system inset) so
      // the page background is not visible under the bar.
      bottomSheet: Container(
        // ensure background fills into the bottom inset
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SizedBox(
          height: 56 + MediaQuery.of(context).viewPadding.bottom,
          child: Container(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).viewPadding.bottom),
            decoration: BoxDecoration(boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))
            ]),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _nodes.isEmpty ? null : _toggleSelectAll,
                  icon: Icon(
                    _selectedUuids.length == _nodes.length && _nodes.isNotEmpty
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                  label: Text(_selectedUuids.length == _nodes.length && _nodes.isNotEmpty ? '取消全选' : '全选'),
                ),
                const SizedBox(width: 12),
                // selection counter: selected / total
                Text('${_selectedUuids.length}/${_nodes.length}', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                _processing
                    ? const SizedBox(width: 120, height: 36, child: Center(child: CircularProgressIndicator()))
                    : ElevatedButton.icon(
                        onPressed: _selectedUuids.isEmpty
                            ? null
                            : () async {
                                await _addSelectedToGroup();
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('添加'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeEntry {
  final ProvisionedMeshNode node;
  String? name;
  int? address;

  _NodeEntry(this.node);
}
