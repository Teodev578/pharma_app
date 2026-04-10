import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:pharma_app/models/route_info.dart';

class RoutingService {
  /// Fetches a route between [start] and [end] using OSRM API.
  /// Returns a [RouteInfo] representing the route and its instructions.
  Future<RouteInfo?> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          final points = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          final double totalDistance = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final double totalDuration = (route['duration'] as num?)?.toDouble() ?? 0.0;

          List<RouteStep> steps = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['steps'] != null) {
              final stepsData = leg['steps'] as List;
              steps = stepsData.map((s) => RouteStep.fromJson(s)).toList();
            }
          }

          return RouteInfo(
            points: points,
            steps: steps,
            distance: totalDistance,
            duration: totalDuration,
          );
        }
      }
      return null;
    } catch (e) {
      print('Routing Error: $e');
      return null;
    }
  }
}
