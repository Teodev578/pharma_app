import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharma_app/models/pharmacy.dart';

class SupabaseService {
  static final supabase = Supabase.instance.client;
  static const _cacheKey = 'cached_pharmacies';
  static const _cacheTimestampKey = 'cached_pharmacies_ts';
  // Durée maximale de validité du cache avant rafraîchissement en arrière-plan
  static const Duration _cacheTtl = Duration(hours: 1);

  /// Retourne immédiatement les pharmacies depuis le cache si disponible,
  /// puis déclenche un rafraîchissement réseau en arrière-plan.
  Future<List<Pharmacy>> getPharmacies() async {
    final cached = await _loadFromCache();
    if (cached != null) {
      _refreshCache().ignore();
      return cached;
    }
    return await _fetchFromNetwork();
  }

  /// Recherche les pharmacies dans un rayon donné (en mètres) autour d'un point GPS.
  /// Utilise la fonction RPC 'get_pharmacies_in_radius' définie en SQL.
  Future<List<Pharmacy>> getPharmaciesInRadius({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
  }) async {
    try {
      final List<dynamic> response = await supabase.rpc(
        'get_pharmacies_in_radius',
        params: {
          'lat': latitude,
          'lng': longitude,
          'radius_meters': radiusMeters,
        },
      );

      final pharmacies = response
          .map((json) => Pharmacy.fromJson(json as Map<String, dynamic>))
          .toList();
      return pharmacies;
    } catch (e) {
      debugPrint('SupabaseService: erreur rpc radius: $e');
      return [];
    }
  }

  /// Recherche les pharmacies par nom via le backend (Full-Text Search).
  Future<List<Pharmacy>> searchPharmacies(String query) async {
    try {
      if (query.isEmpty) return await getPharmacies();

      final List<Map<String, dynamic>> response = await supabase
          .from('pharmacies')
          .select()
          .textSearch('fts', query, config: 'french', type: TextSearchType.websearch)
          .order('nom', ascending: true);

      return response.map((json) => Pharmacy.fromJson(json)).toList();
    } catch (e) {
      debugPrint('SupabaseService: erreur search: $e');
      return [];
    }
  }

  /// Stream en temps réel pour écouter les changements de statut des pharmacies.
  Stream<List<Pharmacy>> pharmaciesStream() {
    return supabase
        .from('pharmacies')
        .stream(primaryKey: ['nom']) // 'nom' est utilisé comme clé unique ici
        .map((data) => data.map((json) => Pharmacy.fromJson(json)).toList());
  }

  Future<List<Pharmacy>> _fetchFromNetwork() async {
    final List<Map<String, dynamic>> response = await supabase
        .from('pharmacies')
        .select()
        .order('nom', ascending: true);

    final pharmacies = response.map((json) => Pharmacy.fromJson(json)).toList();
    await _saveToCache(pharmacies);
    return pharmacies;
  }

  Future<void> _refreshCache() async {
    try {
      await _fetchFromNetwork();
    } catch (e) {
      debugPrint('SupabaseService: rafraîchissement du cache échoué: $e');
    }
  }

  Future<List<Pharmacy>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_cacheTimestampKey);
      if (ts == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheTtl.inMilliseconds) return null; // Cache expiré

      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;

      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Pharmacy.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('SupabaseService: erreur lecture cache: $e');
      return null;
    }
  }

  Future<void> _saveToCache(List<Pharmacy> pharmacies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(pharmacies.map((p) => p.toJson()).toList()));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('SupabaseService: erreur écriture cache: $e');
    }
  }
}
