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
    final styleId = brightness == Brightness.dark
        ? 'basic-v2-dark'
        : 'streets-v2';
    final cacheKey = 'map_style_v3_$styleId';

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null && mounted) {
        setState(() {
          _mapTheme = vtr.ThemeReader().read(jsonDecode(cachedJson));
        });
      }

      final styleUri = Uri.parse(
        'https://api.maptiler.com/maps/$styleId/style.json?key=$mapTilerKey',
      );
      final response = await http.get(styleUri);

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        if (mounted) {
          setState(
            () => _mapTheme = vtr.ThemeReader().read(jsonDecode(response.body)),
          );
        }
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
      child: Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                backgroundColor: bgColor,
                initialCenter: _initialCenter,
                initialZoom: 15.0,
                minZoom: 3.0,
                maxZoom: 20.0,
                // --- EMPECHE LE SCROLL DANS LE VIDE ---
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(-85.06, -180.0),
                    const LatLng(85.06, 180.0),
                  ),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
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
                else
                  _wrapWithLayerFilter(
                    isDarkMode,
                    TileLayer(
                      urlTemplate: isDarkMode
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                  ),

                CurrentLocationLayer(
                  alignPositionStream: const Stream.empty(),
                  style: LocationMarkerStyle(
                    marker: DefaultLocationMarker(color: colorScheme.primary),
                    markerSize: const Size(20, 20),
                    accuracyCircleColor: colorScheme.primary.withOpacity(0.1),
                  ),
                ),

                MarkerLayer(
                  markers: [
                    _buildPharmacyMarker(context, _initialCenter),
                    _buildPharmacyMarker(context, const LatLng(6.145, 1.220)),
                    _buildPharmacyMarker(context, const LatLng(6.132, 1.205)),
                  ],
                ),
              ],
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 16),
                  child: FloatingMapButtons(mapController: _mapController),
                ),
              ),
            ),

            const SearchBottomSheet(),
          ],
        ),
      ),
    );
  }

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

  Widget _wrapWithLayerFilter(bool isDarkMode, Widget child) {
    if (!isDarkMode) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        1.05,
        0,
        0,
        0,
        10,
        0,
        1.05,
        0,
        0,
        10,
        0,
        0,
        1.05,
        0,
        10,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: child,
    );
  }
}
