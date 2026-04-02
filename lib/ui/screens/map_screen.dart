import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'dart:async';
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
  final String mapTilerKey = 'pg76rH7Ad8bNzkP7pnwf';

  vtr.Theme? _mapTheme;
  Brightness? _lastBrightness;

  // Controller pour forcer le recentrage sur la position actuelle (envoie le niveau de zoom souhaité)
  late final StreamController<double?> _alignController;

  @override
  void initState() {
    super.initState();
    _alignController = StreamController<double?>.broadcast();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final currentBrightness = theme.brightness;
    final isDarkMode = currentBrightness == Brightness.dark;
    final bgColor = isDarkMode
        ? theme.colorScheme.surface
        : const Color(0xFFF2F4F5);

    if (_lastBrightness != currentBrightness) {
      _lastBrightness = currentBrightness;
      _loadVectorMapTheme(currentBrightness, bgColor);
    }
  }

  Future<void> _loadVectorMapTheme(Brightness brightness, Color bgColor) async {
    final styleId = brightness == Brightness.dark
        ? 'streets-v2-dark'
        : 'streets-v2';
    // On sauvegarde le style brut non-modifié dans le cache
    final cacheKey = 'map_style_v3_raw_$styleId';

    try {
      final prefs = await SharedPreferences.getInstance();
      String rawJsonStr = '';

      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        rawJsonStr = cachedJson;
      } else {
        final styleUri = Uri.parse(
          'https://api.maptiler.com/maps/$styleId/style.json?key=$mapTilerKey',
        );
        final response = await http.get(styleUri);
        if (response.statusCode == 200) {
          rawJsonStr = response.body;
          prefs.setString(cacheKey, rawJsonStr);
        }
      }

      if (rawJsonStr.isNotEmpty) {
        final Map<String, dynamic> jsonStyle = jsonDecode(rawJsonStr);

        // --- INJECTION MAGIQUE MATERIAL 3 ---
        // On récupère la couleur hexadécimale du fond actuel (sans l'alpha)
        final bgHex =
            '#${bgColor.value.toRadixString(16).substring(2, 8).toUpperCase()}';

        if (jsonStyle.containsKey('layers')) {
          for (var layer in jsonStyle['layers']) {
            if (layer['type'] == 'background') {
              layer['paint'] ??= {};
              layer['paint']['background-color'] = bgHex;
            }
          }
        }

        if (mounted) {
          setState(() {
            _mapTheme = vtr.ThemeReader().read(jsonStyle);
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur critique chargement thème: $e");
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _alignController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final bgColor = isDarkMode ? colorScheme.surface : const Color(0xFFF2F4F5);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
      // AnnotatedRegion permet de personnaliser la barre d'état (status bar) et la barre de navigation du système
      child: Scaffold(
        // Fond de l'écran, s'adapte au mode sombre/clair
        backgroundColor: bgColor,
        // Étendre le corps derrière l'AppBar et la barre de navigation pour un effet immersif
        extendBodyBehindAppBar: true,
        extendBody: true,
        // Utilisation d'un Stack pour superposer la carte, les boutons et la barre de recherche
        body: Stack(
          fit: StackFit.expand,
          children: [
            // FlutterMap est le composant principal pour afficher la carte
            FlutterMap(
              mapController: _mapController,
              // Configuration initiale de la carte
              options: MapOptions(
                backgroundColor: bgColor,
                initialCenter:
                    _initialCenter, // Centre la carte sur Lomé par défaut
                initialZoom: 15.0,
                minZoom: 3.0,
                maxZoom: 20.0,
                // Empêche de scroller à l'infini en dehors de la carte du monde
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(-85.06, -180.0),
                    const LatLng(85.06, 180.0),
                  ),
                ),
                // Active toutes les interactions (zoom, rotation, drag)
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                keepAlive: true,
              ),
              children: [
                // Couche de tuiles vectorielles (MapTiler) pour une carte plus précise et fluide
                if (_mapTheme != null)
                  VectorTileLayer(
                    theme: _mapTheme!,
                    tileProviders: TileProviders({
                      'maptiler_planet': MemoryCacheVectorTileProvider(
                        maxSizeBytes: 15 * 1024 * 1024, // 15 MB de cache RAM
                        delegate: NetworkVectorTileProvider(
                          urlTemplate:
                              'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$mapTilerKey',
                          maximumZoom: 14,
                        ),
                      ),
                    }),
                  )
                // Solution de repli (fallback) avec des tuiles raster (CartoDB)
                else
                  TileLayer(
                    urlTemplate: isDarkMode
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    keepBuffer:
                        3, // Conserve plus de tuiles en RAM autour de la zone vue
                    panBuffer:
                        2, // Pré-charge les tuiles proches pour un pan ultra rapide
                  ),

                // Couche affichant la position actuelle de l'utilisateur (point bleu + direction)
                CurrentLocationLayer(
                  alignPositionStream: _alignController.stream,
                  alignPositionOnUpdate:
                      AlignOnUpdate.never, // N'aligne que quand on le demande
                  alignDirectionOnUpdate: AlignOnUpdate.never,
                  alignPositionAnimationDuration: const Duration(
                    milliseconds: 1200,
                  ),
                  alignPositionAnimationCurve: Curves.easeInOutCubic,
                  style: LocationMarkerStyle(
                    showHeadingSector: true,
                    headingSectorColor: colorScheme.primary.withOpacity(0.4),
                    headingSectorRadius: 60,
                    marker: DefaultLocationMarker(color: colorScheme.primary),
                    markerSize: const Size(20, 20),
                    accuracyCircleColor: colorScheme.primary.withOpacity(0.1),
                  ),
                ),

                // Couche affichant les marqueurs (pharmacies, hôpitaux, écoles)
                MarkerLayer(
                  markers: [
                    // Pharmacies
                    _buildPharmacyMarker(context, _initialCenter),
                    _buildPharmacyMarker(context, const LatLng(6.145, 1.220)),
                    _buildPharmacyMarker(context, const LatLng(6.132, 1.205)),

                    // Hôpitaux (exemples)
                    _buildHospitalMarker(context, const LatLng(6.135, 1.215)),
                    _buildHospitalMarker(context, const LatLng(6.140, 1.210)),

                    // Écoles (exemples)
                    _buildSchoolMarker(context, const LatLng(6.138, 1.218)),
                  ],
                ),

                // SafeArea pour les boutons flottants, insérée dans le FlutterMap pour avoir accès au MapCamera
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, right: 16),
                      // Nos boutons d'action customisés (Zoom +, Zoom -, Ma position)
                      child: FloatingMapButtons(
                        mapController: _mapController,
                        onMyLocationPressed: () => _alignController.add(15.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Barre de recherche rétractable en bas de l'écran
            const SearchBottomSheet(),
          ],
        ),
      ),
    );
  }

  Marker _buildHospitalMarker(BuildContext context, LatLng point) {
    return Marker(
      point: point,
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: const Icon(Icons.local_hospital, color: Colors.red, size: 20),
      ),
    );
  }

  Marker _buildSchoolMarker(BuildContext context, LatLng point) {
    return Marker(
      point: point,
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: const Icon(Icons.school, color: Colors.blue, size: 20),
      ),
    );
  }

  // Méthode pour construire l'apparence personnalisée d'un marqueur de pharmacie
  Marker _buildPharmacyMarker(BuildContext context, LatLng point) {
    final colorScheme = Theme.of(context).colorScheme;
    return Marker(
      point: point,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.surface, width: 3),
            ),
            child: Icon(
              Icons.local_pharmacy,
              color: colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
