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
  final LatLng _initialCenter = const LatLng(6.137, 1.212);
  final MapController _mapController = MapController();

  final String mapTilerKey = 'VOTRE_CLE_API_MAPTILER_ICI';

  // Mettez ici l'ID de la carte que vous avez créée sur MapTiler Cloud
  final String myCustomDarkMapId =
      'VOTRE_ID_DE_CARTE_CUSTOM_ICI'; // ex: '5f9a-xyz-...'

  vtr.Theme? _mapTheme;
  Brightness? _lastBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = Theme.of(context).brightness;

    if (_lastBrightness != currentBrightness) {
      _lastBrightness = currentBrightness;
      _loadVectorMapTheme(currentBrightness);
    }
  }

  Future<void> _loadVectorMapTheme(Brightness brightness) async {
    try {
      // SI MODE SOMBRE -> Utilise votre style personnalisé très contrasté
      // SI MODE CLAIR -> Utilise le style de base clair
      final styleId = brightness == Brightness.dark
          ? myCustomDarkMapId // <-- Votre style néon/nuit créé sur MapTiler
          : 'streets-v2'; // <-- Style clair classique

      final styleUri = Uri.parse(
        'https://api.maptiler.com/maps/$styleId/style.json?key=$mapTilerKey',
      );

      final response = await http.get(styleUri);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _mapTheme = vtr.ThemeReader().read(jsonDecode(response.body));
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur de chargement du thème vectoriel: $e");
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF101418)
          : Colors.white, // Fond raccord avec la map
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15.0,
              maxZoom: 22.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
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
                  urlTemplate: isDarkMode
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.pharma_app.app',
                  retinaMode: true,
                ),

              CurrentLocationLayer(
                alignPositionStream: const Stream.empty(),
                style: const LocationMarkerStyle(
                  marker: DefaultLocationMarker(color: Colors.blueAccent),
                  markerSize: Size(20, 20),
                  showAccuracyCircle: true,
                ),
              ),

              MarkerLayer(
                markers: [
                  _buildPharmacyMarker(_initialCenter),
                  _buildPharmacyMarker(const LatLng(6.145, 1.220)),
                  _buildPharmacyMarker(const LatLng(6.132, 1.205)),
                ],
              ),
            ],
          ),

          Positioned(
            top: 50,
            right: 16,
            child: FloatingMapButtons(mapController: _mapController),
          ),

          const SearchBottomSheet(),
        ],
      ),
    );
  }

  Marker _buildPharmacyMarker(LatLng point) {
    return Marker(
      point: point,
      alignment: Alignment.center,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ), // Bordure un peu plus fine
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.5,
                  ), // Ombre plus marquée
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.local_pharmacy,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
