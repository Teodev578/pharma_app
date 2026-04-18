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
  /// Lance une exception si le réseau échoue ET qu'il n'y a pas de cache.
  Future<List<Pharmacy>> getPharmacies() async {
    final cached = await _loadFromCache();

    if (cached != null) {
      // Cache valide : retourner immédiatement et rafraîchir en arrière-plan
      _refreshCache().ignore();
      return cached;
    }

    // Pas de cache : charge obligatoirement depuis le réseau
    return await _fetchFromNetwork();
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
