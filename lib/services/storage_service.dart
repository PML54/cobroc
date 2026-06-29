import 'package:shared_preferences/shared_preferences.dart';

class AppParameters {
  final int rayonDensite;
  final double poidExposants;
  final double poidDensite;
  final double poidRevenu;
  final double poidHistorique;
  final bool inclureDistance;

  const AppParameters({
    required this.rayonDensite,
    required this.poidExposants,
    required this.poidDensite,
    required this.poidRevenu,
    required this.poidHistorique,
    required this.inclureDistance,
  });

  factory AppParameters.defaults() {
    return const AppParameters(
      rayonDensite: 12,
      poidExposants: 30.0,
      poidDensite: 25.0,
      poidRevenu: 20.0,
      poidHistorique: 25.0,
      inclureDistance: true,
    );
  }

  AppParameters copyWith({
    int? rayonDensite,
    double? poidExposants,
    double? poidDensite,
    double? poidRevenu,
    double? poidHistorique,
    bool? inclureDistance,
  }) {
    return AppParameters(
      rayonDensite: rayonDensite ?? this.rayonDensite,
      poidExposants: poidExposants ?? this.poidExposants,
      poidDensite: poidDensite ?? this.poidDensite,
      poidRevenu: poidRevenu ?? this.poidRevenu,
      poidHistorique: poidHistorique ?? this.poidHistorique,
      inclureDistance: inclureDistance ?? this.inclureDistance,
    );
  }

  @override
  String toString() {
    return 'AppParameters(rayon: ${rayonDensite}km, exposants: ${poidExposants.round()}%, '
        'densité: ${poidDensite.round()}%, revenu: ${poidRevenu.round()}%, '
        'historique: ${poidHistorique.round()}%, distance: $inclureDistance)';
  }
}

class StorageService {
  static const String _rayonDensiteKey = 'rayon_densite_cobrac';
  static const String _poidExposantsKey = 'poid_exposants_cobrac';
  static const String _poidDensiteKey = 'poid_densite_cobrac';
  static const String _poidRevenuKey = 'poid_revenu_cobrac';
  static const String _poidHistoriqueKey = 'poid_historique_cobrac';
  static const String _inclureDistanceKey = 'inclure_distance_cobrac';
  static const String _lieuActuelKey = 'lieu_actuel_cobrac';
  static const String _monCoinKey = 'mon_coin_cobrac';
  static const String _gpsSimuleKey = 'gps_simule_cobrac';
  static const String _latSimuleeKey = 'lat_simulee_cobrac';
  static const String _lonSimuleeKey = 'lon_simulee_cobrac';

  static Future<AppParameters> loadParameters() async {
    final prefs = await SharedPreferences.getInstance();
    return AppParameters(
      rayonDensite: prefs.getInt(_rayonDensiteKey) ?? 12,
      poidExposants: prefs.getDouble(_poidExposantsKey) ?? 30.0,
      poidDensite: prefs.getDouble(_poidDensiteKey) ?? 25.0,
      poidRevenu: prefs.getDouble(_poidRevenuKey) ?? 20.0,
      poidHistorique: prefs.getDouble(_poidHistoriqueKey) ?? 25.0,
      inclureDistance: prefs.getBool(_inclureDistanceKey) ?? true,
    );
  }

  static Future<void> saveParameters(AppParameters params) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rayonDensiteKey, params.rayonDensite);
    await prefs.setDouble(_poidExposantsKey, params.poidExposants);
    await prefs.setDouble(_poidDensiteKey, params.poidDensite);
    await prefs.setDouble(_poidRevenuKey, params.poidRevenu);
    await prefs.setDouble(_poidHistoriqueKey, params.poidHistorique);
    await prefs.setBool(_inclureDistanceKey, params.inclureDistance);
  }

  static Future<int> loadLieuActuel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lieuActuelKey) ?? 0;
  }

  static Future<void> saveLieuActuel(int lieu) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lieuActuelKey, lieu);
  }

  static Future<List<int>> loadMonCoin() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_monCoinKey);
    if (saved == null || saved.isEmpty) return [];
    return saved.split(',').map(int.parse).toList();
  }

  static Future<void> saveMonCoin(List<int> deps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_monCoinKey, deps.join(','));
  }

  static Future<({bool actif, double lat, double lon})> loadGpsSimule() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      actif: prefs.getBool(_gpsSimuleKey) ?? false,
      lat: prefs.getDouble(_latSimuleeKey) ?? 46.5,
      lon: prefs.getDouble(_lonSimuleeKey) ?? 2.5,
    );
  }

  static Future<void> saveGpsSimule(bool actif, double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gpsSimuleKey, actif);
    await prefs.setDouble(_latSimuleeKey, lat);
    await prefs.setDouble(_lonSimuleeKey, lon);
  }
}
