import 'dart:math';

import 'package:cobroc/diverspml.dart';
import 'package:flutter/material.dart';

class ConfigTrajet {
  int codebrocante = 0;
  double centerLatitude;
  double centerLongitude;
  List<int> tripSelected = [];

  ConfigTrajet(this.codebrocante, this.centerLatitude, this.centerLongitude,
      this.tripSelected);
}

class MapCobrac extends StatefulWidget {
  const MapCobrac({key}) : super(key: key);

  @override
  _MapCobracState createState() => _MapCobracState();
}

class _MapCobracState extends State<MapCobrac> {
  // List to hold visibility status of buttons, all set to true initially
  List<bool> isVisible = List.generate(9, (_) => true);
  List<bool> DepFrance = [];

  ConfigTrajet configTrajet = ConfigTrajet(1, 0, 0, []);

  int selectedDepartement = 1;
  late Departement departement;
  List<int> Pourtour = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  List<int> ajusterListe(List<int> liste) {
    // Copie de la liste pour éviter de modifier l'originale
    List<int> nouvelleListe = List.from(liste);

    // Parcourir chaque valeur de la liste
    for (int i = 0; i < nouvelleListe.length; i++) {
      for (int j = i + 1; j < nouvelleListe.length; j++) {
        // Vérifier si deux valeurs sont identiques
        if (nouvelleListe[i] == nouvelleListe[j]) {
          bool ajuste = false;

          // Essayer de trouver une valeur inférieure libre
          for (int inf = nouvelleListe[j] - 1; inf >= 0; inf--) {
            if (!nouvelleListe.contains(inf)) {
              nouvelleListe[j] = inf;
              ajuste = true;
              break;
            }
          }

          // Si aucune valeur inférieure n'est libre, chercher une valeur supérieure libre
          if (!ajuste) {
            for (int sup = nouvelleListe[j] + 1; sup <= 7; sup++) {
              if (!nouvelleListe.contains(sup)) {
                nouvelleListe[j] = sup;
                ajuste = true;
                break;
              }
            }
          }

          // Si ni valeur inférieure ni supérieure n'est libre, erreur
          if (!ajuste) {
            print(
                "Erreur: Impossible de résoudre les doublons avec les règles données.");
            return liste; // Retourner la liste originale pour indiquer l'erreur
          }
        }
      }
    }

    return nouvelleListe;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Scaffold(
      appBar: AppBar(actions: <Widget>[
        Center(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.black,
                iconSize: 30.0,
                tooltip: 'Home',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.save),
                color: Colors.red,
                iconSize: 30.0,
                tooltip: 'Home',
                onPressed: () {
                  updateConfigTrajet();
                  print(configTrajet);
                  Navigator.pop(context, configTrajet);
                },
              ),
            ],
          ),
        ),
      ]),
      body: Center(
          child: Container(
        width: double.infinity,
        height: 500,
        // Hauteur exemple, ajustez selon le besoin
        color: Colors.lightBlue.shade100,
        // Couleur de fond pour visualiser l'espace
        //  child: CircularButtons(),
        child: LinearButtons(Pourtour),
      )),
      bottomNavigationBar: const Row(
          //crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            /*         IconButton(
              // unused
              icon: const Icon(Icons.arrow_back_outlined),

              iconSize: 25,
              color: Colors.blue,
              tooltip: '-1',
              onPressed: () {
                setState(() {

                });
              },
            ),
*/
          ] // This trailing comma makes auto-formatting nicer for build methods.
          ),
    ));
  }

  String getNom(int depart) {
    // return (lesDepartements[depart].)
    if (depart <= 0) return ("Error");
    departement = lesDepartements[depart - 1];
    return (departement.nom);
  }

  int calculerDistance(double lat1, double lon1, double lat2, double lon2) {
    var R = 6371e3; // Rayon de la Terre en mètres
    var phi1 = lat1 * pi / 180;
    var phi2 = lat2 * pi / 180;
    var deltaPhi = (lat2 - lat1) * pi / 180;
    var deltaLambda = (lon2 - lon1) * pi / 180;

    var a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return (R * c) ~/ 1000; // En mètres
  }

  double degToRad(double degrees) {
    return degrees * (pi / 180);
  }

  @override
  void initState() {
    super.initState();

    DepFrance.clear();
    for (int i = 0; i < 96; i++) {
      DepFrance.add(false);
    }

    majDistAngles(); //<PML>

    Pourtour.clear();
    departement = lesDepartements[95 - 1];
    Pourtour = List.from(
        departement.pourtour); // Crée une copie de departement.pourtour

    updateDepartement(95);
    setState(() {});
  }

  void majDistAngles() {
    for (Departement departement in lesDepartements) {
      departement.distances = List<int>.filled(departement.pourtour.length,
          0); // Initialisation avec la bonne taille

      for (int i = 0; i < departement.pourtour.length; i++) {
        var deptVoisinId = departement.pourtour[i];
        var deptVoisin =
            lesDepartements.firstWhere((d) => d.departement == deptVoisinId);

        var distance = calculerDistance(departement.latitude,
            departement.longitude, deptVoisin.latitude, deptVoisin.longitude);

        departement.distances[i] = distance; // Stocke la distance calculée
      }
      print(departement.distances);
    }

    for (Departement departement in lesDepartements) {
      for (int i = 0; i < departement.pourtour.length; i++) {
        var deptVoisinId = departement.pourtour[i];
        var deptVoisin =
            lesDepartements.firstWhere((d) => d.departement == deptVoisinId);

        var distance = calculerDistance(departement.latitude,
            departement.longitude, deptVoisin.latitude, deptVoisin.longitude);
      }
    }
  }



  void updateDepartement(int thisdepart) {
    setState(() {
      selectedDepartement = thisdepart;

      if (selectedDepartement == 0) return;
      departement = lesDepartements[selectedDepartement - 1];
      Pourtour.clear();
      print(departement.pourtour);
      Pourtour.addAll(departement.pourtour
          .toList()); // Crée une nouvelle liste à partir de departement.pourtour

      Pourtour.insert(0, departement.departement);

      print(Pourtour.length.toString());
      print('updateDepartement');
    });
  }

  void toggleVisibility(int index) {
    setState(() {
      print('index = $index');
      //isVisible[index] = !isVisible[index];  // unused
      updateDepartement(index);
    });
  }

  updateConfigTrajet() {
    configTrajet.tripSelected.clear();
    for (int j = 0; j < Pourtour.length; j++) {
      if (Pourtour[j] > 0) {
        configTrajet.tripSelected.add(Pourtour[j]);
      }
    }
    configTrajet.codebrocante = 999;
  }

  Widget LinearButtons(List<int> pourtour) {
    List<int> itemsToShow = pourtour; //<PML>

    // Calculer la largeur des boutons basée sur la largeur de l'écran
    double buttonWidth =
        MediaQuery.of(context).size.width / itemsToShow.length -
            10; // 10 pour l'espacement

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          // Espacement équilibré entre les boutons
          children: itemsToShow.map((item) {
            return Visibility(
              visible: item > 0,
              child: Tooltip(
                message: getNom(item),
                textStyle: const TextStyle(
                  color: Colors.white, // Couleur du texte
                  fontSize: 16, // Taille du texte
                  fontWeight: FontWeight.bold, // Épaisseur du texte
                ),
                child: ElevatedButton(
                  onPressed: () {
                    var lerang = Pourtour.indexOf(item);

                    toggleVisibility(Pourtour[lerang]);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(buttonWidth, 40),
                    // Taille minimale pour chaque bouton
                    shape: const CircleBorder(),
                    // Forme circulaire du bouton
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                    // Ajustement de l'espacement autour de l'icône
                    backgroundColor: Colors.blue,
                    // Couleur de fond du bouton
                    foregroundColor:
                        Colors.white, // Couleur du texte ou de l'icône
                  ),
                  child: Text(item.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize:
                              12)), // Réduire la taille du texte pour économiser de l'espace
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

//</HASH>
}
