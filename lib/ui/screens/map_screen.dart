import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Coordonnées initiales (Lomé)
  final LatLng _initialCenter = const LatLng(6.137, 1.212);
  final MapController _mapController = MapController();

  // Clé API MapTiler (à remplacer par la vôtre)
  final String mapTilerKey = 'VOTRE_CLE_API_MAPTILER_ICI';

  // Thème de la carte vectorielle
  vtr.Theme? _mapTheme;

  @override
  void initState() {
    super.initState();
    _loadVectorMapTheme();
  }

  // Fonction pour charger le style visuel de la carte depuis MapTiler
  Future<void> _loadVectorMapTheme() async {
    try {
      final styleUri = Uri.parse(
        'https://api.maptiler.com/maps/streets-v2/style.json?key=$mapTilerKey',
      );
      final response = await http.get(styleUri);

      if (response.statusCode == 200) {
        setState(() {
          _mapTheme = vtr.ThemeReader().read(jsonDecode(response.body));
        });
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement du thème vectoriel: $e");
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. LA CARTE
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 14.0,
              maxZoom: 22.0,
            ),
            children: [
              // --- COUCHE DE FOND (Vectoriel ou Raster) ---
              if (_mapTheme != null)
                VectorTileLayer(
                  theme: _mapTheme!,
                  tileProviders: TileProviders({
                    'openmaptiles': NetworkVectorTileProvider(
                      urlTemplate:
                          'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$mapTilerKey',
                      maximumZoom: 14,
                    ),
                  }),
                )
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pharma_app.app',
                ),

              // --- COUCHE : POSITION DE L'UTILISATEUR (Point bleu) ---
              CurrentLocationLayer(
                alignPositionStream: const Stream.empty(), // Empêche le recentrage auto au début
                style: const LocationMarkerStyle(
                  marker: DefaultLocationMarker(color: Colors.blueAccent),
                  markerSize: Size(20, 20),
                  showAccuracyCircle: true,
                ),
              ),

              // --- COUCHE : MARQUEURS (Pharmacies) ---
              MarkerLayer(
                markers: [
                  Marker(
                    point: _initialCenter,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.local_pharmacy,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. BOUTONS FLOTTANTS (Map & Localisation)
          Positioned(
            top: 50,
            right: 16,
            child: FloatingMapButtons(mapController: _mapController),
          ),

          // 3. LE BOTTOM SHEET (Barre de recherche et menu)
          const SearchBottomSheet(),
        ],
      ),
    );
  }
}
