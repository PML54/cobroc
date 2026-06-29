
// ==========================================
// 📁 lib/widgets/brocante/brocante_list_reduce.dart
// ==========================================
import 'package:flutter/material.dart';
import 'package:cobroc/pmltools.dart' show Brocabrac;
import 'package:cobroc/histeric.dart' show Histeric;

class BrocanteListReduce extends StatelessWidget {
  final List<Brocabrac> brocantes;
  final bool Function(String) isInHistoric;
  final int secureHistory;

  const BrocanteListReduce({
    super.key,
    required this.brocantes,
    required this.isInHistoric,
    required this.secureHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        controller: ScrollController(),
        itemCount: brocantes.length,
        itemBuilder: (context, index) {
          final brocante = brocantes[index];

          return ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatLocalite(brocante),
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Serif',
                    color: brocante.brocDejaVu == "New"
                        ? Colors.black
                        : Colors.blue,
                  ),
                ),
                Text(
                  '${brocante.brocFromSelect}km - ${brocante.brocStarNbExposants} Exp ${brocante.brocStarRevenu}€',
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'Serif',
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            dense: true,
            onTap: () {},
            onLongPress: () {
              if (isInHistoric(brocante.brocLocality) && secureHistory == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Histeric(),
                    settings: RouteSettings(
                      arguments: brocante.brocLocality,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  String _formatLocalite(Brocabrac brocante) {
    String postalPrefix = brocante.brocPostal.substring(0, 2);
    String locality = brocante.brocLocality;
    String combined = '$locality ($postalPrefix)';

    if (combined.length > 14) {
      int charsToKeep = 14 - postalPrefix.length - 3;
      if (charsToKeep < 1) charsToKeep = 1;
      return '${locality.substring(0, charsToKeep)}... ($postalPrefix)';
    }
    return combined;
  }
}