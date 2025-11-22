import 'package:flutter/services.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nordic_nrf_mesh/src/constants.dart';

part 'provisioned_mesh_node.g.dart';

/// {@template model_data}
/// A serializable data class used to hold data about a specific model of a mesh node
/// {@endtemplate}
@JsonSerializable(anyMap: true)
class ModelData {
  final int key;
  final int modelId;
  final List<int> subscribedAddresses;
  final List<int> boundAppKey;
  final String modelName;

  /// {@macro model_data}
  ModelData(this.key, this.modelId, this.subscribedAddresses, this.boundAppKey,this.modelName);

  /// Provide a constructor to get [ModelData] from JSON [Map].
  /// {@macro model_data}
  factory ModelData.fromJson(Map json) => _$ModelDataFromJson(json);

  /// Provide a constructor to get [Map] from [ModelData].
  /// {@macro model_data}
  Map<String, dynamic> toJson() => _$ModelDataToJson(this);

  @override
  String toString() => 'ModelData ${toJson()}';
}

/// {@template element_data}
/// A serializable data class used to hold data about a specific element of a mesh node
/// {@endtemplate}
@JsonSerializable(anyMap: true)
class ElementData {
  final int key;
  final int address;
  final String name;
  final int locationDescriptor;
  final List<ModelData> models;

  /// {@macro element_data}
  ElementData(this.key, this.name, this.address, this.locationDescriptor, this.models);

  /// Provide a constructor to get [ElementData] from JSON [Map].
  /// {@macro element_data}
  factory ElementData.fromJson(Map json) => _$ElementDataFromJson(json.cast<String, dynamic>());

  /// Provide a constructor to get [Map] from [ElementData].
  /// {@macro element_data}
  Map<String, dynamic> toJson() => _$ElementDataToJson(this);

  @override
  String toString() => 'ElementData ${toJson()}';
}

/// {@template provisioned_node}
/// A class used to expose some data of a given **provisioned** mesh node
/// {@endtemplate}
class ProvisionedMeshNode {
  final MethodChannel _methodChannel;
  final String uuid;

  /// {@macro provisioned_node}
  ProvisionedMeshNode(this.uuid) : _methodChannel = MethodChannel('$namespace/provisioned_mesh_node/$uuid/methods');

  /// Will return the unicast address of this node as stored in the local database
  Future<int> get unicastAddress async => (await _methodChannel.invokeMethod<int>('unicastAddress'))!;

  /// Will set the name of this node to be stored in the local database
  set nodeName(String name) => _methodChannel.invokeMethod('nodeName', {'name': name});

  /// Will return the name of this node as stored in the local database
  Future<String> get name async => (await _methodChannel.invokeMethod<String>('name'))!;

  /// Will return the list of elements of this node as stored in the local database
  Future<List<ElementData>> get elements async {
    final elements = await _methodChannel.invokeMethod<List>('elements');
    return elements!.map((e) => ElementData.fromJson(e)).toList();
  }

  /// Will return the list of network key info known to this node
  /// Normalized entries include: { 'index': int?, 'name': String?, 'key': String?, 'phase': String?, 'networkId': String?, 'updated': bool }
  Future<List<Map<String, dynamic>>> get networkKeys async {
    final keys = await _methodChannel.invokeMethod<List>('networkKeys');
    if (keys == null) return [];
    return keys.map<Map<String, dynamic>>((k) {
      // Default normalized map
      var normalized = <String, dynamic>{'index': null, 'name': null, 'key': null, 'phase': null, 'networkId': null, 'updated': false};
      if (k is Map) {
        final map = Map<String, dynamic>.from(k.cast<String, dynamic>());
        // index could be under 'index', 'keyIndex', or as a string
        final idxVal = map['index'] ?? map['keyIndex'] ?? map['idx'] ?? map['key'];
        if (idxVal is num) {
          normalized['index'] = idxVal.toInt();
        } else if (idxVal is String) {
          final parsed = int.tryParse(idxVal);
          if (parsed != null) normalized['index'] = parsed;
        } else if (idxVal is Map && idxVal['index'] is num) {
          normalized['index'] = (idxVal['index'] as num).toInt();
        }

        // name
        if (map['name'] != null) normalized['name'] = map['name'].toString();
        // key (may be hex string)
        if (map['key'] != null) normalized['key'] = map['key'].toString();
        // phase
        if (map['phase'] != null) normalized['phase'] = map['phase'].toString();
        // networkId might be Data / bytes or hex string
        if (map['networkId'] != null) {
          final nid = map['networkId'];
          if (nid is String) normalized['networkId'] = nid;
          else if (nid is List) {
            // list of ints -> hex
            try {
              normalized['networkId'] = nid.map<int>((e) => (e as num).toInt()).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            } catch (_) {}
          }
        }
        // updated flag could be 'updated' or 'isUpdated'
        if (map['updated'] is bool) normalized['updated'] = map['updated'] as bool;
        else if (map['isUpdated'] is bool) normalized['updated'] = map['isUpdated'] as bool;
        else if (map['updated'] is num) normalized['updated'] = (map['updated'] as num) != 0;
      } else if (k is num) {
        normalized['index'] = k.toInt();
      } else if (k is String) {
        final parsed = int.tryParse(k);
        if (parsed != null) normalized['index'] = parsed;
      }
      return normalized;
    }).toList();
  }

  /// Will return the list of application key info known to this node
  /// Normalized entries include: { 'index': int?, 'name': String?, 'key': String?, 'updated': bool }
  Future<List<Map<String, dynamic>>> get applicationKeys async {
    final keys = await _methodChannel.invokeMethod<List>('applicationKeys');
    if (keys == null) return [];
    return keys.map<Map<String, dynamic>>((k) {
      var normalized = <String, dynamic>{'index': null, 'name': null, 'key': null, 'updated': false};
      if (k is Map) {
        final map = Map<String, dynamic>.from(k.cast<String, dynamic>());
        final idxVal = map['index'] ?? map['keyIndex'] ?? map['idx'];
        if (idxVal is num) {
          normalized['index'] = idxVal.toInt();
        } else if (idxVal is String) {
          final parsed = int.tryParse(idxVal);
          if (parsed != null) normalized['index'] = parsed;
        }
        if (map['name'] != null) normalized['name'] = map['name'].toString();
        if (map['key'] != null) normalized['key'] = map['key'].toString();
        if (map['updated'] is bool) {
          normalized['updated'] = map['updated'] as bool;
        } else if (map['isUpdated'] is bool) {
          normalized['updated'] = map['isUpdated'] as bool;
        }
        else if (map['updated'] is num) {
          normalized['updated'] = (map['updated'] as num) != 0;
        }
      } else if (k is num) {
        normalized['index'] = k.toInt();
      }
      else if (k is String) {
        final parsed = int.tryParse(k);
        if (parsed != null) normalized['index'] = parsed;
      }
      return normalized;
    }).toList();
  }
}
