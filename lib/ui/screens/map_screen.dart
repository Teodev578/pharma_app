import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  // VOTRE CLÉ MAPTILER
  final String mapTilerKey = 'VOTRE_CLE_API_MAPTILER_ICI';

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
    // On utilise les styles intégrés de MapTiler qui marchent à 100%
    // "basic-v2-dark" donne un effet nuit très lisible avec des rues bleutées.
    final styleId = brightness == Brightness.dark
        ? 'basic-v2-dark'
        : 'streets-v2';

    // J'ai changé le nom de la clé pour vider l'ancien cache défectueux
    final cacheKey = 'map_style_v3_$styleId';

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);

      // 1. Essai de chargement depuis le cache
      if (cachedJson != null) {
        if (mounted) {
          setState(() {
            _mapTheme = vtr.ThemeReader().read(jsonDecode(cachedJson));
          });
        }
      }

      // 2. Téléchargement depuis MapTiler
      final styleUri = Uri.parse(
        'https://api.maptiler.com/maps/$styleId/style.json?key=$mapTilerKey',
      );
      final response = await http.get(styleUri);

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body); // Sauvegarde en cache

        if (cachedJson == null && mounted) {
          setState(() {
            _mapTheme = vtr.ThemeReader().read(jsonDecode(response.body));
          });
        }
      } else {
        debugPrint(
          "Erreur MapTiler: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Erreur critique chargement thème: $e");
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

    // Couleur de fond de la carte le temps qu'elle charge (Gris foncé ou Gris clair)
    final bgColor = isDarkMode
        ? const Color(
            0xFF212121,
          ) // Un gris légèrement plus clair que le noir pur
        : const Color(0xFFF2F4F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              backgroundColor: bgColor, // Empêche le flash blanc au lancement
              initialCenter: _initialCenter,
              initialZoom: 15.0,
              maxZoom: 22.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // --- COUCHE VECTORIELLE (Si chargée avec succès) ---
              if (_mapTheme != null)
                _wrapWithLayerFilter(
                  isDarkMode,
                  VectorTileLayer(
                    theme: _mapTheme!,
                    tileProviders: TileProviders({
                      'openmaptiles': NetworkVectorTileProvider(
                        urlTemplate:
                            'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$mapTilerKey',
                        maximumZoom: 14,
                      ),
                    }),
                  ),
                )
              // --- COUCHE DE SECOURS (Si le vectoriel échoue ou charge) ---
              else
                _wrapWithLayerFilter(
                  isDarkMode,
                  TileLayer(
                    // Utilise CartoDB Dark en mode sombre
                    urlTemplate: isDarkMode
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.pharma_app.app',
                    retinaMode: true,
                  ),
                ),

              // --- POSITION DE L'UTILISATEUR ---
              CurrentLocationLayer(
                alignPositionStream: const Stream.empty(),
                style: const LocationMarkerStyle(
                  marker: DefaultLocationMarker(color: Colors.blueAccent),
                  markerSize: Size(20, 20),
                  showAccuracyCircle: true,
                ),
              ),

              // --- MARQUEURS PHARMACIES ---
              MarkerLayer(
                markers: [
                  _buildPharmacyMarker(_initialCenter),
                  _buildPharmacyMarker(const LatLng(6.145, 1.220)),
                  _buildPharmacyMarker(const LatLng(6.132, 1.205)),
                ],
              ),
            ],
          ),

          // BOUTONS FLOTTANTS
          Positioned(
            top: 50,
            right: 16,
            child: FloatingMapButtons(mapController: _mapController),
          ),

          // BOTTOM SHEET
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
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
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

  /// Applique un filtre pour éclaircir les tuiles de la map en mode sombre
  Widget _wrapWithLayerFilter(bool isDarkMode, Widget child) {
    if (!isDarkMode) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        1.1, 0, 0, 0, 20, // Augmente légèrement la luminosité
        0, 1.1, 0, 0, 20,
        0, 0, 1.1, 0, 20,
        0, 0, 0, 1, 0,
      ]),
      child: child,
    );
  }
}
