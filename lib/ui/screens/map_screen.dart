import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Pour la fonction compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

// Importations de tes fichiers locaux
import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/services/supabase_service.dart';

/// FONCTION GLOBALE : Exécutée dans un thread séparé (Isolate)
/// pour décoder le JSON du thème sans faire ramer l'UI.
Future<vtr.Theme> _parseVectorTheme(Map<String, dynamic> params) async {
  final String jsonStr = params['jsonStr'];
  final String bgHex = params['bgHex'];
  final Map<String, dynamic> jsonStyle = jsonDecode(jsonStr);

  if (jsonStyle.containsKey('layers')) {
    for (var layer in jsonStyle['layers']) {
      if (layer['type'] == 'background') {
        layer['paint'] ??= {};
        layer['paint']['background-color'] = bgHex;
      }
    }
  }
  return vtr.ThemeReader().read(jsonStyle);
}

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Configuration
  final LatLng _initialCenter = const LatLng(6.137, 1.212);
  final MapController _mapController = MapController();
  final String mapTilerKey = 'pg76rH7Ad8bNzkP7pnwf';

  // State
  vtr.Theme? _mapTheme;
  Brightness? _lastBrightness;
  bool _isLoadingPharmacies = true;
  bool _isThemeLoading = false;

  List<Pharmacy> _pharmacies = [];
  List<Marker> _cachedMarkers = [];

  late final StreamController<double?> _alignController;
  late final TileProviders _tileProviders;

  @override
  void initState() {
    super.initState();
    _alignController = StreamController<double?>.broadcast();

    // Initialisation unique des providers (Cache RAM de 50MB)
    _tileProviders = TileProviders({
      'maptiler_planet': MemoryCacheVectorTileProvider(
        maxSizeBytes: 50 * 1024 * 1024,
        delegate: NetworkVectorTileProvider(
          urlTemplate:
              'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$mapTilerKey',
          maximumZoom: 14,
        ),
      ),
    });

    _fetchPharmacies();
  }

  /// Chargement des données depuis Supabase
  Future<void> _fetchPharmacies() async {
    try {
      final pharmacies = await SupabaseService().getPharmacies();
      if (mounted) {
        setState(() {
          _pharmacies = pharmacies;
          // NE PAS générer les marqueurs immédiatement pour éviter un goulot d'étranglement CPU (Jank)
          // On laisse le temps à la carte vectorielle (très lourde) de finir son premier rendu.
        });

        // Délai intentionnel (Staggered Loading)
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          _updateMarkers();
        }
      }
    } catch (e) {
      debugPrint("Erreur Supabase: $e");
      if (mounted) setState(() => _isLoadingPharmacies = false);
    }
  }

  /// Génère ou met à jour la liste des marqueurs (appelé si data ou thème change)
  void _updateMarkers() {
    final newMarkers = _pharmacies
        .where((p) => p.latitude != null && p.longitude != null)
        .map(
          (p) => _buildPharmacyMarker(
            context,
            LatLng(p.latitude!, p.longitude!),
            p,
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        _cachedMarkers = newMarkers;
        _isLoadingPharmacies = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);

    // On ne recharge le thème que si la luminosité change (Clair <-> Sombre)
    if (_lastBrightness != theme.brightness) {
      _lastBrightness = theme.brightness;

      final bgColor = theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : const Color(0xFFF2F4F5);

      _loadVectorMapTheme(theme.brightness, bgColor);

      // On rafraîchit les marqueurs pour qu'ils prennent les couleurs du nouveau thème
      if (_pharmacies.isNotEmpty) {
        setState(() => _isLoadingPharmacies = true);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _updateMarkers();
        });
      }
    }
  }

  /// Gestion du thème vectoriel avec Cache Disque et Thread séparé
  Future<void> _loadVectorMapTheme(Brightness brightness, Color bgColor) async {
    if (_isThemeLoading) return;
    setState(() => _isThemeLoading = true);

    final styleId = brightness == Brightness.dark
        ? 'streets-v2-dark'
        : 'streets-v2';
    final cacheKey = 'map_style_$styleId';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$cacheKey.json');
      String rawJsonStr = '';

      if (await file.exists()) {
        rawJsonStr = await file.readAsString();
      } else {
        final response = await http.get(
          Uri.parse(
            'https://api.maptiler.com/maps/$styleId/style.json?key=$mapTilerKey',
          ),
        );
        if (response.statusCode == 200) {
          rawJsonStr = response.body;
          await file.writeAsString(rawJsonStr);
        }
      }

      if (rawJsonStr.isNotEmpty && mounted) {
        final bgHex =
            '#${bgColor.value.toRadixString(16).substring(2, 8).toUpperCase()}';

        // EXECUTION HORS DU THREAD PRINCIPAL
        final decodedTheme = await compute(_parseVectorTheme, {
          'jsonStr': rawJsonStr,
          'bgHex': bgHex,
        });

        if (mounted) {
          setState(() {
            _mapTheme = decodedTheme;
            _isThemeLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur chargement thème: $e");
      if (mounted) setState(() => _isThemeLoading = false);
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? theme.colorScheme.surface
        : const Color(0xFFF2F4F5);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
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
                maxZoom: 20.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // 1. CARTE (VECTEUR)
                if (_mapTheme != null)
                  VectorTileLayer(
                    theme: _mapTheme!,
                    tileProviders: _tileProviders,
                  ),

                // 2. POSITION UTILISATEUR
                CurrentLocationLayer(
                  alignPositionStream: _alignController.stream,
                  style: LocationMarkerStyle(
                    marker: DefaultLocationMarker(
                      color: theme.colorScheme.primary,
                    ),
                    markerSize: const Size(20, 20),
                  ),
                ),

                // 3. MARQUEURS PHARMACIES (CLUSTERING)
                if (!_isLoadingPharmacies && _cachedMarkers.isNotEmpty)
                  Builder(
                    builder: (context) {
                      return MarkerClusterLayer(
                        mapController: _mapController,
                        mapCamera: MapCamera.of(context),
                        options: MarkerClusterLayerOptions(
                          markers: _cachedMarkers,
                          size: const Size(44, 44),
                          maxClusterRadius: 45,
                          builder: (context, markers) =>
                              _buildClusterWidget(markers.length),
                        ),
                      );
                    },
                  ),

                // 4. BOUTONS FLOTTANTS
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FloatingMapButtons(
                        mapController: _mapController,
                        onMyLocationPressed: () => _alignController.add(15.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 5. BARRE DE RECHERCHE
            SearchBottomSheet(
              pharmacies: _pharmacies,
              onPharmacySelected: (pharmacy) {
                if (pharmacy.latitude != null && pharmacy.longitude != null) {
                  _mapController.move(
                    LatLng(pharmacy.latitude!, pharmacy.longitude!),
                    16.0,
                  );
                  _showPharmacyDetails(context, pharmacy);
                }
              },
            ),

            // 6. LOADER
            if (_isLoadingPharmacies || _isThemeLoading) _buildTopLoader(theme),
          ],
        ),
      ),
    );
  }

  // Widget pour les groupes de marqueurs
  Widget _buildClusterWidget(int count) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget loader discret en haut
  Widget _buildTopLoader(ThemeData theme) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  "Optimisation de la carte...",
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Construction d'un marqueur individuel optimisé
  Marker _buildPharmacyMarker(
    BuildContext context,
    LatLng point,
    Pharmacy pharmacy,
  ) {
    final isOpen = pharmacy.statutActuel == 'Ouvert';
    final colorScheme = Theme.of(context).colorScheme;

    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: RepaintBoundary(
        // CRUCIAL pour la fluidité
        child: GestureDetector(
          onTap: () => _showPharmacyDetails(context, pharmacy),
          child: Container(
            decoration: BoxDecoration(
              color: isOpen ? Colors.green.shade100 : Colors.red.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.surface, width: 3),
            ),
            child: Icon(
              Icons.local_pharmacy,
              color: isOpen ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // Détails de la pharmacie (BottomSheet)
  void _showPharmacyDetails(BuildContext context, Pharmacy pharmacy) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pharmacy.nom,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (pharmacy.adresse != null)
                Text(pharmacy.adresse!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.directions),
                  label: const Text("Itinéraire"),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
