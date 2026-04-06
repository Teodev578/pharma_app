import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharma_app/models/pharmacy.dart';

class SupabaseService {
  static final supabase = Supabase.instance.client;

  Future<List<Pharmacy>> getPharmacies() async {
    try {
      final response = await supabase
          .from('pharmacies')
          .select()
          .order('nom', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Pharmacy.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des pharmacies: $e');
      return [];
    }
  }
}
