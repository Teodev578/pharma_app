import 'dart:convert';

class Pharmacy {
  final String nom;
  final String? statutActuel;
  final String? adresse;
  final String? telephone;
  final String? itineraireGoogleMaps;
  final double? latitude;
  final double? longitude;
  final List<dynamic>? horairesOuverture;

  Pharmacy({
    required this.nom,
    this.statutActuel,
    this.adresse,
    this.telephone,
    this.itineraireGoogleMaps,
    this.latitude,
    this.longitude,
    this.horairesOuverture,
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    // Handle double conversion carefully as Supabase might return int for round numbers
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value.toString());
    }

    // Handle horaires_ouverture which might be a JSON string or a List
    List<dynamic>? parseHoraires(dynamic value) {
      if (value == null) return null;
      if (value is List) return value;
      if (value is String) {
        try {
          return jsonDecode(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return Pharmacy(
      nom: json['nom'] ?? 'Nom inconnu',
      statutActuel: json['statut_actuel'],
      adresse: json['adresse'],
      telephone: json['telephone'],
      itineraireGoogleMaps: json['itineraire_google_maps'],
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      horairesOuverture: parseHoraires(json['horaires_ouverture']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'statut_actuel': statutActuel,
      'adresse': adresse,
      'telephone': telephone,
      'itineraire_google_maps': itineraireGoogleMaps,
      'latitude': latitude,
      'longitude': longitude,
      'horaires_ouverture': horairesOuverture,
    };
  }
}
