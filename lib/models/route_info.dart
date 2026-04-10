import 'package:latlong2/latlong.dart';

class RouteStep {
  final double distance; // The distance of this step along the route
  final String instruction; // Our generated instruction (e.g. "À droite")
  final String modifier; // e.g. "right", "left", "straight"
  final LatLng maneuverLocation; // Coordinate of the maneuver

  RouteStep({
    required this.distance,
    required this.instruction,
    required this.modifier,
    required this.maneuverLocation,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] ?? {};
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';
    final locationData = maneuver['location'] as List<dynamic>? ?? [0.0, 0.0];
    
    // OSRM provides [longitude, latitude]
    final location = LatLng(locationData[1].toDouble(), locationData[0].toDouble());
    
    // Generate simple French instruction
    String instruction = "Continuer sur l'itinéraire";
    if (type == 'depart') {
      instruction = 'Départ';
    } else if (type == 'arrive') {
      instruction = 'Arrivée';
    } else {
      switch (modifier) {
        case 'left':
          instruction = 'À gauche';
          break;
        case 'right':
          instruction = 'À droite';
          break;
        case 'slight left':
          instruction = 'Légèrement à gauche';
          break;
        case 'slight right':
          instruction = 'Légèrement à droite';
          break;
        case 'sharp left':
          instruction = 'Tournez serré à gauche';
          break;
        case 'sharp right':
          instruction = 'Tournez serré à droite';
          break;
        case 'straight':
          instruction = 'Tout droit';
          break;
        case 'uturn':
          instruction = 'Demi-tour';
          break;
      }
    }

    final distance = (json['distance'] as num?)?.toDouble() ?? 0.0;

    return RouteStep(
      distance: distance,
      instruction: instruction,
      modifier: modifier,
      maneuverLocation: location,
    );
  }
}

class RouteInfo {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distance;
  final double duration;

  RouteInfo({
    required this.points,
    required this.steps,
    required this.distance,
    required this.duration,
  });
}
