// lib/detailedBrocante.dart
// Modified: 260606161500
// Détail brocante — analyse historique
// CHANGEMENTS: (1) analyzeBrocante: remplace toUpperCase par Historic.matchesVille pour match partiel, ligne 259
import 'package:cobroc/historibroc.dart' show Historic, listHistoric;
import 'package:cobroc/pmltools.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

double safeAverage(Iterable<num> numbers) {
  if (numbers.isEmpty) return 0;
  double sum = numbers.fold(0.0, (prev, element) => prev + element.toDouble());
  return sum / numbers.length;
}

String findMostRecentDate(List<Historic> entries) {
  if (entries.isEmpty) return "Aucune date";
  entries.sort((a, b) {
    DateTime dateA = DateFormat("dd/MM/yyyy").parse(a.histDate);
    DateTime dateB = DateFormat("dd/MM/yyyy").parse(b.histDate);
    return dateB.compareTo(dateA);
  });
  return entries.first.histDate;
}



class DetailBroc extends StatefulWidget {
  const DetailBroc({super.key});

  @override
  _DetailBrocState createState() => _DetailBrocState();
}

class _DetailBrocState extends State<DetailBroc> {
  String thatbrocType = "";
  String thatbrocLocality = "";
  String thatbrocPostal = "";
  String thatbrocStreet = "";
  double thatbrocLatitude = 0.0;
  double thatbrocLongitude = 0.0;
  String thatbrocEventStatus = "";
  String thatbrocVenueName = "";
  String thatbrocOrganizer = "";
  String thatbrocStartDate = "";
  String thatbrocEndDate = "";
  String thatbrocDescription = "";
  String thatbrocNbExposants = "";
  String thatbrocStarBarycentre = "";
  String thatbrocEventId = "";
  int thatbrocDistance = 0;
  Color thatColor = Colors.green;

  double altitude = 0.0;
  double superficie = 0.0;
  double population = 0.0;
  int codeDepartement = 0;
  int codeRegion = 0;
  int thatRevenu = 0;
  int masterBroc = 0;
  int nbPassage = 0;
  late ManageCobrac manageCobrac;
  late Brocabrac thatBrocante;
  List<Brocabrac> allBrocante = [];
  Color colorBrocor = Colors.grey;
  Map<String, dynamic> brocAnalysis = {};

  @override
  Widget build(BuildContext context) {
    if (nbPassage == 0) {
      var arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is ManageCobrac) {
        manageCobrac = arguments;
      }
      print("nb Passage= $nbPassage");
      allBrocante = manageCobrac.brocanteBrocabrac;
      thatBrocante = manageCobrac.brocabrac;
      nbPassage = 1;
      masterBroc = thatBrocante.brocMaster - 1;
      print("masterBroc (build)$masterBroc");
    } else {
      thatBrocante = allBrocante[masterBroc];
    }
    readActiveRecord();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "$thatbrocDistance km $thatbrocLocality",
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            iconSize: 25,
            color: masterBroc > 0 ? Colors.red : Colors.grey,
            onPressed: () {
              if (masterBroc > 0) {
                bool answer = getPrevRecord();
                if (answer) {
                  setState(() {
                    readActiveRecord();
                  });
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            iconSize: 25,
            color: Colors.red,
            tooltip: 'brocabrac',
            onPressed: () {
              bool answer = getNextRecord();
              if (answer == true) {
                setState(() {
                  readActiveRecord();
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildDescriptionCard(),
            const SizedBox(height: 16),
            _buildAnalysisCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$thatbrocPostal $thatbrocLocality",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: thatColor),
            ),
            const SizedBox(height: 8),
            Text("Identifiant Brocabrac = $thatbrocEventId"),
            Text("Lieu = $thatbrocVenueName", style: const TextStyle(color: Colors.blue)),
            Text(thatbrocStreet),
            Text("$thatbrocNbExposants Exposants"),
            Text("Revenu Moyen = $thatRevenu€"),
            Text("Organisateur = $thatbrocOrganizer"),
            Text("Avec $thatbrocStarBarycentre Brocantes à moins de 15 km"),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(thatbrocDescription),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Analyse de la brocante", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (brocAnalysis.isNotEmpty)
              ...brocAnalysis.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key.replaceAll('_', ' ').capitalize()),
                    Text(entry.value.toString()),
                  ],
                ),
              ))
            else
              const Text('Aucune donnée d\'analyse disponible', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void readActiveRecord() {
    setState(() {
      thatbrocType = thatBrocante.brocType;
      thatbrocLocality = thatBrocante.brocLocality;
      thatbrocPostal = thatBrocante.brocPostal;
      thatbrocStreet = thatBrocante.brocStreet;
      thatbrocLatitude = thatBrocante.brocLatitude;
      thatbrocLongitude = thatBrocante.brocLongitude;
      thatbrocEventStatus = thatBrocante.brocEventStatus;
      thatbrocOrganizer = thatBrocante.brocOrganizer;
      thatbrocStartDate = thatBrocante.brocStartDate;
      thatbrocEndDate = thatBrocante.brocEndDate;
      thatbrocDescription = thatBrocante.brocDescription;
      thatbrocNbExposants = thatBrocante.brocNbExposants;
      thatbrocDistance = thatBrocante.brocFromCenter;
      thatRevenu = thatBrocante.revenu;
      thatbrocVenueName = thatBrocante.brocVenueName;
      thatbrocStarBarycentre = thatBrocante.brocStarBarycentre;
      thatbrocEventId = thatBrocante.eventId;
      thatColor = Colors.green;
      if (thatbrocEventStatus == "KO") {
        thatColor = Colors.red;
        thatbrocEventStatus = "Brocante Annulée!!";
      } else {
        thatbrocEventStatus = "";
      }
      brocAnalysis = analyzeBrocante(thatbrocLocality);
    });
  }

  bool getNextRecord() {
    if (masterBroc >= allBrocante.length - 1) return false;
    setState(() {
      masterBroc = masterBroc + 1;
      print("masterBroc=$masterBroc");
      print("allBrocante.length=${allBrocante.length}");
      thatBrocante = allBrocante[masterBroc];
    });
    return (true);
  }

  bool getPrevRecord() {
    if (masterBroc < 0) return false;
    setState(() {
      masterBroc--;
      thatBrocante = allBrocante[masterBroc];
      readActiveRecord();
    });
    return true;
  }
  Map<String, dynamic> analyzeBrocante(String ville) {
    var cityEntries = listHistoric.where((h) => Historic.matchesVille(h.histVille, ville)).toList();

    if (cityEntries.isEmpty) {
      return {'error': 'Aucune donnée historique trouvée pour cette ville'};
    }

    double avgQuality = safeAverage(cityEntries.map((e) => e.histGood).where((e) => e > 0));
    double avgSize = safeAverage(cityEntries.map((e) => e.histNbExpo).where((e) => e > 0));
    double avgSpending = safeAverage(cityEntries.map((e) => (e.histPmlDep + e.histFraDep + e.histMaisonDep)).where((e) => e > 0));
    int frequency = cityEntries.length;
    String lastDate = findMostRecentDate(cityEntries);

    if (avgQuality == 0 && avgSize == 0 && avgSpending == 0) {
      return {'error': 'Données insuffisantes pour une analyse complète'};
    }

    var allComments = cityEntries.map((e) => "${e.histAvis} ${e.histDetail}").join(" ");
    var positiveWords = ['bon', 'bien', 'super', 'intéressant', 'qualité'];
    var negativeWords = ['mauvais', 'pauvre', 'décevant', 'éviter', 'rien'];
    int positiveCount = positiveWords.fold(0, (sum, word) => sum + allComments.toLowerCase().split(word).length - 1);
    int negativeCount = negativeWords.fold(0, (sum, word) => sum + allComments.toLowerCase().split(word).length - 1);

    int qualityScore = (avgQuality / 5 * 20).round();
    int sizeScore = (min(avgSize / 300, 1) * 20).round();
    int spendingScore = (min(avgSpending / 100, 1) * 20).round();
    int consistencyScore = (min(frequency / 10, 1) * 20).round();
    int commentScore = positiveCount > negativeCount ? 16 : (positiveCount < negativeCount ? 8 : 12);

    int overallScore = ((qualityScore + sizeScore + spendingScore + consistencyScore + commentScore) / 5).round();

    return {
      'ville': ville,
      'qualité': '$qualityScore/20',
      'taille': '$sizeScore/20',
      'dernière Visite': lastDate,  // Ajout de la dernière date
      'potentiel_achat': '$spendingScore/20',
      // 'constance': '$consistencyScore/20',
      'commentaires': '$commentScore/20',
      'note_globale': '$overallScore/20',
      'fréquence': frequency,
      'taille_moyenne': '${avgSize.round()} exposants',
      'dépense_moyenne': '${avgSpending.round()}€',
      'commentaires': 'Positifs: $positiveCount, Négatifs: $negativeCount',


    };
  }
// Fonction utilitaire pour limiter une valeur
  double min(double a, double b) => (a < b) ? a : b;
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}