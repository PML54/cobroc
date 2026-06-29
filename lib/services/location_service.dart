import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static const Map<String, List<int>> departementsLimitrophes = {
    '01': [38, 69, 42, 39, 74, 73],
    '02': [08, 51, 77, 60, 80, 59, 62],
    '03': [58, 18, 36, 23, 63, 42, 71],
    '04': [05, 83, 06, 84],
    '05': [04, 83, 06, 73, 38, 26],
    '06': [83, 04, 05, 73],
    '07': [26, 84, 30, 48, 43, 42, 69, 38],
    '08': [51, 55, 54, 02],
    '09': [31, 11, 66],
    '10': [51, 52, 21, 89, 77],
    '11': [09, 31, 81, 34, 66],
    '12': [48, 30, 34, 81, 82, 46, 15],
    '13': [84, 04, 83, 30],
    '14': [50, 61, 27, 76],
    '15': [48, 12, 46, 19, 63, 43],
    '16': [86, 87, 24, 17, 79],
    '17': [85, 79, 16, 24, 33],
    '18': [58, 45, 41, 36, 23, 03],
    '19': [46, 12, 15, 63, 23, 87, 24],
    '21': [52, 70, 39, 71, 58, 89, 10],
    '22': [35, 56, 29],
    '23': [87, 19, 15, 63, 03, 36, 86],
    '24': [87, 19, 46, 47, 33, 17, 16],
    '25': [70, 39, 01, 74, 73, 05, 26, 38, 69, 01, 39, 90],
    '26': [38, 73, 05, 04, 84, 07, 69],
    '27': [76, 60, 95, 78, 28, 61, 14],
    '28': [78, 91, 45, 41, 72, 61, 27],
    '29': [22, 56],
    '30': [48, 07, 84, 13, 34, 12],
    '31': [32, 65, 09, 11, 81, 82],
    '32': [40, 47, 82, 31, 65],
    '33': [40, 47, 24, 17],
    '34': [30, 12, 81, 11],
    '35': [56, 44, 49, 53, 50, 22],
    '36': [37, 41, 18, 23, 03, 86],
    '37': [86, 36, 41, 72, 49],
    '38': [73, 74, 01, 39, 71, 42, 07, 26, 05, 73],
    '39': [01, 25, 70, 21, 71, 42, 01],
    '40': [64, 65, 32, 47, 33],
    '41': [45, 18, 36, 37, 72, 28],
    '42': [71, 03, 63, 43, 07, 69, 38, 73, 01, 39],
    '43': [42, 63, 15, 48, 07],
    '44': [85, 49, 35, 56],
    '45': [77, 89, 58, 18, 41, 28, 91],
    '46': [82, 31, 09, 19, 15, 12, 82, 47, 24],
    '47': [33, 24, 46, 82, 32, 40],
    '48': [30, 84, 07, 43, 15, 12],
    '49': [85, 79, 86, 37, 72, 53, 35, 44],
    '50': [14, 61, 53, 35],
    '51': [08, 55, 54, 57, 77, 02, 10, 52],
    '52': [55, 88, 70, 21, 10, 51],
    '53': [72, 61, 14, 50, 35, 49],
    '54': [55, 57, 67, 88, 52, 51, 08],
    '55': [08, 51, 52, 88, 54, 57],
    '56': [22, 35, 44],
    '57': [67, 54, 55],
    '58': [89, 21, 71, 03, 18, 45],
    '59': [62, 80, 02],
    '60': [80, 02, 77, 95, 27, 76],
    '61': [14, 27, 28, 72, 53, 50],
    '62': [80, 59, 02],
    '63': [23, 19, 15, 43, 42, 03],
    '64': [40, 65],
    '65': [64, 40, 32, 31],
    '66': [09, 11],
    '67': [54, 57, 88, 68],
    '68': [67, 88, 90, 25],
    '69': [01, 38, 42, 71],
    '70': [88, 52, 21, 39, 25, 90],
    '71': [21, 39, 01, 69, 42, 03, 58],
    '72': [53, 61, 28, 41, 37, 49],
    '73': [38, 74, 01, 42, 05, 26],
    '74': [73, 01, 25, 26, 05],
    '75': [92, 93, 94],
    '76': [27, 14, 80, 60],
    '77': [60, 95, 78, 91, 45, 89, 10, 51, 02],
    '78': [92, 95, 27, 28, 91],
    '79': [85, 17, 16, 86, 49],
    '80': [76, 60, 02, 59, 62],
    '81': [82, 46, 12, 34, 11, 31],
    '82': [46, 47, 32, 31, 81],
    '83': [06, 04, 84, 13],
    '84': [26, 07, 30, 13, 83, 04],
    '85': [44, 49, 79, 17],
    '86': [79, 16, 23, 36, 37, 49],
    '87': [23, 19, 24, 16, 86],
    '88': [52, 70, 25, 68, 67, 54, 55],
    '89': [77, 45, 58, 21, 10],
    '90': [70, 25, 68],
    '91': [77, 78, 28, 45],
    '92': [75, 93, 94, 78, 95],
    '93': [75, 92, 94, 95, 77],
    '94': [75, 92, 93, 77],
    '95': [78, 92, 93, 77, 60, 27],
  };

  Future<LocationData?> obtenirPositionGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission de localisation refusée');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation définitivement refusée');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String? codePostal = place.postalCode;

        if (codePostal != null && codePostal.length >= 2) {
          String departement = codePostal.substring(0, 2);
          List<int> departementsProches = obtenirDepartementsLimitrophes(departement);

          return LocationData(
            latitude: position.latitude,
            longitude: position.longitude,
            departement: departement,
            departementsProches: departementsProches,
          );
        }
      }

      return null;
    } catch (e) {
      print('Erreur GPS: $e');
      return null;
    }
  }

  Future<LocationData?> obtenirPositionDepuisCoords(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final codePostal = placemarks.first.postalCode;
        if (codePostal != null && codePostal.length >= 2) {
          final departement = codePostal.substring(0, 2);
          return LocationData(
            latitude: lat,
            longitude: lon,
            departement: departement,
            departementsProches: obtenirDepartementsLimitrophes(departement),
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  List<int> obtenirDepartementsLimitrophes(String departement) {
    List<int> deps = [int.parse(departement)];

    if (departementsLimitrophes.containsKey(departement)) {
      deps.addAll(departementsLimitrophes[departement]!);
    }

    return deps.toSet().toList()..sort();
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final String? departement;
  final List<int> departementsProches;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.departement,
    required this.departementsProches,
  });
}