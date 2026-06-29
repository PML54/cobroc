
// ==========================================
// 📁 lib/widgets/brocante/rayon_dialog.dart
// ==========================================
import 'package:flutter/material.dart';
import 'package:cobroc/services/storage_service.dart';

class RayonDialog extends StatefulWidget {
  final AppParameters parametresInitiaux;
  final Function(AppParameters) onValidate;

  const RayonDialog({
    super.key,
    required this.parametresInitiaux,
    required this.onValidate,
  });

  @override
  _RayonDialogState createState() => _RayonDialogState();
}

class _RayonDialogState extends State<RayonDialog> {
  late double tempRayonDensite;
  late double tempPoidExposants;
  late double tempPoidDensite;
  late double tempPoidRevenu;
  late double tempPoidHistorique;
  late bool tempInclureDistance;

  @override
  void initState() {
    super.initState();
    tempRayonDensite = widget.parametresInitiaux.rayonDensite.toDouble();
    tempPoidExposants = widget.parametresInitiaux.poidExposants;
    tempPoidDensite = widget.parametresInitiaux.poidDensite;
    tempPoidRevenu = widget.parametresInitiaux.poidRevenu;
    tempPoidHistorique = widget.parametresInitiaux.poidHistorique;
    tempInclureDistance = widget.parametresInitiaux.inclureDistance;
  }

  double get totalPourcentages =>
      tempPoidExposants + tempPoidDensite + tempPoidRevenu + tempPoidHistorique;

  bool get totalValide => (totalPourcentages - 100.0).abs() < 0.1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paramètres de notation'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rayon de densité
            const Text('Rayon:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: tempRayonDensite,
                    min: 5.0,
                    max: 20.0,
                    divisions: 15,
                    label: '${tempRayonDensite.round()} km',
                    onChanged: (value) {
                      setState(() => tempRayonDensite = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text('${tempRayonDensite.round()} km',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text('Pondération des critères:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Slider Exposants
            _buildSlider(
              'Nombre d\'exposants:',
              tempPoidExposants,
              Colors.blue,
                  (value) => setState(() => tempPoidExposants = value),
            ),

            // Slider Densité
            _buildSlider(
              'Densité de brocantes:',
              tempPoidDensite,
              Colors.green,
                  (value) => setState(() => tempPoidDensite = value),
            ),

            // Slider Revenu
            _buildSlider(
              'Revenu de la commune:',
              tempPoidRevenu,
              Colors.orange,
                  (value) => setState(() => tempPoidRevenu = value),
            ),

            // Slider Historique
            _buildSlider(
              'Historique personnel:',
              tempPoidHistorique,
              Colors.purple,
                  (value) => setState(() => tempPoidHistorique = value),
            ),

            const SizedBox(height: 15),

            // Total
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: totalValide ? Colors.green.shade50 : Colors.orange.shade50,
                border: Border.all(
                  color: totalValide ? Colors.green : Colors.orange,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(
                        '${totalPourcentages.round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: totalValide
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        totalValide ? Icons.check_circle : Icons.warning,
                        color: totalValide ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (!totalValide) ...[
              const SizedBox(height: 8),
              Text(
                'Le total sera automatiquement ajusté à 100%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 15),

            // Option distance
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CheckboxListTile(
                title: const Text('Bonus Proximité'),
                value: tempInclureDistance,
                onChanged: (value) {
                  setState(() => tempInclureDistance = value ?? true);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),

            const SizedBox(height: 10),

            // Boutons de réglage rapide
            const Text('Réglages rapides:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text('Équilibré', style: TextStyle(fontSize: 11)),
                    onPressed: () => _appliquerPreset(25, 25, 25, 25),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text('Focus expo', style: TextStyle(fontSize: 11)),
                    onPressed: () => _appliquerPreset(40, 30, 20, 10),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text('Focus hist.', style: TextStyle(fontSize: 11)),
                    onPressed: () => _appliquerPreset(20, 20, 20, 40),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text(
            'Valider',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () {
            // Ajuster automatiquement à 100%
            double facteurAjustement = 100.0 / totalPourcentages;

            final nouveauxParams = AppParameters(
              rayonDensite: tempRayonDensite.round(),
              poidExposants: tempPoidExposants * facteurAjustement,
              poidDensite: tempPoidDensite * facteurAjustement,
              poidRevenu: tempPoidRevenu * facteurAjustement,
              poidHistorique: tempPoidHistorique * facteurAjustement,
              inclureDistance: tempInclureDistance,
            );

            widget.onValidate(nouveauxParams);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildSlider(
      String label,
      double value,
      Color color,
      Function(double) onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: 0.0,
                max: 100.0,
                divisions: 20,
                label: '${value.round()}%',
                activeColor: color,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 50,
              child: Text('${value.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  void _appliquerPreset(double exp, double den, double rev, double hist) {
    setState(() {
      tempPoidExposants = exp;
      tempPoidDensite = den;
      tempPoidRevenu = rev;
      tempPoidHistorique = hist;
    });
  }
}
