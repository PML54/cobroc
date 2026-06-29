import 'package:cobroc/pmltools.dart' show Brocabrac;
import 'package:cobroc/services/geo_service.dart';

class ScoringService {
  final int rayonDensite;
  final double poidExposants;
  final double poidDensite;
  final double poidRevenu;
  final double poidHistorique;
  final bool inclureDistance;

  ScoringService({
    required this.rayonDensite,
    required this.poidExposants,
    required this.poidDensite,
    required this.poidRevenu,
    required this.poidHistorique,
    required this.inclureDistance,
  });

  double calculerScoreOptimal(
      Brocabrac brocante,
      List<Brocabrac> toutesLesBrocantes,
      bool Function(String) isInHistoric,
      ) {
    if (brocante.brocEventStatus != 'OK') return 0.0;

    final scoreExposants = getScoreExposants(brocante.brocStarNbExposants);
    final scoreDensitePonderee = calculerDensitePonderee(brocante, toutesLesBrocantes);
    final scoreRevenu = double.tryParse(brocante.brocStarRevenu) ?? 0.0;
    final scoreHistorique = getScoreHistorique(brocante.brocLocality, isInHistoric);
    final scoreDistance = inclureDistance
        ? getScoreDistance(brocante.brocFromCenter)
        : 5.0;

    double scoreBase = (scoreExposants * poidExposants / 100.0) +
        (scoreDensitePonderee * poidDensite / 100.0) +
        (scoreRevenu * poidRevenu / 100.0) +
        (scoreHistorique * poidHistorique / 100.0);

    double scoreFinal = scoreBase;
    if (inclureDistance) {
      scoreFinal = scoreBase * (0.8 + (scoreDistance / 5.0) * 0.2);
    }

    return ((scoreFinal / 5.0) * 98.0 + 1.0).clamp(1.0, 99.0);
  }

  double calculerDensitePonderee(
      Brocabrac brocanteCentrale,
      List<Brocabrac> toutesLesBrocantes,
      ) {
    double scoreDensite = 0.0;
    int compteur = 0;

    for (var autreBrocante in toutesLesBrocantes) {
      if (autreBrocante.brocEventStatus == 'OK' &&
          autreBrocante != brocanteCentrale) {
        final distance = GeoService.distanceInKmBetweenEarthCoordinates(
          brocanteCentrale.brocLatitude,
          brocanteCentrale.brocLongitude,
          autreBrocante.brocLatitude,
          autreBrocante.brocLongitude,
        );

        if (distance <= rayonDensite && distance > 1) {
          final scoreExposantsVoisin = getScoreExposants(autreBrocante.brocStarNbExposants);
          final facteurDistance = (rayonDensite - distance) / rayonDensite;
          scoreDensite += scoreExposantsVoisin * facteurDistance;
          compteur++;
        }
      }
    }

    return compteur > 0 ? (scoreDensite / compteur).clamp(0.0, 5.0) : 0.0;
  }

  Map<String, int> calculerTousLesClassements(
      List<Brocabrac> brocantes,
      bool Function(String) isInHistoric,
      ) {
    List<MapEntry<Brocabrac, double>> scoresAvecBrocantes = [];

    for (var brocante in brocantes) {
      if (brocante.brocEventStatus == 'OK' && brocante.eventId.isNotEmpty) {
        final score = calculerScoreOptimal(brocante, brocantes, isInHistoric);
        scoresAvecBrocantes.add(MapEntry(brocante, score));
      }
    }

    scoresAvecBrocantes.sort((a, b) => b.value.compareTo(a.value));

    Map<String, int> classements = {};
    for (int i = 0; i < scoresAvecBrocantes.length; i++) {
      String eventId = scoresAvecBrocantes[i].key.eventId;
      classements[eventId] = i + 1;
    }

    return classements;
  }

  List<Brocabrac> creerTop10(
      List<Brocabrac> brocantes,
      Map<String, int> classements,
      ) {
    List<Brocabrac> top10 = [];

    var entriesTop10 = classements.entries
        .where((entry) => entry.value <= 10)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (var entry in entriesTop10) {
      String eventId = entry.key;
      Brocabrac? brocante = brocantes
          .cast<Brocabrac?>()
          .firstWhere((b) => b?.eventId == eventId, orElse: () => null);

      if (brocante != null) {
        top10.add(brocante);
      }
    }

    return top10;
  }

  double getScoreExposants(String nbExposantsStr) {
    int nbExp = int.tryParse(nbExposantsStr) ?? 0;
    if (nbExp >= 300) return 5.0;
    if (nbExp >= 250) return 4.0;
    if (nbExp >= 150) return 3.0;
    if (nbExp >= 75) return 2.0;
    if (nbExp >= 25) return 1.0;
    return 0.5;
  }

  double getScoreDistance(int distanceKm) {
    if (distanceKm <= 10) return 5.0;
    if (distanceKm <= 20) return 4.0;
    if (distanceKm <= 40) return 3.0;
    if (distanceKm <= 60) return 2.0;
    if (distanceKm <= 100) return 1.0;
    return 0.5;
  }

  double getScoreHistorique(String ville, bool Function(String) isInHistoric) {
    if (!isInHistoric(ville)) return 2.5;
    return 3.5;
  }
}