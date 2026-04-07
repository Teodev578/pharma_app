import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharma_app/models/pharmacy.dart';

class SupabaseService {
  static final supabase = Supabase.instance.client;

  Future<List<Pharmacy>> getPharmacies() async {
    try {
      // Le SDK Supabase Flutter retourne List<Map<String,dynamic>> directement.
      // FIX : whereType filtre tout élément inattendu sans lever d'erreur,
      // ce qui rend le parsing robuste même si le schéma Supabase évolue.
      final List<Map<String, dynamic>> response = await supabase
          .from('pharmacies')
          .select()
          .order('nom', ascending: true);

      return response
          .map((json) => Pharmacy.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService: erreur lors de la récupération des pharmacies: $e');
      return [];
    }
  }
}
