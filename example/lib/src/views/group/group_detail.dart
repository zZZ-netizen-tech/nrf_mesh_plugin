// filepath: example/lib/src/views/group/group_detail.dart
import 'package:flutter/material.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';

class GroupDetailPage extends StatefulWidget {
  final IMeshNetwork meshNetwork;
  final int groupAddress;

  const GroupDetailPage({super.key, required this.meshNetwork, required this.groupAddress});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  bool _loading = false;
  List<ElementData> _elements = [];
  final Map<int, String> _nodeNames = {}; // elementAddress -> node name

  @override
  void initState() {
    super.initState();
    _loadElements();
  }

  Future<void> _loadElements() async {
    setState(() {
      _loading = true;
      _elements = [];
      _nodeNames.clear();
    });

    try {
      final elements = await widget.meshNetwork.elementsForGroup(widget.groupAddress);
      setState(() {
        _elements = elements;
      });

      // Resolve node names concurrently
      await Future.wait(elements.map((e) async {
        try {
          final node = await widget.meshNetwork.getNode(e.address);
          if (node != null) {
            final name = await node.name;
            if (mounted) {
              setState(() {
                _nodeNames[e.address] = name;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _nodeNames[e.address] = e.name.isNotEmpty ? e.name : 'Unknown device';
              });
            }
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _nodeNames[e.address] = e.name.isNotEmpty ? e.name : 'Unknown device';
            });
          }
        }
      }));
    } catch (e) {
      debugPrint('Failed to load group elements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load group elements: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Group ${widget.groupAddress}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: _loadElements, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _elements.isEmpty
              ? const Center(child: Text('No devices subscribed to this group'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _elements.length,
                  itemBuilder: (c, i) {
                    final e = _elements[i];
                    final nodeName = _nodeNames[e.address] ?? (e.name.isNotEmpty ? e.name : 'Unknown device');
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nodeName, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text('Element address: ${e.address}'),
                            const SizedBox(height: 8),
                            if (e.models.isNotEmpty) ...[
                              const Text('Models:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: e.models.map((m) {
                                  final subs = (m.subscribedAddresses).map((a) => a.toString()).join(', ');
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text('${m.modelName} (0x${m.modelId.toRadixString(16)}) — subscribed: ${subs.isEmpty ? 'none' : subs}'),
                                  );
                                }).toList(),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
