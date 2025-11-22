package fr.dooz.nordic_nrf_mesh

import android.annotation.SuppressLint
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import no.nordicsemi.android.mesh.transport.ProvisionedMeshNode

class DoozProvisionedMeshNode(binaryMessenger: BinaryMessenger, var meshNode: ProvisionedMeshNode): MethodChannel.MethodCallHandler {
    init {
        MethodChannel(binaryMessenger, "$namespace/provisioned_mesh_node/${meshNode.uuid}/methods").setMethodCallHandler(this)
    }

    @SuppressLint("RestrictedApi")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "nodeName" -> {
                val nodeName = call.argument<String>("name")!!
                meshNode.nodeName = nodeName
                result.success(null)
            }
            "name" -> {
                result.success(meshNode.nodeName)
            }
            "elementAt" -> {

            }
            "elements" -> {
                result.success(meshNode.elements.map { element ->
                    mapOf(
                            "key" to element.key,
                            "address" to element.value.elementAddress,
                            "name" to element.value.name,
                            "locationDescriptor" to element.value.locationDescriptor,
                            "models" to element.value.meshModels.map {
                                mapOf(
                                        "key" to it.key,
                                        "modelId" to it.value.modelId,
                                        "subscribedAddresses" to it.value.subscribedAddresses,
                                        "boundAppKey" to it.value.boundAppKeyIndexes
                                )
                            }
                    )
                })
            }
            "unicastAddress" -> {
                result.success(meshNode.unicastAddress)
            }
            "networkKeys" -> {
                // Return list of network key info known to this node as maps { "index": Int, "name": String?, "key": String?, "phase": String?, "networkId": String? }
                try {
                    fun bytesToHex(bytes: Any?): String? {
                        return when (bytes) {
                            is ByteArray -> bytes.joinToString(separator = "") { String.format("%02x", it) }
                            is List<*> -> try { (bytes.map { (it as Number).toInt() }.joinToString("") { String.format("%02x", it.toInt()) }) } catch (e: Exception) { null }
                            is String -> bytes
                            else -> null
                        }
                    }

                    val keys = mutableListOf<Map<String, Any?>>()
                    val nodeKeys = meshNode.networkKeys
                    if (nodeKeys != null) {
                        for (k in nodeKeys) {
                            // index
                            val idxAny = try { k.index } catch (e: Exception) { try { k.keyIndex } catch (ex: Exception) { try { k.getIndex() } catch (e2: Exception) { null } } }
                            val index = when (idxAny) {
                                is Int -> idxAny
                                is Number -> idxAny.toInt()
                                is String -> idxAny.toIntOrNull()
                                else -> null
                            }

                            // name
                            val name = try { k.name?.toString() } catch (e: Exception) { try { k.getName()?.toString() } catch (ex: Exception) { null } }

                            // key bytes -> hex
                            val keyHex = try { bytesToHex(k.key) } catch (e: Exception) { try { bytesToHex(k.getKey()) } catch (ex: Exception) { null } }

                            // phase
                            val phaseVal = try { k.phase?.toString() } catch (e: Exception) { try { k.getPhase()?.toString() } catch (ex: Exception) { null } }

                            // networkId bytes -> hex
                            val networkIdHex = try { bytesToHex(k.networkId) } catch (e: Exception) { try { bytesToHex(k.getNetworkId()) } catch (ex: Exception) { null } }

                            keys.add(mapOf(
                                    "index" to index,
                                    "name" to name,
                                    "key" to keyHex,
                                    "phase" to phaseVal,
                                    "networkId" to networkIdHex
                            ))
                        }
                    }
                    result.success(keys)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to retrieve networkKeys", e.message)
                }
            }
            "applicationKeys" -> {
                // Return list of application key info known to this node as maps { "index": Int, "name": String?, "key": String?, "boundNetworkKeyIndex": Int?, "updated": Boolean }
                try {
                    fun bytesToHex(bytes: Any?): String? {
                        return when (bytes) {
                            is ByteArray -> bytes.joinToString(separator = "") { String.format("%02x", it) }
                            is List<*> -> try { (bytes.map { (it as Number).toInt() }.joinToString("") { String.format("%02x", it.toInt()) }) } catch (e: Exception) { null }
                            is String -> bytes
                            else -> null
                        }
                    }

                    val keys = mutableListOf<Map<String, Any?>>()
                    val appKeys = try { meshNode.applicationKeys } catch (e: Exception) { try { meshNode.appKeys } catch (ex: Exception) { null } }
                    if (appKeys != null) {
                        for (k in appKeys) {
                            val idxAny = try { k.index } catch (e: Exception) { try { k.keyIndex } catch (ex: Exception) { try { k.getIndex() } catch (e2: Exception) { null } } }
                            val index = when (idxAny) {
                                is Int -> idxAny
                                is Number -> idxAny.toInt()
                                is String -> idxAny.toIntOrNull()
                                else -> null
                            }
                            val name = try { k.name?.toString() } catch (e: Exception) { try { k.getName()?.toString() } catch (ex: Exception) { null } }
                            val keyHex = try { bytesToHex(k.key) } catch (e: Exception) { try { bytesToHex(k.getKey()) } catch (ex: Exception) { null } }
                            val boundNet = try { val v = k.boundNetworkKeyIndex; when(v){is Number->v.toInt(); is Int->v; else->null} } catch (e: Exception) { try { val v = k.getBoundNetworkKeyIndex(); when(v){is Number->v.toInt(); is Int->v; else->null} } catch (ex: Exception) { null } }

                            keys.add(mapOf(
                                    "index" to index,
                                    "name" to name,
                                    "key" to keyHex,
                                    "oldKey" to null,
                                    "boundNetworkKeyIndex" to boundNet
                            ))
                        }
                    }
                    result.success(keys)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to retrieve applicationKeys", e.message)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}