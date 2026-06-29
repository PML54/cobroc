import 'package:cobroc/models/filtre_exposants.dart';
import 'package:cobroc/pmltools.dart' show Brocabrac;

class FilterService {
  static List<Brocabrac> appliquerFiltres({
    required List<Brocabrac> brocantes,
    required FiltreCategorieExposants filtreExposants,
    required bool afficherHistorique,
    required bool Function(String) isInHistoric,
  }) {
    List<Brocabrac> resultat = List.from(brocantes);

    if (filtreExposants != FiltreCategorieExposants.tous) {
      resultat = resultat.where((broc) {
        int nbExposants = int.tryParse(broc.brocStarNbExposants) ?? 0;
        return matchFiltreExposants(nbExposants, filtreExposants);
      }).toList();
    }

    if (afficherHistorique) {
      resultat = resultat.where((broc) => isInHistoric(broc.brocLocality)).toList();
    }

    return resultat;
  }

  static bool matchFiltreExposants(
      int nbExposants,
      FiltreCategorieExposants filtre,
      ) {
    switch (filtre) {
      case FiltreCategorieExposants.moins50:
        return true;
      case FiltreCategorieExposants.de50a100:
        return nbExposants >= 50;
      case FiltreCategorieExposants.de100a200:
        return nbExposants >= 100;
      case FiltreCategorieExposants.de200a300:
        return nbExposants >= 200;
      case FiltreCategorieExposants.plus300:
        return nbExposants >= 300;
      default:
        return true;
    }
  }

  static String getLabelFiltre(FiltreCategorieExposants filtre) {
    switch (filtre) {
      case FiltreCategorieExposants.tous:
        return 'Tous';
      case FiltreCategorieExposants.moins50:
        return '≥ 0';
      case FiltreCategorieExposants.de50a100:
        return '≥ 50';
      case FiltreCategorieExposants.de100a200:
        return '≥ 100';
      case FiltreCategorieExposants.de200a300:
        return '≥ 200';
      case FiltreCategorieExposants.plus300:
        return '≥ 300';
    }
  }
}