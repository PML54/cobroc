import 'package:google_maps_flutter/google_maps_flutter.dart';

class Brocabrac {
  String brocType = "";
  String brocLocality = "";
  String brocPostal = "";
  String brocStreet = "";
  String brocName = "";
  double brocLatitude = 0.0;
  double brocLongitude = 0.0;
  String brocEventStatus = "";
  String brocOrganizer = "";
  String brocStartDate = "";
  String brocEndDate = "";
  String brocDescription = "";
  String brocNbExposants = "";
  String brocVenueName= "";
  String brocStarNbExposants = "*";
  String brocStarRevenu = "€";
  String brocLove = "";
  String brocStarBarycentre = ""; // plus i ly a de + concentration
  String brocStarLastColor = "";
  String brocDejaVu = "";
  String eventId = "";

  int brocFromCenter = 0;
  int brocFromSelect = 0;
  int brocMaster = 0;
  int brocInside = 0;
  int brocNote = 0;


  ///  Ewxtra
  ///
  ///
  /// int codeInsee;
  int codePostal = 0;

  //   String ville;
  //   double altitude;
  double superficie = 0.0;
  double population = 0.0;
  double latitude = 0.0;
  double longitude = 0.0;
  int codeDepartement = 99;

  //   int codeRegion
  int revenu = 0;

  Brocabrac(
      this.brocType,
      this.brocLocality,
      this.brocPostal,
      this.brocStreet,
      this.brocName,
      this.brocLatitude,
      this.brocLongitude,
      this.brocEventStatus,
      this.brocOrganizer,
      this.brocStartDate,
      this.brocEndDate,
      this.brocDescription,
      this.brocNbExposants,
      this.brocVenueName,
 this.eventId
  );

  setbrocMaster(brocmaster) {
    brocMaster = brocmaster;
  }

  setfromCenter(brocFromCenter) {
    this.brocFromCenter = brocFromCenter;
  }

  String noAccent(String inputChine) {
    // var outputStr1 = inputChine.replaceAll(/[à|â|ä]/g,"a");
    var outputStr1 = inputChine.toUpperCase();
    var outputStr2 = outputStr1.replaceAll('È', 'E');
    outputStr1 = outputStr2.replaceAll('É', 'E');
    outputStr2 = outputStr1.replaceAll('Ê', 'E');
    outputStr1 = outputStr2.replaceAll('Ë', 'E');
    outputStr2 = outputStr1.replaceAll('Ô', 'O');
    outputStr1 = outputStr2.replaceAll('Ô', 'O');
    outputStr2 = outputStr1.replaceAll('Ö', 'O');

//    var outputStr11 = outputStr10.replace([È|É|Ê|Ë],"E");
//    var outputStr12 = outputStr11.replace(/[Â|Ä|À]/g,"A");
//    var outputStr13 = outputStr12.replace(/[Î|Ï]/g,"I");
//    var outputStr14 = outputStr13.replace(/[Ô|Ö]/g,"O");
//    var outputStr15 = outputStr14.replace(/[Û|Ù]/g,"U");

    return (outputStr2);
  }

  debugBrocLocality() {
    brocLocality = noAccent(brocLocality);
  }
}

class GoToMarket {
  // On Va sur Google Map avec une liste

  int tripNbStep;
  double centerLatitude;
  double centerLongitude;

  List<int> order = [];
  List<Marker> tripMarkers = [];

  GoToMarket(this.tripNbStep, this.tripMarkers, this.centerLatitude,
      this.centerLongitude);
}

class ManageCobrac {
// Passage Arguments au travers une classe
// In case of Multiple Arguments
// Incovnénient: Je pense que l'on double les tailles
// Pour brocabrac t 50 brocabtes  c'est pas gébnar maus over ?

  List<Brocabrac> brocanteBrocabrac = [];
 // GoToMarket goToMarket;
  Brocabrac brocabrac;

  ManageCobrac(this.brocanteBrocabrac,this.brocabrac);
}
