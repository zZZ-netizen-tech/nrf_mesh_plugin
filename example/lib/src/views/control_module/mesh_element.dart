import 'package:flutter/material.dart';
import 'package:nordic_nrf_mesh/nordic_nrf_mesh.dart';
import 'package:nordic_nrf_mesh_example/src/views/control_module/model_detail.dart';

class MeshElement extends StatelessWidget {
  final ElementData element;
  final MeshManagerApi? meshManagerApi;

  const MeshElement(this.element, {Key? key, this.meshManagerApi}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final addressHex = '0x${element.address.toRadixString(16).toUpperCase()}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.device_hub, size: 20, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    element.name.isNotEmpty ? element.name : 'Element ${element.key}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  addressHex,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Models as rows (ListTiles) — one per model
            if (element.models.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No models', style: TextStyle(color: Colors.grey[700])),
              )
            else
              Column(
                children: element.models.map((ModelData model) {
                  final modelHex = '0x${model.modelId.toRadixString(16).toUpperCase()}';
                  // Prefer model's subscribed address if present, otherwise fall back to element address

                  final modelName = model.modelName.isNotEmpty ? model.modelName : modelHex;
                  final bound = model.boundAppKey.isNotEmpty;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(modelName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Model ID: $modelHex', style: const TextStyle(fontSize: 12)),
                        trailing: Icon(
                          bound ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: bound ? Colors.green : Colors.grey,
                        ),
                        // navigate to model details on tap
                        onTap: () async {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ModelDetailPage(model: model, element: element),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
