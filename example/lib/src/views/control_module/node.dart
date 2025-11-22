import 'package:flutter/material.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';

import '../control_module/mesh_element.dart';

class Node extends StatefulWidget {
  final String name;
  final ProvisionedMeshNode node;
  final MeshManagerApi meshManagerApi;

  const Node({super.key, required this.node, required this.meshManagerApi, required this.name});

  @override
  State<Node> createState() => _NodeState();
}

class _NodeState extends State<Node> {
  bool isLoading = true;
  late int nodeAddress;
  late List<ElementData> elements;

  // full application keys info returned from native
  List<Map<String, dynamic>> _applicationKeys = [];
  bool _applicationKeysLoading = true;

  // network keys
  List<Map<String, dynamic>> _networkKeys = [];
  bool _networkKeysLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    nodeAddress = await widget.node.unicastAddress;
    elements = await widget.node.elements;

    // fetch application keys directly from the native node object
    try {
      final keys = await widget.node.applicationKeys;
      // keep full structured list for UI (normalize to Map)
      try {
        _applicationKeys = keys.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        _applicationKeys = [];
      }
    } catch (_) {
      _applicationKeys = [];
    } finally {
      if (mounted) {
        setState(() {
          _applicationKeysLoading = false;
          isLoading = false;
        });
      }
    }

    // fetch network keys directly from the native node object
    try {
      final keys = await widget.node.networkKeys;
      // ensure we have a List<Map<String, dynamic>>
      _networkKeys = keys.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _networkKeys = [];
    } finally {
      if (mounted) {
        setState(() {
          _networkKeysLoading = false;
        });
      }
    }

    // ensure UI updated if mounted
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(),
          Text('Configuring...'),
        ],
      ),
    );
    if (!isLoading) {
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        children: [
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
            child: ListTile(
              leading: const Icon(Icons.router),
              title: Text('Node address: $nodeAddress'),
              subtitle: Text(widget.node.uuid),
            ),
          ),
          const SizedBox(height: 6),

          // Application Keys section
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Application Keys', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_applicationKeysLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_applicationKeys.isEmpty)
                    const Text('No application keys', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _applicationKeys.map((k) {
                        final index = k['index'] is int ? k['index'] as int : (k['index'] is num ? (k['index'] as num).toInt() : null);
                        final name = (k['name'] is String && (k['name'] as String).isNotEmpty) ? k['name'] as String : null;
                        final bound = k['boundNetworkKeyIndex'];
                        final boundStr = (bound is int) ? ' bound:0x${bound.toRadixString(16).toUpperCase()}' : '';
                        final label = name != null ? '$name (0x${index != null ? index.toRadixString(16).toUpperCase() : '??'})$boundStr' : (index != null ? '0x${index.toRadixString(16).toUpperCase()}$boundStr' : 'Unknown');
                        return Chip(label: Text(label));
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),
          // Network Keys section
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Network Keys', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_networkKeysLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_networkKeys.isEmpty)
                    const Text('No network keys', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _networkKeys.map((k) {
                        final index = k['index'] is int ? k['index'] as int : (k['index'] is num ? (k['index'] as num).toInt() : null);
                        final name = (k['name'] is String && (k['name'] as String).isNotEmpty) ? k['name'] as String : null;
                        final label = name != null ? '$name (0x${index != null ? index.toRadixString(16).toUpperCase() : '??'})' : (index != null ? '0x${index.toRadixString(16).toUpperCase()}' : 'Unknown');
                        return Chip(label: Text(label));
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),
          // One section (card) per element
          ...elements.map((element) => MeshElement(element)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
      ),
      body: body,
    );
  }
}
