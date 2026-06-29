import 'dart:math';

class GeoService {
  static double distanceInKmBetweenEarthCoordinates(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadiusKm = 6371;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1Rad) * cos(lat2Rad);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  static int compterBrocantesProches({
    required double latitudeFrom,
    required double longitudeFrom,
    required List<dynamic> toutesLesBrocantes,
    required int rayonKm,
    double facteurConversion = 1.27,
  }) {
    int count = 0;

    for (var brocante in toutesLesBrocantes) {
      if (brocante.brocEventStatus != 'OK') continue;

      final distance = distanceInKmBetweenEarthCoordinates(
        latitudeFrom,
        longitudeFrom,
        brocante.brocLatitude,
        brocante.brocLongitude,
      );

      final distanceAjustee = (distance * facteurConversion).round();

      if (distanceAjustee > 1 && distanceAjustee <= rayonKm) {
        count++;
      }
    }

    return count;
  }
}