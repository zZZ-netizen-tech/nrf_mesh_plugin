import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 简化版 Node 数据模型，用于展示和交互占位。
class Node {
  String? name;
  int primaryUnicastAddress;
  int? defaultTTL;
  String? deviceKeyHex;
  bool isCompositionDataReceived;
  bool isConfigComplete;
  bool isExcluded;
  int? companyIdentifier;
  int? productIdentifier;
  int? versionIdentifier;
  int? minimumNumberOfReplayProtectionList;

  List<ElementModel> elements = [];
  List<dynamic> networkKeys = [];
  List<dynamic> applicationKeys = [];
  List<dynamic> scenes = [];

  Node({
    this.name,
    required this.primaryUnicastAddress,
    this.defaultTTL,
    this.deviceKeyHex,
    this.isCompositionDataReceived = false,
    this.isConfigComplete = false,
    this.isExcluded = false,
    this.companyIdentifier,
    this.productIdentifier,
    this.versionIdentifier,
    this.minimumNumberOfReplayProtectionList,
  });
}

class ElementModel {
  final String? name;
  final int index;
  final int modelsCount;
  ElementModel({this.name, required this.index, this.modelsCount = 0});
}

/// Flutter 页面：Node 详情与配置（占位实现，Mesh 通信需集成到后端或平台渠道）。
class NodeViewPage extends StatefulWidget {
  final Node node;
  final Node? originalNode; // 可选，用于 reconfigure 流程

  const NodeViewPage({Key? key, required this.node, this.originalNode}) : super(key: key);

  @override
  State<NodeViewPage> createState() => _NodeViewPageState();
}

class _NodeViewPageState extends State<NodeViewPage> {
  late Node node;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    node = widget.node;
    // Fetch current TTL when opening the node view (non-blocking).
    // This ensures _getTtl is referenced and provides a best-effort TTL value.
    _getTtl();
  }

  Future<void> _identifyPressed() async {
    try {
      final can = await _canIdentify(node);
      if (!can) {
        final configure = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Identify'),
            content: Text(
                'Health Server model requires configuration.\n\nWould you like to configure ${node.name ?? 'the Node'} automatically?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Configure')),
            ],
          ),
        );
        if (configure == true) {
          await _identify(node);
        }
        return;
      }
      await _identify(node);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<bool> _canIdentify(Node node) async {
    // TODO: 与实际 Mesh 后端集成判断逻辑
    await Future.delayed(const Duration(milliseconds: 150));
    return node.deviceKeyHex != null;
  }

  Future<void> _identify(Node node) async {
    // TODO: 发送 Identify 命令到设备
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    _setLoading(false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identify command sent')));
  }

  Future<void> _getCompositionData() async {
    _setLoading(true);
    // TODO: 请求 Composition Data，通过平台通道或后端
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      node.isCompositionDataReceived = true; // 模拟
    });
    _setLoading(false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Composition Data requested')));

    if (widget.originalNode != null) {
      // 模拟 reconfigure 跳转或逻辑提示
      await Future.delayed(const Duration(milliseconds: 200));
      _showReconfigureDialog();
    }
  }

  Future<void> _getTtl() async {
    _setLoading(true);
    // TODO: 请求默认 TTL
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      node.defaultTTL ??= 6; // 模拟
    });
    _setLoading(false);
  }

  Future<void> _setTtl(int ttl) async {
    _setLoading(true);
    // TODO: 发送 ConfigDefaultTtlSet
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      node.defaultTTL = ttl;
    });
    _setLoading(false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TTL updated')));
  }

  Future<void> _resetNode() async {
    final ok = await _confirmAction('Reset Node',
        'Resetting the node will change its state back to unprovisioned state and remove it from the local database.');
    if (!ok) return;
    _setLoading(true);
    // TODO: 发送 ConfigNodeReset
    await Future.delayed(const Duration(seconds: 1));
    _setLoading(false);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _removeNode() async {
    final ok = await _confirmAction('Remove Node',
        'The node will only be removed from the local database. It will still be able to send and receive messages from the network. Remove the node only if the device is no longer available.');
    if (!ok) return;
    // TODO: 从本地保存中移除 node
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Node removed from local database')));
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmAction(String title, String message) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(message),
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8.0,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(title, style: const TextStyle(color: Colors.red))),
                ],
              )
            ],
          ),
        );
      },
    );
    return res == true;
  }

  void _showReconfigureDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconfigure'),
        content: const Text('Composition Data received. Would you like to reconfigure the node based on original configuration?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('No')),
          TextButton(onPressed: () {
            Navigator.of(context).pop();
            // TODO: 启动 reconfigure 流程
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconfigure started')));
          }, child: const Text('Yes')),
        ],
      ),
    );
  }

  void _presentNameDialog() async {
    final controller = TextEditingController(text: node.name ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'E.g. Bedroom Light')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('OK')),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        node.name = result.isEmpty ? null : result;
      });
      // TODO: 保存网络配置
    }
  }

  void _presentTtlDialog() async {
    final controller = TextEditingController(text: node.defaultTTL != null ? '${node.defaultTTL}' : '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default TTL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'TTL (0-127)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('OK')),
        ],
      ),
    );
    if (result != null) {
      final ttl = int.tryParse(result);
      if (ttl != null && ttl >= 0 && ttl <= 127) {
        await _setTtl(ttl);
      } else {
        _showError('Invalid TTL value');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setLoading(bool v) => setState(() => isLoading = v);

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(node.name ?? 'Unknown device'),
        actions: [
          IconButton(onPressed: _identifyPressed, icon: const Icon(Icons.vibration)),
          IconButton(
              onPressed: node.deviceKeyHex != null ? () => Clipboard.setData(ClipboardData(text: node.deviceKeyHex!)) : null,
              icon: const Icon(Icons.copy)),
          IconButton(onPressed: _getCompositionData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            children: [
              _buildSectionHeader('Name'),
              ListTile(
                title: const Text('Name'),
                subtitle: Text(node.name ?? 'No name'),
                trailing: const Icon(Icons.edit),
                onTap: _presentNameDialog,
              ),

              _buildSectionHeader('Node'),
              ListTile(
                title: const Text('Unicast Address'),
                subtitle: Text('0x${node.primaryUnicastAddress.toRadixString(16).padLeft(4, '0').toUpperCase()}'),
              ),
              ListTile(
                title: const Text('Default TTL'),
                subtitle: Text(node.defaultTTL != null ? '${node.defaultTTL}' : 'Unknown'),
                trailing: const Icon(Icons.edit),
                onTap: _presentTtlDialog,
              ),
              ListTile(
                title: const Text('Device Key'),
                subtitle: Text(node.deviceKeyHex ?? 'Unknown Device Key'),
                onTap: () {
                  if (node.deviceKeyHex != null) {
                    Clipboard.setData(ClipboardData(text: node.deviceKeyHex!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Key copied to Clipboard.')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No key to copy.')));
                  }
                },
              ),

              _buildSectionHeader('Keys'),
              ListTile(
                title: const Text('Network Keys'),
                trailing: Text('${node.networkKeys.length}'),
                onTap: () {
                  // TODO: 跳转到 network keys 页面
                },
              ),
              ListTile(
                title: const Text('Application Keys'),
                trailing: Text('${node.applicationKeys.length}'),
                onTap: () {
                  // TODO: 跳转到 application keys 页面
                },
              ),

              _buildSectionHeader('Elements'),
              if (node.isCompositionDataReceived)
                ...node.elements.map((e) => ListTile(
                      title: Text(e.name ?? 'Element ${e.index + 1}'),
                      subtitle: Text('${e.modelsCount} models'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: 元素详情
                      },
                    ))
              else
                ListTile(
                  title: const Text('Composition Data not received'),
                  subtitle: const Text('Pull to refresh or open the node to request composition data.'),
                ),

              _buildSectionHeader('Scenes'),
              ListTile(
                title: const Text('Scenes'),
                subtitle: Text(node.isCompositionDataReceived ? '${node.scenes.length}' : 'Not supported'),
                onTap: () {
                  // TODO: 跳转到 scenes
                },
              ),

              _buildSectionHeader('Node information'),
              ListTile(
                title: const Text('Company Identifier'),
                subtitle: Text(node.companyIdentifier != null ? '${node.companyIdentifier}' : 'Unknown'),
              ),
              ListTile(
                title: const Text('Product Identifier'),
                subtitle: Text(node.productIdentifier != null ? '${node.productIdentifier}' : 'Unknown'),
              ),
              ListTile(
                title: const Text('Product Version'),
                subtitle: Text(node.versionIdentifier != null ? '${node.versionIdentifier}' : 'Unknown'),
              ),
              ListTile(
                title: const Text('Replay Protection Count'),
                subtitle: Text(node.minimumNumberOfReplayProtectionList != null ? '${node.minimumNumberOfReplayProtectionList}' : 'Unknown'),
              ),
              ListTile(
                title: const Text('Security'),
                subtitle: const Text('—'),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(title: const Text('Info'), content: const Text('A node is considered secure when it has been provisioned using Out-Of-Band (OOB) Public Key.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]),
                    );
                  },
                ),
              ),

              _buildSectionHeader('Switches'),
              SwitchListTile(
                title: const Text('Configured'),
                value: node.isConfigComplete,
                activeThumbColor: Colors.blue,
                onChanged: (v) {
                  setState(() => node.isConfigComplete = v);
                  // TODO: persist change
                },
              ),
              SwitchListTile(
                title: const Text('Excluded'),
                value: node.isExcluded,
                activeThumbColor: Colors.red,
                onChanged: (v) {
                  setState(() => node.isExcluded = v);
                  // TODO: persist change
                },
              ),

              _buildSectionHeader('Actions'),
              ListTile(
                title: const Text('Reset Node'),
                trailing: const Text('Reset', style: TextStyle(color: Colors.red)),
                onTap: _resetNode,
              ),
              ListTile(
                title: const Text('Remove Node'),
                trailing: const Text('Remove', style: TextStyle(color: Colors.red)),
                onTap: _removeNode,
              ),
            ],
          ),

          if (isLoading) ...[
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            )
          ]
        ],
      ),
    );
  }
}
