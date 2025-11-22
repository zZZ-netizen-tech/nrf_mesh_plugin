// dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';
import 'package:nordic_nrf_mesh_example/src/services/global_mesh.dart';

class ModelDetailPage extends StatefulWidget {
  final ModelData model;
  final ElementData element;

  const ModelDetailPage({super.key, required this.model, required this.element});

  @override
  State<ModelDetailPage> createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  late List<int> _boundKeys;
  late List<int> _subscriptions;
  // map appKeyIndex -> name (if available)
  Map<int, String> _appKeyNames = {};
  // current publication(s) for this model/element (usually at most one)
  List<ConfigModelPublicationStatus> _publications = [];
  // indicates an ongoing update to publication settings
  bool _updatingPublication = false;

  MeshManagerApi get _meshApi => nordicNrfMesh.meshManagerApi;

  @override
  void initState() {
    super.initState();
    _boundKeys = List<int>.from(widget.model.boundAppKey);
    _subscriptions = List<int>.from(widget.model.subscribedAddresses);
    // load current publication settings
    _refreshPublications();
    // load app key names for display
    _loadAppKeyNames();
  }

  Future<void> _loadAppKeyNames() async {
    try {
      final keys = await _fetchAvailableAppKeys();
      final Map<int, String> map = {};
      for (final k in keys) {
        final idx = (k['keyIndex'] is int) ? (k['keyIndex'] as int) : int.tryParse(k['keyIndex'].toString()) ?? -1;
        final name = (k['name'] as String?) ?? '';
        if (idx >= 0) map[idx] = name;
      }
      if (mounted) setState(() => _appKeyNames = map);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshPublications() async {
    try {
      final api = _meshApi;
      if (api.meshNetwork == null) {
        if (mounted) setState(() => _publications = []);
        return;
      }
      final status = await api.getPublicationSettings(widget.element.address, widget.model.modelId);
      // The API returns a default status with publishAddress == -1 when no publication is set
      if (status.publishAddress != -1 && status.modelIdentifier == widget.model.modelId) {
        if (mounted) setState(() => _publications = [status]);
      } else {
        if (mounted) setState(() => _publications = []);
      }
    } catch (_) {
      if (mounted) setState(() => _publications = []);
    }
  }

  String _toHex(dynamic v) {
    if (v == null) return '—';
    if (v is int) return '0x${v.toRadixString(16).toUpperCase()}';
    try {
      final parsed = int.parse(v.toString());
      return '0x${parsed.toRadixString(16).toUpperCase()}';
    } catch (_) {
      return v.toString();
    }
  }

  List<Widget> _buildChips(List items) {
    if (items.isEmpty) {
      return [const Text('None', style: TextStyle(color: Colors.grey))];
    }
    return items.map<Widget>((it) {
      final label = _toHex(it);
      return Padding(
        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
        child: Chip(label: Text(label)),
      );
    }).toList();
  }

  List<Widget> _buildAppKeyChips(List<int> items) {
    if (items.isEmpty) {
      return [const Text('None', style: TextStyle(color: Colors.grey))];
    }
    return items.map<Widget>((it) {
      final name = (_appKeyNames[it] ?? '').trim();
      final displayName = name.isNotEmpty ? name : 'AppKey';
      return Padding(
        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: it.toString()));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied appKeyIndex: $it')));
          },
          child: ChoiceChip(
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(_toHex(it), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            selected: false,
            onSelected: (_) {},
          ),
        ),
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableAppKeys() async {
    try {
      final api = _meshApi;
      final network = api.meshNetwork;
      if (network == null) return <Map<String, dynamic>>[];
      final keys = await network.appKeys; // now returns List<Map{name, keyIndex}>
      // ensure compatibility: convert ints to maps if needed
      if (keys.isNotEmpty && keys.first is int) {
        return (keys as List).map<Map<String, dynamic>>((e) => {'name': '', 'keyIndex': e as int}).toList();
      }
      return List<Map<String, dynamic>>.from(keys);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _refreshBoundKeys() async {
    try {
      final api = _meshApi;
      final network = api.meshNetwork;
      if (network == null) return;
      // find provisioner node that contains our element's unicast
      final nodes = await network.nodes;
      int? provUnicast;
      for (final n in nodes) {
        final elems = await n.elements;
        for (final e in elems) {
          if (e.address == widget.element.address) {
            provUnicast = await n.unicastAddress;
            break;
          }
        }
        if (provUnicast != null) break;
      }
      if (provUnicast == null) return;
      final provNode = await network.getNode(provUnicast);
      if (provNode == null) return;
      final elements = await provNode.elements;
      final updatedElem = elements.firstWhere((e) => e.address == widget.element.address, orElse: () => widget.element);
      final model = updatedElem.models.firstWhere((m) => m.modelId == widget.model.modelId, orElse: () => widget.model);
      if (mounted) {
        setState(() {
          _boundKeys = List<int>.from(model.boundAppKey);
          _subscriptions = List<int>.from(model.subscribedAddresses);
        });
        // refresh app key names after we've ensured network available
        _loadAppKeyNames();
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _showBindDialog(BuildContext context) async {
    final availableKeys = await _fetchAvailableAppKeys();

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BindAppKeySheet(
          availableKeys: availableKeys,
          elementAddress: widget.element.address,
          modelId: widget.model.modelId,
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    if (result['success'] == true) {
      await _refreshBoundKeys();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bound appKeyIndex: ${result['appKeyIndex']}')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bind failed: ${result['error'] ?? 'unknown'}')));
    }
  }

  Future<void> _showPublicationDialog(BuildContext context) async {
    final availableKeys = await _fetchAvailableAppKeys();

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _PublicationSheet(
          availableKeys: availableKeys,
          elementAddress: widget.element.address,
          modelId: widget.model.modelId,
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    if (result['success'] == true) {
      final addr = result['publishAddress'] as int?;
      await _refreshBoundKeys();
      await _refreshPublications();
      if (!mounted) return;
      if (addr != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publication set to: 0x${addr.toRadixString(16).toUpperCase()}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication set')));
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Set publication failed: ${result['error'] ?? 'unknown'}')));
    }
  }

  Future<void> _showSubscribeDialog(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SubscribeSheet(elementAddress: widget.element.address, modelId: widget.model.modelId),
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    if (result['success'] == true) {
      await _refreshBoundKeys();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subscribed to: 0x${(result['subscriptionAddress'] as int).toRadixString(16).toUpperCase()}')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subscribe failed: ${result['error'] ?? 'unknown'}')));
    }
  }

  // apply a change to an existing publication: only update the provided fields
  Future<void> _applyPublicationChange(
      ConfigModelPublicationStatus pub, {
        bool? credentialFlag,
        int? retransmitIntervalSteps,
      }) async {
    // can't update if no valid publish address
    if (pub.publishAddress == -1) return;
    setState(() => _updatingPublication = true);
    final api = _meshApi;
    try {
      if (api.meshNetwork == null) throw Exception('Mesh network not loaded');

      // prepare values: use existing pub fields unless overridden
      final int publishAddress = pub.publishAddress;
      final int appKeyIndex = pub.appKeyIndex;
      final bool cred = credentialFlag ?? pub.credentialFlag;
      final int publishTtl = pub.publishTtl;
      final int publicationSteps = pub.publicationSteps;
      final int publicationResolution = pub.publicationResolution;
      final int retransmitCount = pub.retransmitCount;
      final int retransmitInterval = retransmitIntervalSteps ?? pub.retransmitIntervalSteps;

      // call API: elementAddress, publishAddress, modelIdentifier
      final status = await api
          .sendConfigModelPublicationSet(
        widget.element.address,
        publishAddress,
        widget.model.modelId,
        appKeyIndex: appKeyIndex,
        credentialFlag: cred,
        publishTtl: publishTtl,
        publicationSteps: publicationSteps,
        publicationResolution: publicationResolution,
        retransmitCount: retransmitCount,
        retransmitIntervalSteps: retransmitInterval,
      )
          .timeout(const Duration(seconds: 12));
      final ok = status.publishAddress == publishAddress;

      if (mounted && ok == true) {
        Navigator.of(context).pop({
          'type': 'publication',
          'success': true,
          'publishAddress': publishAddress,
          'status': status,
        });
      }
      // refresh local publications and notify user
      await _refreshPublications();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update publication: $e')));
    } finally {
      if (mounted) setState(() => _updatingPublication = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelHex = _toHex(widget.model.modelId);
    final elementHex = _toHex(widget.element.address);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.model.modelName.isNotEmpty ? widget.model.modelName : modelHex),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBoundKeys,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Model: ${widget.model.modelName.isNotEmpty ? widget.model.modelName : modelHex}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Element: $elementHex'),
            const SizedBox(height: 16),
            const Text('Bound App Keys', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(children: _buildAppKeyChips(_boundKeys)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _showBindDialog(context), child: const Text('Bind AppKey')),
            const Divider(height: 32),
            const Text('Subscriptions', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(children: _buildChips(_subscriptions)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _showSubscribeDialog(context), child: const Text('Subscribe')),
            const Divider(height: 32),
            const Text('Publication', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () => _showPublicationDialog(context), child: const Text('Set Publication')),
            const SizedBox(height: 16),
            // display current publication status
            const Text('Current Publication', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_publications.isEmpty)
              const Text('No publication set', style: TextStyle(color: Colors.grey))
            else ...[
              for (final pub in _publications)
                StatefulBuilder(builder: (contextCard, setStateCard) {
                  // local interactive states for this card
                  bool localCred = pub.credentialFlag;
                  double localInterval = pub.retransmitIntervalSteps.clamp(0, 100).toDouble();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Publish Address: ${_toHex(pub.publishAddress)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: Text('App Key Index: ${pub.appKeyIndex}', style: const TextStyle(fontWeight: FontWeight.w500))),
                          Row(children: [
                            const Text('Credential'),
                            const SizedBox(width: 8),
                            // interactive switch: toggle applies change
                            Switch.adaptive(
                              value: localCred,
                              onChanged: _updatingPublication
                                  ? null
                                  : (v) async {
                                setStateCard(() => localCred = v);
                                await _applyPublicationChange(pub, credentialFlag: v);
                              },
                            ),
                          ]),
                        ]),
                        const SizedBox(height: 12),

                        const Text('Retransmit', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Count: ${pub.retransmitCount}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text('Interval: ${pub.retransmitIntervalSteps} steps', style: const TextStyle(fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 8),
                        // interactive slider: on change end applies update
                        Slider.adaptive(
                          value: localInterval,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: _updatingPublication
                              ? null
                              : (v) => setStateCard(() => localInterval = v),
                          onChangeEnd: _updatingPublication
                              ? null
                              : (v) async {
                            final int newVal = v.round();
                            setStateCard(() => localInterval = v);
                            await _applyPublicationChange(pub, retransmitIntervalSteps: newVal);
                          },
                        ),

                        const SizedBox(height: 8),
                        const Text('Publication TTL', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text('${pub.publishTtl} seconds', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('Steps: ${pub.publicationSteps}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('Resolution: ${pub.publicationResolution} ms', style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (_updatingPublication) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                      ]),
                    ),
                  );
                }),
            ],
          ]),
        ),
      ),
    );
  }
}

class _BindAppKeySheet extends StatefulWidget {
  final List<Map<String, dynamic>> availableKeys; // {name, keyIndex}
  final int elementAddress;
  final int modelId;
  const _BindAppKeySheet({required this.availableKeys, required this.elementAddress, required this.modelId});

  @override
  State<_BindAppKeySheet> createState() => __BindAppKeySheetState();
}

class __BindAppKeySheetState extends State<_BindAppKeySheet> {
  int? _selected;
  late TextEditingController _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_loading) return;
    int? index = _selected;
    if (index == null) {
      final text = _controller.text.trim();
      if (text.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter an app key index')));
        return;
      }
      try {
        index = int.parse(text);
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid index')));
        return;
      }
    }
    _performBind(index);
  }

  Future<void> _performBind(int index) async {
    setState(() => _loading = true);
    final api = nordicNrfMesh.meshManagerApi;
    try {
      final network = api.meshNetwork;
      if (network == null) throw Exception('Mesh network not loaded');
      final nodes = await network.nodes;

      int? nodeId;
      for (final n in nodes) {
        final elements = await n.elements;
        for (final e in elements) {
          if (e.address == widget.elementAddress) {
            nodeId = await n.unicastAddress;
            break;
          }
        }
        if (nodeId != null) break;
      }

      if (nodeId == null) throw Exception('Node unicast address not found');

      final status = await api.sendConfigModelAppBind(nodeId, widget.elementAddress, widget.modelId, appKeyIndex: index).timeout(const Duration(seconds: 10));
      if(status.elementAddress == widget.elementAddress && status.modelId == widget.modelId && status.appKeyIndex == index) {
        if(mounted) {
          if (status.isSuccessful) {
            Navigator.of(context).pop({'type': 'bind', 'success': true, 'appKeyIndex': index});
          } else {
            Navigator.of(context).pop({'type': 'bind', 'success': false, 'error': status.errorMessage});
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop({'type': 'bind', 'success': false, 'error': e.toString()});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = (MediaQuery.of(context).size.height * 0.9 - viewInsets).clamp(200.0, MediaQuery.of(context).size.height).toDouble();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bind App Key', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (widget.availableKeys.isNotEmpty) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Available app keys')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableKeys.map((k) {
                    final idx = (k['keyIndex'] is int) ? (k['keyIndex'] as int) : int.tryParse(k['keyIndex'].toString()) ?? 0;
                    final name = (k['name'] as String?) ?? '';
                    return GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: idx.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied appKeyIndex: $idx')));
                      },
                      child: ChoiceChip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.isNotEmpty ? name : 'AppKey', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              Text('0x${idx.toRadixString(16).toUpperCase()}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        selected: _selected == idx,
                        onSelected: (v) => setState(() => _selected = v ? idx : null),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(),
              ],
              const Align(alignment: Alignment.centerLeft, child: Text('Or enter AppKey index')),
              const SizedBox(height: 8),
              TextField(controller: _controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 0')),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()))
              else
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _submit, child: const Text('Bind')),
                ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PublicationSheet extends StatefulWidget {
  final List<Map<String, dynamic>> availableKeys; // {name, keyIndex}
  final int elementAddress;
  final int modelId;
  const _PublicationSheet({required this.availableKeys, required this.elementAddress, required this.modelId});

  @override
  State<_PublicationSheet> createState() => __PublicationSheetState();
}

class __PublicationSheetState extends State<_PublicationSheet> {
  int? _selectedKey;
  bool _credentialFlag = false;
  late TextEditingController _addressController;
  late TextEditingController _ttlController;
  late TextEditingController _stepsController;
  late TextEditingController _resolutionController;
  late TextEditingController _retransmitCountController;
  late TextEditingController _retransmitIntervalController;
  bool _loading = false;
  bool _addressesLoading = true;
  List<Map<String, dynamic>> _groupOptions = [];
  List<Map<String, dynamic>> _nodeOptions = [];
  int? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _ttlController = TextEditingController(text: '15');
    _stepsController = TextEditingController(text: '0');
    _resolutionController = TextEditingController(text: '100');
    _retransmitCountController = TextEditingController(text: '0');
    _retransmitIntervalController = TextEditingController(text: '0');
    _loadAddressOptions();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _ttlController.dispose();
    _stepsController.dispose();
    _resolutionController.dispose();
    _retransmitCountController.dispose();
    _retransmitIntervalController.dispose();
    super.dispose();
  }

  Future<void> _loadAddressOptions() async {
    setState(() => _addressesLoading = true);
    try {
      final api = nordicNrfMesh.meshManagerApi;
      final network = api.meshNetwork;
      if (network == null) {
        _groupOptions = [];
        _nodeOptions = [];
        return;
      }

      final groups = await network.groups;
      final nodes = await network.nodes;

      final List<Map<String, dynamic>> groupsBuilt = [];
      for (final g in groups) {
        final name = (g.name).toString().trim();
        groupsBuilt.add({'address': g.address, 'label': name});
      }

      final List<Map<String, dynamic>> nodesBuilt = [];
      for (final n in nodes) {
        try {
          final uuid = n.uuid;
          final elements = await n.elements;
          final List<int> elemAddresses = elements.map<int>((e) => e.address).toList();
          nodesBuilt.add({'uuid': uuid, 'unicast': n.unicastAddress, 'elements': elemAddresses});
        } catch (_) {
          // ignore node if error
        }
      }

      if (mounted) {
        setState(() {
          _groupOptions = groupsBuilt;
          _nodeOptions = nodesBuilt;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _groupOptions = [];
          _nodeOptions = [];
        });
      }
    } finally {
      if (mounted) setState(() => _addressesLoading = false);
    }
  }

  void _submit() {
    int? addr = _selectedAddress;
    if (addr == null) {
      final text = _addressController.text.trim();
      if (text.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter a publish address')));
        return;
      }
      try {
        if (text.startsWith('0x') || text.startsWith('0X')) {
          addr = int.parse(text.substring(2), radix: 16);
        } else {
          addr = int.parse(text);
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid address format')));
        return;
      }
    }

    int parseOr(String s, int fallback) {
      try {
        return int.parse(s);
      } catch (_) {
        return fallback;
      }
    }

    final publishTtl = parseOr(_ttlController.text.trim(), 15);
    final publicationSteps = parseOr(_stepsController.text.trim(), 0);
    final publicationResolution = parseOr(_resolutionController.text.trim(), 100);
    final retransmitCount = parseOr(_retransmitCountController.text.trim(), 0);
    final retransmitIntervalSteps = parseOr(_retransmitIntervalController.text.trim(), 0);

    _performPublication(
      addr,
      _selectedKey ?? 0,
      _credentialFlag,
      publishTtl,
      publicationSteps,
      publicationResolution,
      retransmitCount,
      retransmitIntervalSteps,
    );
  }

  Future<void> _performPublication(
      int publishAddress,
      int appKeyIndex,
      bool credentialFlag,
      int publishTtl,
      int publicationSteps,
      int publicationResolution,
      int retransmitCount,
      int retransmitIntervalSteps,
      ) async {
    setState(() => _loading = true);
    final api = nordicNrfMesh.meshManagerApi;
    try {
      final network = api.meshNetwork;
      if (network == null) throw Exception('Mesh network not loaded');

      final status = await api
          .sendConfigModelPublicationSet(
        widget.elementAddress,
        publishAddress,
        widget.modelId,
        appKeyIndex: appKeyIndex,
        credentialFlag: credentialFlag,
        publishTtl: publishTtl,
        publicationSteps: publicationSteps,
        publicationResolution: publicationResolution,
        retransmitCount: retransmitCount,
        retransmitIntervalSteps: retransmitIntervalSteps,
      )
          .timeout(const Duration(seconds: 12));
      // 使用返回的 status 判断是否成功（根据实际字段检查）
      final ok = status.elementAddress == widget.elementAddress &&
          status.modelIdentifier == widget.modelId &&
          status.publishAddress == publishAddress;

      if (mounted && ok == true) {
        Navigator.of(context).pop({
          'type': 'publication',
          'success': true,
          'publishAddress': publishAddress,
          'status': status,
        });
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop({'type': 'publication', 'success': false, 'error': e.toString()});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = (MediaQuery.of(context).size.height * 0.9 - viewInsets).clamp(200.0, MediaQuery.of(context).size.height).toDouble();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Set Publication', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_addressesLoading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()))
              else ...[
                if (widget.availableKeys.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('App Key')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableKeys.map((k) {
                      final idx = (k['keyIndex'] is int) ? (k['keyIndex'] as int) : int.tryParse(k['keyIndex'].toString()) ?? 0;
                      final name = (k['name'] as String?) ?? '';
                      return GestureDetector(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: idx.toString()));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied appKeyIndex: $idx')));
                        },
                        child: ChoiceChip(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.isNotEmpty ? name : 'AppKey', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text('0x${idx.toRadixString(16).toUpperCase()}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          selected: _selectedKey == idx,
                          onSelected: (v) => setState(() => _selectedKey = v ? idx : null),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_groupOptions.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Groups')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _groupOptions.map((opt) {
                      final addr = opt['address'] as int;
                      final label = opt['label'] as String;
                      final chipLabel = label.isNotEmpty ? '$label (0x${addr.toRadixString(16).toUpperCase()})' : '0x${addr.toRadixString(16).toUpperCase()}';
                      return ChoiceChip(label: Text(chipLabel), selected: _selectedAddress == addr, onSelected: (v) => setState(() => _selectedAddress = v ? addr : null));
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_nodeOptions.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Nodes')),
                  const SizedBox(height: 8),
                  for (final node in _nodeOptions)
                    ExpansionTile(
                      title: Text('Node: ${((node['uuid'] as String?) ?? '').isNotEmpty ? (node['uuid'] as String) : (node['unicast']?.toString() ?? 'unknown')}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: (node['elements'] as List<int>).map((ea) {
                                  final label = 'Element 0x${ea.toRadixString(16).toUpperCase()}';
                                  return ChoiceChip(label: Text(label), selected: _selectedAddress == ea, onSelected: (v) => setState(() => _selectedAddress = v ? ea : null));
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],

                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('Or enter publish address')),
                const SizedBox(height: 8),
                TextField(controller: _addressController, decoration: const InputDecoration(hintText: 'e.g. 0xC000 or 49408')),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(child: TextField(controller: _ttlController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'TTL'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _stepsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Steps'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _resolutionController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Resolution'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _retransmitCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Retransmit Count'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _retransmitIntervalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Retransmit Interval Steps'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Checkbox(value: _credentialFlag, onChanged: (v) => setState(() => _credentialFlag = v ?? false)),
                  const SizedBox(width: 4),
                  const Text('Credential Flag'),
                ]),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()))
                else
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _submit, child: const Text('Set')),
                  ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _SubscribeSheet extends StatefulWidget {
  final int elementAddress;
  final int modelId;
  const _SubscribeSheet({required this.elementAddress, required this.modelId});

  @override
  State<_SubscribeSheet> createState() => __SubscribeSheetState();
}

class __SubscribeSheetState extends State<_SubscribeSheet> {
  bool _loading = false;
  bool _addressesLoading = true;
  List<Map<String, dynamic>> _groupOptions = [];
  int? _selectedAddress;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _loadGroupOptions();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupOptions() async {
    setState(() => _addressesLoading = true);
    try {
      final api = nordicNrfMesh.meshManagerApi;
      final network = api.meshNetwork;
      if (network == null) {
        _groupOptions = [];
        return;
      }
      final groups = await network.groups;
      final List<Map<String, dynamic>> groupsBuilt = [];
      for (final g in groups) {
        groupsBuilt.add({'address': g.address, 'label': (g.name).toString()});
      }
      if (mounted) setState(() => _groupOptions = groupsBuilt);
    } catch (_) {
      if (mounted) setState(() => _groupOptions = []);
    } finally {
      if (mounted) setState(() => _addressesLoading = false);
    }
  }

  void _submit() {
    int? addr = _selectedAddress;
    if (addr == null) {
      final text = _addressController.text.trim();
      if (text.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter a subscription address')));
        return;
      }
      try {
        addr = text.startsWith('0x') || text.startsWith('0X') ? int.parse(text.substring(2), radix: 16) : int.parse(text);
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid address format')));
        return;
      }
    }
    _performSubscription(addr);
  }

  Future<void> _performSubscription(int addr) async {
    setState(() => _loading = true);
    final api = nordicNrfMesh.meshManagerApi;
    try {
      final network = api.meshNetwork;
      if (network == null) throw Exception('Mesh network not loaded');
      final status = await api.sendConfigModelSubscriptionAdd(widget.elementAddress, addr, widget.modelId).timeout(const Duration(seconds: 10));
      // 根据返回的 status 判断是否成功（这里用 subscriptionAddress 与请求的 addr 比对）
      if (status.subscriptionAddress == addr) {
        if (mounted) Navigator.of(context).pop({'success': true, 'subscriptionAddress': addr});
        return;
      } else {
        throw Exception('Subscription rejected or unexpected status: $status');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop({'success': false, 'error': e.toString()});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = (MediaQuery.of(context).size.height * 0.9 - viewInsets).clamp(200.0, MediaQuery.of(context).size.height).toDouble();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Subscribe (groups only)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_addressesLoading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()))
              else ...[
                if (_groupOptions.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Groups')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _groupOptions.map((opt) {
                      final addr = opt['address'] as int;
                      final label = opt['label'] as String;
                      final chipLabel = label.isNotEmpty ? '$label (0x${addr.toRadixString(16).toUpperCase()})' : '0x${addr.toRadixString(16).toUpperCase()}';
                      return ChoiceChip(label: Text(chipLabel), selected: _selectedAddress == addr, onSelected: (v) => setState(() => _selectedAddress = v ? addr : null));
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                const Align(alignment: Alignment.centerLeft, child: Text('Or enter group address manually')),
                const SizedBox(height: 8),
                TextField(controller: _addressController, decoration: const InputDecoration(hintText: 'e.g. 0xC000 or 49408')),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()))
                else
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _submit, child: const Text('Subscribe')),
                  ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
