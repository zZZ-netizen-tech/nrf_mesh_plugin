// filepath: /Users/sr/Documents/code/nrf_mesh_plugin/example/lib/src/views/group/group.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';
import 'package:nordic_nrf_mesh_example/src/widgets/group.dart' as widgets;
import 'package:nordic_nrf_mesh_example/src/views/group/device_list.dart';
import 'package:nordic_nrf_mesh_example/src/views/group/group_detail.dart';

/// A simple page that lists groups from the loaded mesh network.
class GroupsPage extends StatefulWidget {
  final NordicNrfMesh nordicNrfMesh;
  const GroupsPage({super.key, required this.nordicNrfMesh});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  List<GroupData> _groups = [];
  IMeshNetwork? _meshNetwork;
  bool _loading = false;
  bool _isAdding = false;
  final Set<int> _deleting = {};

  @override
  void initState() {
    super.initState();
    _meshNetwork = widget.nordicNrfMesh.meshManagerApi.meshNetwork;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _groups = [];
    });

    if (_meshNetwork == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final groups = await _meshNetwork!.groups;
      setState(() {
        _groups = groups;
      });
    } catch (e) {
      debugPrint('Failed to load groups: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_meshNetwork == null) {
      return const Center(child: Text('No mesh network loaded'));
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                  label: Text(_isAdding ? 'Adding...' : 'Add group'),
                  onPressed: _isAdding
                      ? null
                      : () async {
                          // Show a modal bottom sheet that performs validation and displays errors inline
                          final result = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            builder: (sheetCtx) {
                              String? name;
                              String? errorText;
                              bool isSubmitting = false;
                              return StatefulBuilder(builder: (c, setModalState) {
                                final bottom = MediaQuery.of(c).viewInsets.bottom;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: bottom),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Create group', style: Theme.of(c).textTheme.titleMedium),
                                        const SizedBox(height: 8),
                                        TextField(
                                          autofocus: true,
                                          decoration: InputDecoration(labelText: 'Group name', errorText: errorText),
                                          onChanged: (v) => setModalState(() {
                                            name = v;
                                            errorText = null;
                                          }),
                                          onSubmitted: (_) async {
                                            // optional: submit on enter
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(onPressed: () => Navigator.pop(sheetCtx, false), child: const Text('Cancel')),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: ((name?.trim().isEmpty ?? true) || isSubmitting)
                                                  ? null
                                                  : () async {
                                                      final candidate = name!.trim();
                                                       // client-side validation
                                                       if (candidate.length > 32) {
                                                         setModalState(() => errorText = 'Name too long (max 32 chars)');
                                                         return;
                                                       }
                                                       final allowed = RegExp(r'^[A-Za-z0-9 _-]+$');
                                                       if (!allowed.hasMatch(candidate)) {
                                                         setModalState(() => errorText = 'Only letters, numbers, spaces, _ and - are allowed');
                                                         return;
                                                       }

                                                       setModalState(() {
                                                         isSubmitting = true;
                                                         errorText = null;
                                                       });
                                                       try {
                                                         await _meshNetwork!.addGroupWithName(candidate);
                                                         // Close sheet and indicate success
                                                         Navigator.pop(sheetCtx, true);
                                                       } on PlatformException catch (e) {
                                                         setModalState(() => errorText = e.message ?? 'Platform error');
                                                       } catch (e) {
                                                         setModalState(() => errorText = e.toString());
                                                       } finally {
                                                         setModalState(() => isSubmitting = false);
                                                       }
                                                     },
                                              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create'),
                                             ),
                                           ],
                                         ),
                                         const SizedBox(height: 8),
                                       ],
                                     ),
                                   ),
                                 );
                               });
                             },
                           );

                           if (result == true) {
                             // success: sheet already added the group; refresh and show feedback
                             scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Group added')));
                             await _loadGroups();
                           }
                        },
                 ),
               ),
             ],
           ),
         ),
         Expanded(
           child: RefreshIndicator(
             onRefresh: _loadGroups,
             child: _loading
                 ? const Center(child: CircularProgressIndicator())
                 : _groups.isEmpty
                     ? ListView(
                         children: const [SizedBox(height: 120), Center(child: Text('No groups'))],
                       )
                     : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final g = _groups[index];
                          return InkWell(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => GroupDetailPage(meshNetwork: _meshNetwork!, groupAddress: g.address))),
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                children: [
                                  widgets.Group(g, _meshNetwork!),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Add device button (functionality not implemented yet)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                        child: IconButton(
                                          icon: const Icon(Icons.person_add, color: Colors.blueAccent),
                                          tooltip: '添加设备',
                                          onPressed: () {
                                            Navigator.of(context).push(MaterialPageRoute(builder: (c) => MeshDeviceListPage(meshNetwork: _meshNetwork!, groupAddress: g.address)));
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                        child: _deleting.contains(g.address)
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                            : IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text('Delete group'),
                                                      content: Text('Are you sure you want to delete group "${g.name}" (${g.address})?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm != true) return;

                                                  setState(() {
                                                    _deleting.add(g.address);
                                                  });
                                                  try {
                                                    await _meshNetwork!.removeGroup(g.address);
                                                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Group deleted')));
                                                    await _loadGroups();
                                                  } on PlatformException catch (e) {
                                                    scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Platform error')));
                                                  } catch (e) {
                                                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to delete group: ${e.toString()}')));
                                                  } finally {
                                                    if (mounted) {
                                                      setState(() {
                                                        _deleting.remove(g.address);
                                                      });
                                                    }
                                                  }
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                       ),
           ),
         ),
       ],
     );
   }
 }
