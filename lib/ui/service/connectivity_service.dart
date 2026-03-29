import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service pour vérifier la connectivité Internet
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream qui émet les changements de connectivité
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Vérifie si l'appareil est connecté à Internet
  Future<bool> hasConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();

      // Retourne true si connecté via WiFi, mobile, ou ethernet
      return result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.ethernet);
    } catch (e) {
      // En cas d'erreur, on suppose qu'il n'y a pas de connexion
      return false;
    }
  }

  /// Retourne le type de connexion actuel
  Future<List<ConnectivityResult>> getConnectionType() async {
    return await _connectivity.checkConnectivity();
  }

  /// Vérifie si connecté via WiFi
  Future<bool> isConnectedViaWiFi() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi);
  }

  /// Vérifie si connecté via données mobiles
  Future<bool> isConnectedViaMobile() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.mobile);
  }
}
