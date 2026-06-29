final jours = [
  "Lundi",
  "Lundi",
  "Mardi",
  "Mercredi",
  "Jeudi",
  "Vendredi",
  "Samedi",
  "Dimanche"
];

final mois = [
  "Jan",
  "Jan",
  "Fev",
  "Mars",
  "Avril",
  "Mai",
  "Juin",
  "Juil",
  "Aout",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
];

class BreakDate {
  // Date à la Franchouille en Input
  // Date Normalisé + Year Month
  var theYear;
  var theMonth;
  var theDay;
  String brutDate;

  DateTime checkDate = DateTime(2023, 07, 26);

  BreakDate(this.brutDate) {
    List deCoupe = brutDate.split('/');

    theDay = int.parse(deCoupe[0]);
    theMonth = int.parse(deCoupe[1]);
    theYear = int.parse(deCoupe[2]);
    checkDate = DateTime(theYear, theMonth, theDay);
  }
}

class ConfigTchinos {
// Date Normalisé + Year Month
  var theYear;
  var theMonth;
  var theDay;
  String brutDate = "";
  DateTime checkDate = DateTime(2023, 07, 26);
}

class Departement {
  int departement;
  double longitude;
  double latitude;
  double superficie;
  String nom;
  List<int> pourtour;
  List<int> distances;
  List<int> angles;
  List<int> trigo;

  Departement(
    this.departement,
    this.longitude,
    this.latitude,
    this.superficie,
    this.nom,
    this.pourtour,
  )   : distances = List<int>.filled(pourtour.length, 0),
        angles = List<int>.filled(pourtour.length, 0),
        trigo = List<int>.filled(pourtour.length, 0);
// Vous pouvez ajouter des méthodes ici pour manipuler les données si nécessaire
}

List lesDepartements = [
  Departement(
      1, 5.348888889, 46.09944444, 5785, "AIN", [38, 73, 74, 39, 71, 69]),
  Departement(
      2, 3.558333333, 49.55944444, 7419, "AISNE", [59, 80, 60, 77, 51, 8]),
  Departement(
      3, 3.188333333, 46.39361111, 7380, "ALLIER", [42, 71, 58, 18, 23, 63]),
  Departement(4, 6.243888889, 44.10611111, 6996, "ALPES-DE-HAUTE-PROVENCE",
      [83, 6, 5, 26, 84, 13]),
  Departement(
      5, 6.263055556, 44.66361111, 5689, "HAUTES-ALPES", [4, 26, 38, 73]),
  Departement(6, 7.116388889, 43.9375, 4297, "ALPES-MARITIMES", [83, 4, 20]),
  Departement(7, 4.424722222, 44.75166667, 5565, "ARDECHE",
      [48, 30, 84, 26, 38, 69, 43]),
  Departement(8, 4.640833333, 49.61555556, 5244, "ARDENNES", [55, 51, 2, 59]),
  Departement(9, 1.503888889, 42.92083333, 4908, "ARIEGE", [31, 11, 66]),
  Departement(10, 4.161666667, 48.30444444, 6027, "AUBE", [89, 21, 52, 51, 77]),
  Departement(11, 2.414166667, 43.10333333, 6345, "AUDE", [9, 31, 81, 34]),
  Departement(12, 2.679722222, 44.28027778, 8774, "AVEYRON",
      [34, 30, 48, 15, 46, 82, 81]),
  Departement(
      13, 5.086388889, 43.54333333, 5247, "BOUCHES-DU-RHONE", [30, 84, 83, 20]),
  Departement(14, -0.3636111111, 49.09972222, 5606, "CALVADOS", [27, 61, 50]),
  Departement(
      15, 2.668611111, 45.05111111, 5776, "CANTAL", [48, 43, 63, 19, 46, 12]),
  Departement(
      16, 0.2016666667, 45.71805556, 5974, "CHARENTE", [17, 79, 86, 87, 24]),
  Departement(17, -0.6744444444, 45.78083333, 6914, "CHARENTE-MARITIME",
      [85, 79, 16, 33]),
  Departement(
      18, 2.491111111, 47.06472222, 7310, "CHER", [36, 41, 45, 89, 58, 3, 23]),
  Departement(
      19, 1.876944444, 45.35694444, 5900, "CORREZE", [23, 87, 24, 46, 15, 63]),
  Departement(20, 8.988055556, 41.86361111, 4022, "CORSE", [13]),
  Departement(21, 4.772222222, 47.42472222, 8803, "COTE-D'OR",
      [10, 89, 58, 71, 39, 70, 52]),
  Departement(
      22, -2.864166667, 48.44111111, 6983, "COTES-D'ARMOR", [29, 56, 35]),
  Departement(
      23, 2.018888889, 46.09027778, 5599, "CREUSE", [87, 19, 63, 3, 18, 36]),
  Departement(24, 0.7413888889, 45.10416667, 9224, "DORDOGNE",
      [17, 16, 87, 19, 46, 47, 33]),
  Departement(25, 6.361666667, 47.16527778, 5254, "DOUBS", [39, 70, 90]),
  Departement(
      26, 5.168055556, 44.68416667, 6559, "DROME", [84, 4, 5, 38, 69, 7]),
  Departement(27, 0.9961111111, 49.11361111, 6035, "EURE",
      [76, 60, 95, 78, 28, 61, 14]),
  Departement(28, 1.370277778, 48.3875, 5933, "EURE-ET-LOIR",
      [27, 78, 91, 45, 41, 72, 61]),
  Departement(29, -4.058888889, 48.26111111, 6759, "FINISTERE", [22, 56]),
  Departement(
      30, 4.180277778, 43.99333333, 5876, "GARD", [34, 12, 48, 7, 26, 84, 13]),
  Departement(31, 1.172777778, 43.35861111, 6360, "HAUTE-GARONNE",
      [65, 32, 82, 81, 11, 9]),
  Departement(
      32, 0.4533333333, 43.69277778, 6300, "GERS", [31, 65, 64, 40, 47, 82]),
  Departement(
      33, -0.5752777778, 44.82527778, 10155, "GIRONDE", [17, 24, 47, 40]),
  Departement(34, 3.367222222, 43.57972222, 6231, "HERAULT", [11, 81, 12, 30]),
  Departement(35, -1.638611111, 48.15444444, 6844, "ILLE-ET-VILAINE",
      [50, 53, 49, 44, 56, 22]),
  Departement(
      36, 1.575833333, 46.77777778, 6898, "INDRE", [37, 41, 18, 23, 87, 86]),
  Departement(37, 0.6913888889, 47.25805556, 6160, "INDRE-ET-LOIRE",
      [41, 36, 86, 49, 72]),
  Departement(
      38, 5.576111111, 45.26333333, 7876, "ISERE", [5, 73, 1, 69, 7, 26, 42]),
  Departement(39, 5.697777778, 46.72833333, 5050, "JURA", [1, 71, 21, 70, 25]),
  Departement(40, -0.7838888889, 43.96555556, 9351, "LANDES", [33, 47, 32, 64]),
  Departement(41, 1.429444444, 47.61666667, 6419, "LOIR-ET-CHER",
      [72, 37, 36, 18, 45, 28]),
  Departement(
      42, 4.165833333, 45.72694444, 4807, "LOIRE", [43, 69, 71, 3, 63, 38]),
  Departement(43, 3.806388889, 45.12805556, 5005, "HAUTE-LOIRE",
      [48, 7, 69, 42, 63, 15]),
  Departement(44, -1.682222222, 47.36138889, 6912, "LOIRE-ATLANTIQUE",
      [56, 35, 53, 49, 85]),
  Departement(45, 2.344166667, 47.91194444, 6811, "LOIRET",
      [91, 77, 28, 41, 18, 58, 89]),
  Departement(
      46, 1.604722222, 44.62416667, 5227, "LOT", [15, 19, 24, 47, 82, 12]),
  Departement(47, 0.4602777778, 44.3675, 5385, "LOT-ET-GARONNE",
      [33, 40, 32, 82, 46, 24]),
  Departement(
      48, 3.500277778, 44.51722222, 5175, "LOZERE", [12, 30, 7, 43, 15]),
  Departement(49, -0.5641666667, 47.39083333, 7232, "MAINE-ET-LOIRE",
      [44, 53, 72, 37, 86, 79, 85]),
  Departement(50, -1.3275, 49.07944444, 6006, "MANCHE", [14, 61, 53, 35]),
  Departement(
      51, 4.238611111, 48.94916667, 8191, "MARNE", [2, 77, 10, 52, 55, 8]),
  Departement(52, 5.226388889, 48.10944444, 6257, "HAUTE-MARNE",
      [21, 70, 88, 55, 51, 10]),
  Departement(53, -0.6580555556, 48.14666667, 5212, "MAYENNE",
      [49, 72, 61, 50, 35, 44]),
  Departement(
      54, 6.165, 48.78694444, 5282, "MEURTHE-ET-MOSELLE", [57, 67, 88, 55]),
  Departement(55, 5.381666667, 48.98944444, 6236, "MEUSE", [54, 88, 52, 51, 8]),
  Departement(56, -2.81, 47.84638889, 6874, "MORBIHAN", [29, 22, 35, 44]),
  Departement(57, 6.663333333, 49.03722222, 6251, "MOSELLE", [67, 88, 54]),
  Departement(
      58, 3.504722222, 47.11527778, 6874, "NIEVRE", [3, 71, 21, 89, 45, 18]),
  Departement(59, 3.220555556, 50.44722222, 5751, "NORD", [2, 80, 62, 8]),
  Departement(
      60, 2.425277778, 49.41027778, 5890, "OISE", [2, 80, 76, 27, 95, 77]),
  Departement(
      61, 0.1288888889, 48.62361111, 6145, "ORNE", [14, 27, 28, 72, 53, 50]),
  Departement(62, 2.288611111, 50.49361111, 6694, "PAS-DE-CALAIS", [80, 59, 2]),
  Departement(63, 3.140833333, 45.72583333, 8012, "PUY-DE-DOME",
      [15, 43, 42, 3, 23, 19]),
  Departement(64, -0.7613888889, 43.25666667, 7685, "PYRENEES-ATLANTIQUES",
      [40, 32, 65]),
  Departement(
      65, 0.1638888889, 43.05305556, 4522, "HAUTES-PYRENEES", [64, 32, 31]),
  Departement(66, 2.522222222, 42.6, 4141, "PYRENEES-ORIENTALES", [9, 11]),
  Departement(67, 7.551388889, 48.67083333, 4796, "BAS-RHIN", [68, 88, 54, 57]),
  Departement(
      68, 7.274166667, 47.85861111, 3533, "HAUT-RHIN", [90, 70, 88, 67]),
  Departement(
      69, 4.641388889, 45.87027778, 3259, "RHONE", [1, 71, 42, 43, 7, 26, 38]),
  Departement(70, 6.086111111, 47.64111111, 5391, "HAUTE-SAONE",
      [21, 39, 25, 90, 88, 52]),
  Departement(71, 4.542222222, 46.64472222, 8616, "SAONE-ET-LOIRE",
      [3, 42, 69, 1, 39, 21, 58]),
  Departement(72, 0.2222222222, 47.99444444, 6246, "SARTHE",
      [28, 61, 53, 49, 37, 41, 86]),
  Departement(73, 6.443611111, 45.4775, 6271, "SAVOIE", [74, 1, 38, 5]),
  Departement(74, 6.428055556, 46.03444444, 4605, "HAUTE-SAVOIE", [73, 1]),
  Departement(75, 2.342222222, 48.85666667, 105, "PARIS", [92, 93, 94]),
  Departement(76, 1.026388889, 49.655, 6321, "SEINE-MARITIME", [80, 60, 27]),
  Departement(77, 2.933333333, 48.62666667, 5928, "SEINE-ET-MARNE",
      [89, 10, 51, 2, 60, 93, 91, 45]),
  Departement(78, 1.841666667, 48.815, 2305, "YVELINES", [95, 27, 28, 91, 92]),
  Departement(79, -0.3172222222, 46.55555556, 6040, "DEUX-SEVRES",
      [17, 85, 49, 86, 16]),
  Departement(80, 2.277777778, 49.95805556, 6194, "SOMME", [62, 59, 2, 60, 76]),
  Departement(81, 2.166111111, 43.78527778, 5780, "TARN", [11, 34, 12, 82, 31]),
  Departement(82, 1.281944444, 44.08583333, 3729, "TARN-ET-GARONNE",
      [32, 31, 81, 12, 46, 47]),
  Departement(83, 6.218055556, 43.46055556, 6163, "VAR", [13, 84, 4, 6, 20]),
  Departement(
      84, 5.186111111, 43.99388889, 3451, "VAUCLUSE", [13, 4, 26, 7, 30]),
  Departement(85, -1.297777778, 46.67472222, 6774, "VENDEE", [44, 49, 79, 17]),
  Departement(
      86, 0.4602777778, 46.56388889, 7038, "VIENNE", [36, 37, 49, 79, 16, 87]),
  Departement(87, 1.235277778, 45.89166667, 5560, "HAUTE-VIENNE",
      [23, 19, 24, 16, 86, 36]),
  Departement(88, 6.380555556, 48.19666667, 5899, "VOSGES",
      [70, 90, 68, 67, 57, 54, 55, 52]),
  Departement(
      89, 3.564444444, 47.83972222, 7458, "YONNE", [58, 21, 10, 77, 45]),
  Departement(90, 6.928611111, 47.63166667, 612, "TERRITOIRE DE BELFORT",
      [25, 70, 88, 68, 36]),
  Departement(
      91, 2.243055556, 48.52222222, 1819, "ESSONNE", [45, 28, 77, 78, 92, 94]),
  Departement(
      92, 2.245833333, 48.84722222, 175, "HAUTS-DE-SEINE", [75, 95, 78, 93]),
  Departement(
      93, 2.478055556, 48.9175, 237, "SEINE-SAINT-DENIS", [92, 95, 94, 77]),
  Departement(
      94, 2.468888889, 48.7775, 246, "VAL-DE-MARNE", [77, 75, 92, 93, 91]),
  Departement(
      95, 2.131111111, 49.08277778, 1253, "VAL-D'OISE", [78, 27, 60, 93, 92]),
];
