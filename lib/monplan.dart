import 'dart:math';

import 'package:cobroc/detailedBrocante.dart';
import 'package:cobroc/pmltools.dart' show Brocabrac, ManageCobrac;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeoUtils {
  static double distanceInKmBetweenEarthCoordinates(lat1, lon1, lat2, lon2) {
    var earthRadiusKm = 6371;
    var dLat = _degreesToRadians(lat2 - lat1);
    var dLon = _degreesToRadians(lon2 - lon1);
    lat1 = _degreesToRadians(lat1);
    lat2 = _degreesToRadians(lat2);
    var a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(degrees) {
    return degrees * pi / 180;
  }
}

class MonPlan extends StatefulWidget {
  const MonPlan({super.key});

  @override
  _MonPlanState createState() => _MonPlanState();
}

class _MonPlanState extends State<MonPlan> {
  final List<bool> isVisible = List.generate(9, (_) => true);
  final List<int> pourtour = List.filled(10, 0);
  final List<int> monTrajet = [];
  final List<int> etape = [0, 0];
  final List<int> spotsArray = List.filled(5, -1);
  final List<Color> colorsList = [
    Colors.orangeAccent,
    Colors.deepPurple,
    Colors.blue,
    Colors.brown,
    Colors.purpleAccent
  ];

  Map<int, List<int>> graphe = {};
  List<Brocabrac> brocanteBrocabrac = [];
  List<Brocabrac> brocanteBrocabracFull = [];
  List<Brocabrac> brocanteBrocabracBis = [];
  Map<String, int> userSpots = {};

  late final MapController mapController = MapController();
  var pifoMetre = 1.27;
  double initialZoom = 12.0;
  int currentMarkerIndex = 0;
  int selectedDepartement = 1;
  int rayonAction = 20;
  int localRayonAction = 250; //<PML>
  String brocSpot = "PONTOISE";
  bool flagHeart = false;
  int nbBrocOK = 0;

  double latitudeLarris = 49.05;
  double longitudeLarris = 2.1;
  double latitudePortbail = 49.333;
  double longitudePortbail = -1.7;
  double latitudeSelect =  49.05;
  double longitudeSelect = 2.1;
  DateTime now = DateTime.now();

  void adjustRayonAction(int increment) {
    setState(() {
      rayonAction = (rayonAction + increment).clamp(0, 240);
      resetDistance();
    });
  }

  void adjustZoom(double increment) {
    setState(() {
      initialZoom = (initialZoom + increment).clamp(0, 15.0);
      mapController.move(mapController.camera.center, initialZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: buildAppBar(),
        body: buildMap(),
        bottomNavigationBar: buildBottomNavigationBar(),
      ),
    );
  }

  /*AppBar buildAppBar() {
    return AppBar(
      actions: <Widget>[
        Row(

          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_left),
              iconSize: 35,
              onPressed: gotoPreviousMarker,
            ),
            displayZoomButton(brocSpot),
            IconButton(
              icon: const Icon(Icons.arrow_right),
              iconSize: 35,
              onPressed: gotoNextMarker,
            ),

          ],
        ),

      ],
    );
  }*/

  AppBar buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_left),
        onPressed: gotoPreviousMarker,
      ),
      title: displayZoomButton(brocSpot),  // Placez le zoom button au centre
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_right),
          onPressed: gotoNextMarker,
        ),
      ],
    );
  }








  Widget buildBottomNavigationBar() {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.close),
          color: Colors.red,
          iconSize: 40.0,
          tooltip: 'Quitter',
          onPressed: () => Navigator.pop(context),
        ),
        IconButton(
          icon: const Icon(Icons.heart_broken),
          color: Colors.red,
          iconSize: 30.0,
          tooltip: 'Favori',
          onPressed: toggleHeart,
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle),
          onPressed: () => adjustRayonAction(-10),
        ),
        displayZoomButton('$rayonAction km'),
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: () => adjustRayonAction(10),
        ),
        IconButton(
          icon: const Icon(Icons.zoom_out),
          onPressed: () {
            adjustZoom(-0.5);
          },
        ),
        displayZoomButton(brocSpot),
        //   displayZoomButton('$initialZoom'),
        IconButton(
          icon: const Icon(Icons.zoom_in),
          onPressed: () {
            adjustZoom(0.5);
          },
        ),
      ],
    );
  }

  FlutterMap buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
       initialCenter: const LatLng(49.05, 2.1),
        //  double latitudePortbail = 49.333;
        //   double longitudePortbail = -1.7;
       // initialCenter: const LatLng(49.333,-1.7),
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pml.cobroc',
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
        MarkerLayer(markers: buildMarkersFromData(brocanteBrocabrac)),
      ],
    );
  }

  List<Marker> buildMarkersFromData(List<Brocabrac> data) {
    return data
        .asMap()
        .map((index, brocabrac) {
          return MapEntry(
              index,
              Marker(
                point: LatLng(brocabrac.brocLatitude, brocabrac.brocLongitude),
                width: 80,
                height: 80,
                child: IconButton(
                  icon: const Icon(Icons.flag),
                  iconSize: index == currentMarkerIndex ? 40.0 : 25.0,
                  color: determineColor(brocabrac.brocStarNbExposants),
                  tooltip:
                      '${brocabrac.brocLocality} : \n${brocabrac.brocNbExposants} exposants \n${brocabrac.brocFromCenter} km des Larris \n${brocabrac.brocFromSelect} km  de $brocSpot',
                  onPressed: () {
                    navigateToDetails(brocabrac);
                  },
                ),
              ));
        })
        .values
        .toList();
  }

  void computeNewDistanceFromSelect() {
    for (Brocabrac _brocky in brocanteBrocabrac) {
      double latitudeTo = _brocky.brocLatitude;
      double longitudeTo = _brocky.brocLongitude;

      double bricolo = GeoUtils.distanceInKmBetweenEarthCoordinates(
          latitudeSelect, longitudeSelect, latitudeTo, longitudeTo);
      int initialdist = (bricolo * pifoMetre).round();
      _brocky.brocFromSelect = initialdist;
    }

    setState(() {
      nbBrocOK = brocanteBrocabrac
          .where((brocabrac) => brocabrac.brocEventStatus == 'OK')
          .length;
      brocanteBrocabrac
          .retainWhere((brocabrac) => brocabrac.brocEventStatus == 'OK');
    });

    nbBrocOK = 0;
    for (var brocabrac in brocanteBrocabrac) {
      setState(() {
        nbBrocOK++;
      });
      brocabrac.brocMaster = nbBrocOK; // indicateur Index pour les flèches
    }
    for (Brocabrac _brocky in brocanteBrocabrac) {
      //print("DistanceCheck  ${_brocky.brocLocality}: ${_brocky.brocFromSelect}");
    }
  }

  Color determineColor(String nbExposants) {
    int count = int.tryParse(nbExposants) ?? 0;
    if (count >= 300) return Colors.green;
    if (count >= 250) return Colors.green;
    if (count >= 150) return Colors.blue;
    if (count >= 75) return Colors.blue;
    if (count >= 25) return Colors.orange;
    return Colors.red; // Default for less than 25 exposants
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as List<Brocabrac>?;
    if (args != null) {
      brocanteBrocabracFull = args;
      resetDistance();
    }
  }

  ElevatedButton displayZoomButton(String label) {
    return ElevatedButton(
      onPressed: null,
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white), // Définit la couleur du texte en blanc
      ),
    );
  }

  void gotoNextMarker() {
    print ('gotoNextMarker');
    if (currentMarkerIndex < brocanteBrocabrac.length - 1) {
      setState(() {
        currentMarkerIndex++;

        updateMarkerLocation();
        resetDistanceLocal();
      });
    }
  }

  void gotoPreviousMarker() {
    if (currentMarkerIndex > 0) {
      setState(() {
        currentMarkerIndex--;

        updateMarkerLocation();
        resetDistanceLocal();
      });
    }
  }

  void navigateToDetails(Brocabrac brocabrac) {
    ManageCobrac manageCobrac = ManageCobrac(brocanteBrocabrac, brocabrac);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DetailBroc(),
        settings: RouteSettings(
          arguments: manageCobrac,
        ),
      ),
    );
  }

  void resetBrocabrac() {
    brocanteBrocabrac.clear();
    brocanteBrocabrac.addAll(brocanteBrocabracFull);
  }

  void resetDistance() {
    brocanteBrocabrac.clear();
    brocanteBrocabrac.addAll(
      brocanteBrocabracFull.where((item) => item.brocFromCenter <= rayonAction),
    );
  }

  void resetDistanceLocal() {
    computeNewDistanceFromSelect();

    setState(() {});
  }

  void resetHeart() {
    brocanteBrocabrac.clear();
    brocanteBrocabrac
        .addAll(brocanteBrocabracFull.where((item) => item.brocLove == "❤"));
  }

  void toggleHeart() {
    setState(() {
      flagHeart = !flagHeart;
      flagHeart ? resetHeart() : resetBrocabrac();
    });
  }

  void updateMarkerLocation() {
    print("currentMarkerIndex = $currentMarkerIndex");
    print("brocanteBrocabrac = ${brocanteBrocabrac.length.toString()}");

    LatLng newCenter = LatLng(
      brocanteBrocabrac[currentMarkerIndex].brocLatitude,
      brocanteBrocabrac[currentMarkerIndex].brocLongitude,
    );

    mapController.move(newCenter, mapController.zoom);
    brocSpot = brocanteBrocabrac[currentMarkerIndex].brocLocality;
    latitudeSelect = brocanteBrocabrac[currentMarkerIndex].brocLatitude;
    longitudeSelect = brocanteBrocabrac[currentMarkerIndex].brocLongitude;

    print("updateMarkerLocation  $latitudeSelect $longitudeSelect");
  }
}
