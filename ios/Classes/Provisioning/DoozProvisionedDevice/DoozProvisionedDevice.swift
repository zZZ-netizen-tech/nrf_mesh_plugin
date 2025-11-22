//
//  DoozProvisionedDevice.swift
//  nordic_nrf_mesh
//
//  Created by Alexis Barat on 07/08/2020.
//

import Foundation
import nRFMeshProvision

class DoozProvisionedDevice: NSObject{
    
    //MARK: Public properties
    public var node: Node
    
    init(messenger: FlutterBinaryMessenger, node: Node){
        self.node = node
        super.init()
        _initChannels(messenger: messenger, uuid: node.uuid)
    }
    
}

private extension DoozProvisionedDevice {
    
    func _initChannels(messenger: FlutterBinaryMessenger, uuid: UUID){
        
        FlutterMethodChannel(
            name: FlutterChannels.DoozProvisionedMeshNode.getMethodChannelName(deviceUUID: uuid.uuidString),
            binaryMessenger: messenger
        )
        .setMethodCallHandler { (call, result) in
            self._handleMethodCall(call, result: result)
        }
        
    }
    
    
    func _handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        print("🥂 [\(self.classForCoder)] Received flutter call : \(call.method)")
        
        let _method = DoozProvisionedMeshNodeChannel(call: call)
        
        switch _method {
        
        case .error(let error):
            switch error {
            case FlutterCallError.notImplemented:
                result(FlutterMethodNotImplemented)
            case FlutterCallError.missingArguments:
                result(FlutterError(code: "missingArguments", message: "The provided arguments does not match required", details: nil))
            case FlutterCallError.errorDecoding:
                result(FlutterError(code: "errorDecoding", message: "An error occured attempting to decode arguments", details: nil))
            default:
                let nsError = error as NSError
                result(FlutterError(code: String(nsError.code), message: nsError.localizedDescription, details: nil))
            }
        
            break
        case .unicastAddress:
            result(node.primaryUnicastAddress)
            break
        case .nodeName(let data):
            node.name = data.name
            result(nil)
            break
        case .name:
            result(node.name)
            break
        case .networkKeys:
            // Return list of network key info known to this node as dictionaries with NetworkKey fields
            func hex(_ data: Data?) -> String? {
                guard let d = data else { return nil }
                return d.map { String(format: "%02x", $0) }.joined()
            }
            let keysSource = node.networkKeys
            let infos = keysSource.map { nk -> [String: Any] in
                return [
                    "index": Int(nk.index),
                    "name": nk.name,
                    "key": hex(nk.key) ?? NSNull(),
                    "phase": nk.phase.rawValue,
                    "networkId": hex(nk.networkId) ?? NSNull()
                ]
            }
            result(infos)
            break
        case .applicationKeys:
            func hex(_ data: Data?) -> String? {
                guard let d = data else { return nil }
                return d.map { String(format: "%02x", $0) }.joined()
            }
            let appKeys = node.applicationKeys
            let appInfos = appKeys.map { ak -> [String: Any] in
                return [
                    "index": Int(ak.index),
                    "name": ak.name,
                    "key": hex(ak.key) ?? NSNull(),
                    "oldKey": hex(ak.oldKey) ?? NSNull(),
                    "boundNetworkKeyIndex": Int(ak.boundNetworkKeyIndex)
                ]
            }
            result(appInfos)
            break
        case .elements:
            let elements = node.elements.map { element in
                return [
                    EventSinkKeys.meshNode.elements.key.rawValue: element.index,
                    EventSinkKeys.meshNode.elements.name.rawValue: element.name ?? "unnamed element",
                    EventSinkKeys.meshNode.elements.address.rawValue : element.unicastAddress,
                    EventSinkKeys.meshNode.elements.locationDescriptor.rawValue : element.location.rawValue,
                    EventSinkKeys.meshNode.elements.models.rawValue : element.models.enumerated().map({ (index,model) in
                        return [
                            EventSinkKeys.meshNode.elements.model.key.rawValue : index,
                            EventSinkKeys.meshNode.elements.model.modelId.rawValue : model.modelIdentifier,
                            EventSinkKeys.meshNode.elements.model.subscribedAddresses.rawValue : model.subscriptions.map{ sub in
                                return sub.address.address
                            },
                            EventSinkKeys.meshNode.elements.model.boundAppKey.rawValue : model.boundApplicationKeys.map{ key in
                                return key.index
                            },
                            EventSinkKeys.meshNode.elements.model.modelName.rawValue : model.name ?? "unnamed model",
                            
                        ]
                        
                    })
                ]
            }
            result(elements)
            break
        case .elementAt:
            //node.element(withAddress: <#T##Address#>)
            break
                        
        }
        
    }
}
