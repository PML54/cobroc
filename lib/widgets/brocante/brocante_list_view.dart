// ==========================================
// 📋 lib/widgets/brocante/brocante_list_view.dart
// ==========================================
import 'package:flutter/material.dart';
import 'package:cobroc/pmltools.dart' show Brocabrac, ManageCobrac;

class BrocanteListView extends StatelessWidget {
  final List<Brocabrac> brocantes;
  final Map<String, int> classementOptimal;
  final Function(Brocabrac) onTap;
  final Function(Brocabrac) onLongPress;
  final Function(Brocabrac) onDoubleTap;
  final Color Function(String, String) getCouleurClassement;

  const BrocanteListView({
    super.key,
    required this.brocantes,
    required this.classementOptimal,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
    required this.getCouleurClassement,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        controller: ScrollController(),
        itemCount: brocantes.length,
        itemBuilder: (context, index) {
          Brocabrac brocante = brocantes[index];
          bool estTop10 = _estDansTop10(brocante.eventId);
          int rang = _getRangClassement(brocante.eventId);
          bool estKO = brocante.brocEventStatus != 'OK';

          final couleurTexte = estKO
              ? const Color(0xFFD50000) // rouge écarlate
              : Colors.black;

          return InkWell(
            onTap: () => onTap(brocante),
            onLongPress: () => onLongPress(brocante),
            onDoubleTap: () => onDoubleTap(brocante),
            child: ListTile(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (estKO) const Text("KO ", style: TextStyle(fontSize: 11, color: Color(0xFFD50000), fontWeight: FontWeight.bold)),
                      if (rang == 1) const Text("🥇 ", style: TextStyle(fontSize: 12)),
                      if (rang == 2) const Text("🥈 ", style: TextStyle(fontSize: 12)),
                      if (rang == 3) const Text("🥉 ", style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          _formatLocalite(brocante),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Serif',
                            color: couleurTexte,
                            fontWeight: rang <= 3 ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${brocante.brocFromCenter} km - ${brocante.brocStarNbExposants} Exp${_getDensiteAffichage(brocante.brocStarBarycentre)} ${brocante.brocLove}',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Serif',
                      color: couleurTexte,
                      fontWeight: rang <= 3 ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            ),
          );
        },
      ),
    );
  }

  String _formatLocalite(Brocabrac brocante) {
    String postalPrefix = brocante.brocPostal.substring(0, 2);
    String locality = brocante.brocLocality;
    String combined = '$locality ($postalPrefix)';

    if (combined.length > 15) {
      int charsToKeep = 15 - postalPrefix.length - 3;
      if (charsToKeep < 1) charsToKeep = 1;
      return '${locality.substring(0, charsToKeep)}..($postalPrefix)';
    }
    return combined;
  }

  bool _estDansTop10(String eventId) {
    int? rang = classementOptimal[eventId];
    return rang != null && rang <= 10;
  }

  int _getRangClassement(String eventId) {
    return classementOptimal[eventId] ?? 999;
  }

  String _getDensiteAffichage(String densiteStr) {
    int densiteValue = int.tryParse(densiteStr) ?? 0;
    if (densiteValue > 0) return ' - D:$densiteStr';
    return '';
  }
}