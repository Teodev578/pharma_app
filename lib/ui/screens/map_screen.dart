import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

// Importations de tes fichiers locaux
import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/services/supabase_service.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- CONSTANTES ET CONFIGURATIONS ---
  final LatLng _initialCenter = const LatLng(6.137, 1.212);
  final MapController _mapController = MapController();

  // --- VARIABLES D'ÉTAT ---
  bool _isLoadingPharmacies = true;
  List<Pharmacy> _pharmacies = [];
  List<Marker> _cachedMarkers = [];
  LatLng? _userPosition;

  // Gestion de l'ordre d'arrivée GPS/carte
  LatLng? _pendingMove;
  bool _mapReady = false;

  // Stream pour recentrer la position utilisateur sans setState
  late final StreamController<double?> _alignController;

  @override
  void initState() {
    super.initState();
    _alignController = StreamController<double?>.broadcast();
    _fetchPharmacies();
    _centerOnUserLocation();
  }

  /// Centrage initial sur la position GPS de l'utilisateur
  Future<void> _centerOnUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      if (mounted) {
        final userLatLng = LatLng(position.latitude, position.longitude);
        setState(() => _userPosition = userLatLng);

        if (_mapReady) {
          _mapController.move(userLatLng, 15.0);
        } else {
          setState(() => _pendingMove = userLatLng);
        }
      }
    } catch (e) {
      debugPrint('Impossible de récupérer la position GPS : $e');
    }
  }

  /// Chargement des pharmacies depuis Supabase
  Future<void> _fetchPharmacies() async {
    try {
      final pharmacies = await SupabaseService().getPharmacies();

      if (mounted) {
        setState(() => _pharmacies = pharmacies);

        // Staggered loading : on attend le 1er frame rendu avant de calculer les marqueurs,
        // pour ne pas surcharger le thread UI au démarrage.
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
        await completer.future;
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) _updateMarkers();
      }
    } catch (e) {
      debugPrint('Erreur Supabase: $e');
      if (mounted) setState(() => _isLoadingPharmacies = false);
    }
  }

  /// Construit la liste de marqueurs depuis les données Supabase
  void _updateMarkers() {
    final newMarkers = _pharmacies
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => _buildPharmacyMarker(
              context,
              LatLng(p.latitude!, p.longitude!),
              p,
            ))
        .toList();

    if (mounted) {
      setState(() {
        _cachedMarkers = newMarkers;
        _isLoadingPharmacies = false;
      });
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

    // Tuiles raster OSM : clair par défaut, sombre via Stadia Alidade Smooth Dark
    final tileUrl = isDarkMode
        ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
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
                // Si la position GPS est déjà connue avant le 1er rendu, on l'utilise directement.
                // Sinon, on affiche Lomé par défaut et _centerOnUserLocation() recentrera via onMapReady.
                initialCenter: _userPosition ?? _initialCenter,
                initialZoom: 15.0,
                maxZoom: 20.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: () {
                  _mapReady = true;
                  if (_pendingMove != null) {
                    _mapController.move(_pendingMove!, 15.0);
                    _pendingMove = null;
                  }
                },
              ),
              children: [
                // COUCHE N°1 : FOND DE CARTE RASTER (PNG natif — rendu GPU direct, 0 lag)
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.example.pharma_app',
                  maxNativeZoom: 19,
                ),

                // COUCHE N°2 : POSITION UTILISATEUR
                Builder(builder: (context) {
                  final locationStyle = LocationMarkerStyle(
                    marker: DefaultLocationMarker(
                      color: theme.colorScheme.primary,
                    ),
                    markerSize: const Size(20, 20),
                  );
                  return CurrentLocationLayer(
                    alignPositionStream: _alignController.stream,
                    style: locationStyle,
                  );
                }),

                // COUCHE N°3 : MARQUEURS PHARMACIES avec CLUSTERING
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
                              _buildClusterWidget(context, markers.length),
                        ),
                      );
                    },
                  ),

                // COUCHE N°4 : BOUTONS FLOTTANTS
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

            // BARRE DE RECHERCHE
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

            // LOADER DISCRET
            if (_isLoadingPharmacies) _buildTopLoader(theme),
          ],
        ),
      ),
    );
  }

  /// Badge de cluster (nombre de pharmacies regroupées)
  Widget _buildClusterWidget(BuildContext context, int count) {
    return RepaintBoundary(
      child: Container(
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
      ),
    );
  }

  /// Loader discret en haut de l'écran
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
                  'Chargement des pharmacies...',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Marqueur individuel d'une pharmacie
  Marker _buildPharmacyMarker(
    BuildContext context,
    LatLng point,
    Pharmacy pharmacy,
  ) {
    final isOpen = pharmacy.statutActuel == 'Ouvert';
    final colorScheme = Theme.of(context).colorScheme;
    final stableKey = ValueKey('marker_${point.latitude}_${point.longitude}');

    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => _showPharmacyDetails(context, pharmacy),
        child: RepaintBoundary(
          key: stableKey,
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

  /// Bottom sheet de détails d'une pharmacie
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
                  onPressed: () {
                    final url = pharmacy.itineraireGoogleMaps?.isNotEmpty == true
                        ? pharmacy.itineraireGoogleMaps!
                        : (pharmacy.latitude != null && pharmacy.longitude != null
                            ? 'https://www.google.com/maps/dir/?api=1&destination=${pharmacy.latitude},${pharmacy.longitude}'
                            : null);
                    if (url != null) {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lien copié — collez-le dans Google Maps'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Itinéraire'),
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
