// lib/histeric.dart
// Modified: 2606170752
// Histeric — navigation dans l'historique par commune
// CHANGEMENTS: (1) buildHistoricDetails: affichage conditionnel heureArrivee + badges contexte (pluie, arriveeTard, parking, rues, stade, espace) lignes 104-107, (2) ajout buildContexte()/_badge() lignes 113-142
import 'package:cobroc/historibroc.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';

class Histeric extends StatefulWidget {
  const Histeric({super.key});

  @override
  _HistericState createState() => _HistericState();
}

class _HistericState extends State<Histeric> {
  List<Historic> myHistoric = [];
  Historic? currentHistoric;

  @override
  Widget build(BuildContext context) {
    final String thatCommune =
        ModalRoute.of(context)?.settings.arguments as String? ?? "";
    if (myHistoric.isEmpty) {
      loadHistorics(thatCommune);
    }

    return Scaffold(
      appBar: buildAppBar(),
      body: currentHistoric == null
          ? const Center(child: Text("No data available"))
          : buildHistoricDetails(),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      actions: <Widget>[
        navigationButton(Icons.arrow_back, decrementRecord),
        navigationButton(Icons.laptop, () {}),
        navigationButton(Icons.arrow_forward, incrementRecord),
      ],
    );
  }

  Widget navigationButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      color: Colors.green,
      iconSize: icon == Icons.laptop ? 30.0 : 60.0,
      tooltip: 'Navigate',
      onPressed: onPressed,
    );
  }

  void loadHistorics(String commune) {
    myHistoric = listHistoric
        .where((historic) => Historic.matchesVille(historic.histVille, commune))
        .toList();
    myHistoric.sort((a, b) => b.histCheckDate.compareTo(a.histCheckDate));
    if (myHistoric.isNotEmpty) {
      setState(() => currentHistoric = myHistoric.first);
    }
  }

  void incrementRecord() {
    int currentIndex = myHistoric.indexOf(currentHistoric!);
    if (currentIndex < myHistoric.length - 1) {
      setState(() => currentHistoric = myHistoric[++currentIndex]);
    }
  }

  void decrementRecord() {
    int currentIndex = myHistoric.indexOf(currentHistoric!);
    if (currentIndex > 0) {
      setState(() => currentHistoric = myHistoric[--currentIndex]);
    }
  }

  Widget buildHistoricDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${currentHistoric!.histName} : #${currentHistoric!.histDate}#',
              style: TextStyle(
                  fontSize: 20,
                  color: getColorByRating(currentHistoric!.histGood))),
          Text('Exposants: <${currentHistoric!.histNbExpo}>',
              style: const TextStyle(fontSize: 20)),
          Text('Commune: ${currentHistoric!.histVille}',
              style: TextStyle(
                  fontSize: 18,
                  color: getColorByRating(currentHistoric!.histGood))),
          Text('Adresse: ${currentHistoric!.histAdresse}',
              style: TextStyle(
                  fontSize: 22,
                  color: getColorByRating(currentHistoric!.histGood))),
          Text('Avis: ${currentHistoric!.histAvis}',
              style: const TextStyle(fontSize: 18)),
          Text('Détails: ${currentHistoric!.histDetail}',
              style: const TextStyle(fontSize: 16)),
          if (currentHistoric!.heureArrivee.isNotEmpty)
            Text('Arrivée: ${currentHistoric!.heureArrivee}',
                style: const TextStyle(fontSize: 16)),
          buildContexte(),
        ],
      ),
    );
  }

  // Affichage conditionnel des champs « contexte » (export enrichi).
  // N'affiche que les indicateurs renseignés (= 1) pour la visite courante.
  Widget buildContexte() {
    final h = currentHistoric!;
    final badges = <Widget>[
      if (h.pluie == 1) _badge('🌧 Pluie', Colors.blueGrey),
      if (h.arriveeTard == 1) _badge('⏰ Arrivée tardive', Colors.brown),
      if (h.parking == 1) _badge('🅿️ Parking', Colors.indigo),
      if (h.rues == 1) _badge('🏘️ Rues', Colors.indigo),
      if (h.stade == 1) _badge('🏟️ Stade', Colors.indigo),
      if (h.espace == 1) _badge('🌳 Espace', Colors.indigo),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: badges),
    );
  }

  Widget _badge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade300),
      ),
      child: Text(label, style: TextStyle(fontSize: 14, color: color.shade800)),
    );
  }

  Color getColorByRating(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  String normalizeString(String str) {
    return removeDiacritics(str).toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  }
}
