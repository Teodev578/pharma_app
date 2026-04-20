import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';


import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';
import 'package:pharma_app/ui/widget/pharmacy_details_bottom_sheet.dart';

import 'package:pharma_app/ui/widget/map_top_loader.dart';
import 'package:pharma_app/ui/widget/map_scale_widget.dart';
import 'package:pharma_app/ui/widget/pharmacy_cluster_layer.dart';
import 'package:pharma_app/ui/widget/navigation_banner.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/models/route_info.dart';
import 'package:pharma_app/services/supabase_service.dart';
import 'package:pharma_app/services/routing_service.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LatLng _initialCenter = const LatLng(6.137, 1.212);
  final MapController _mapController = MapController();

  bool _isLoadingPharmacies = true;
  // ValueNotifier évite que SearchBottomSheet rebuild quand _trackingState ou la route changent
  final ValueNotifier<List<Pharmacy>> _pharmaciesNotifier = ValueNotifier([]);
  LatLng? _userPosition;
  LatLng? _pendingMove;
  bool _mapReady = false;
  int _trackingState = 0; // 0: tracking disabled, 1: position, 2: heading
  late final ValueNotifier<double> _rotationNotifier;
  // Zoom discret arrondi à 0.5 pour limiter les rebuilds de la couche marqueurs
  late final ValueNotifier<double> _zoomNotifier;
  late final ValueNotifier<double> _centerLatNotifier;
  List<LatLng> _routePoints = [];
  RouteInfo? _currentRoute;
  bool _isRouting = false;
  // Debounce timer pour éviter les rebuilds excessifs sur onPositionChanged
  Timer? _centerDebounce;
  // Rafraîchissement automatique des statuts toutes les 10 minutes
  Timer? _refreshTimer;
  // Stream d'arrivée — surveille la position pour stopper le routing auto
  StreamSubscription<Position>? _arrivalSubscription;

  late final StreamController<double?> _alignController;

  @override
  void initState() {
    super.initState();
    _rotationNotifier = ValueNotifier(0.0);
    _zoomNotifier = ValueNotifier(15.0);
    _centerLatNotifier = ValueNotifier(6.137);
    _alignController = StreamController<double?>.broadcast();
    _fetchPharmacies();
    _centerOnUserLocation();
    // Rafraîchissement silencieux des statuts toutes les 10 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) => _silentRefresh());
  }

  /// Met à jour les pharmacies en arrière-plan sans afficher le loader
  Future<void> _silentRefresh() async {
    try {
      final pharmacies = await SupabaseService().getPharmacies();
      if (mounted) _pharmaciesNotifier.value = pharmacies;
    } catch (_) {
      // Silence — une erreur de rafraîchissement ne doit pas déranger l'utilisateur
    }
  }

  Future<void> _centerOnUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showGpsPermissionDeniedSnackBar(permanent: true);
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) _showGpsPermissionDeniedSnackBar(permanent: false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      if (mounted) {
        final userLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _userPosition = userLatLng;
          _trackingState = 1;
        });
        if (_mapReady) {
          _mapController.move(userLatLng, 15.0);
        } else {
          setState(() => _pendingMove = userLatLng);
        }
      }
    } catch (e) {
      debugPrint('GPS error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'obtenir la position GPS.')),
        );
      }
    }
  }

  void _showGpsPermissionDeniedSnackBar({required bool permanent}) {
    final action = permanent
        ? SnackBarAction(
            label: 'Paramètres',
            onPressed: () => Geolocator.openAppSettings(),
          )
        : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permanent
              ? 'Localisation bloquée. Autorisez-la dans les paramètres.'
              : 'Permission de localisation refusée.',
        ),
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchPharmacies() async {
    try {
      final pharmacies = await SupabaseService().getPharmacies();
      if (mounted) {
        _pharmaciesNotifier.value = pharmacies;
        setState(() => _isLoadingPharmacies = false);
      }
    } catch (e) {
      debugPrint('Supabase error: $e');
      if (mounted) {
        setState(() => _isLoadingPharmacies = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible de charger les pharmacies.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Réessayer',
              onPressed: () {
                setState(() => _isLoadingPharmacies = true);
                _fetchPharmacies();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchAndShowRoute(Pharmacy pharmacy) async {
    if (_userPosition == null) return;
    if (pharmacy.latitude == null || pharmacy.longitude == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de calculer l\'itinéraire hors-ligne.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRouting = true;
      _routePoints = []; // Clear previous route
      _currentRoute = null;
    });

    final dest = LatLng(pharmacy.latitude!, pharmacy.longitude!);
    final routeInfo = await RoutingService().getRoute(_userPosition!, dest);

    if (mounted) {
      setState(() {
        _currentRoute = routeInfo;
        _routePoints = routeInfo?.points ?? [];
        _isRouting = false;
      });

      if (_routePoints.isNotEmpty) {
        // Fit bounds to show the whole route
        final bounds = LatLngBounds.fromPoints(_routePoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(80),
          ),
        );
        // Démarrer la surveillance d'arrivée
        _startArrivalDetection(LatLng(pharmacy.latitude!, pharmacy.longitude!));
      }
    }
  }

  /// Démarre un stream Geolocator pour détecter l'arrivée (<50m)
  void _startArrivalDetection(LatLng destination) {
    _arrivalSubscription?.cancel();
    _arrivalSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // ne déclenche que si l'utilisateur bouge de +10m
      ),
    ).listen((pos) {
      final distanceM = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        destination.latitude, destination.longitude,
      );
      if (distanceM < 50 && mounted) {
        _clearRoute();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous êtes arrivé à destination ✅'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _clearRoute() {
    _arrivalSubscription?.cancel();
    _arrivalSubscription = null;
    setState(() {
      _routePoints = [];
      _currentRoute = null;
    });
  }

  @override
  void dispose() {
    _centerDebounce?.cancel();
    _refreshTimer?.cancel();
    _arrivalSubscription?.cancel();
    _rotationNotifier.dispose();
    _zoomNotifier.dispose();
    _centerLatNotifier.dispose();
    _pharmaciesNotifier.dispose();
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

    final tileUrl = isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

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
                initialCenter: _userPosition ?? _initialCenter,
                initialZoom: 15.0,
                maxZoom: 20.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                  // Nécessite un geste de rotation d'au moins 20° avant de pivoter la carte
                  // Évite la rotation accidentelle lors d'un pinch-zoom légèrement de travers
                  rotationThreshold: 20.0,
                ),
                onPositionChanged: (position, hasGesture) {
                  // Rotation — mise à jour directe
                  if (position.rotation != _rotationNotifier.value) {
                    _rotationNotifier.value = position.rotation;
                  }
                  // Zoom discret (arrondi à 0.5) pour limiter les rebuilds marqueurs
                  final double discreteZoom = (position.zoom * 2).roundToDouble() / 2;
                  if (discreteZoom != _zoomNotifier.value) {
                    _zoomNotifier.value = discreteZoom;
                  }
                  // Latitude avec debounce 150ms pour éviter des rebuilds excessifs
                  _centerDebounce?.cancel();
                  _centerDebounce = Timer(const Duration(milliseconds: 150), () {
                    if (position.center.latitude != _centerLatNotifier.value) {
                      _centerLatNotifier.value = position.center.latitude;
                    }
                  });
                  if (hasGesture && _trackingState != 0) {
                    setState(() => _trackingState = 0);
                  }
                },
                onMapReady: () {
                  _mapReady = true;
                  if (_pendingMove != null) {
                    _mapController.move(_pendingMove!, 15.0);
                    _pendingMove = null;
                  }
                },
              ),
              children: [
                // COUCHE 1 : Fond de carte raster CartoDB
                TileLayer(
                  urlTemplate: tileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.pharma_app',
                  maxNativeZoom: 19,
                  // Annule les requêtes de tuiles hors-viewport pour économiser la bande passante
                  tileProvider: CancellableNetworkTileProvider(),
                  // Fondu d'apparition des tuiles (remplace le flash blanc)
                  tileDisplay: TileDisplay.fadeIn(),
                ),

                // COUCHE 2 : Position utilisateur
                Builder(
                  builder: (context) {
                    return CurrentLocationLayer(
                      alignPositionStream: _alignController.stream,
                      alignDirectionOnUpdate: _trackingState == 2
                          ? AlignOnUpdate.always
                          : AlignOnUpdate.never,
                      style: LocationMarkerStyle(
                        marker: DefaultLocationMarker(
                          color: theme.colorScheme.primary,
                        ),
                        markerSize: const Size(20, 20),
                      ),
                    );
                  },
                ),

                // COUCHE : Itinéraire (Polyline)
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: theme.colorScheme.primary,
                        strokeWidth: 5,
                        borderColor: theme.colorScheme.primary.withOpacity(0.3),
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),

                // COUCHE 3 : Clusters de pharmacies (zoom-adaptatif)
                ValueListenableBuilder<List<Pharmacy>>(
                  valueListenable: _pharmaciesNotifier,
                  builder: (context, pharmacies, _) {
                    if (_isLoadingPharmacies || pharmacies.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return RepaintBoundary(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _zoomNotifier,
                        builder: (context, zoom, _) => PharmacyClusterLayer(
                          pharmacies: pharmacies,
                          mapController: _mapController,
                          zoom: zoom,
                          onDirectionsPressedBuilder: (p) => () {
                            Navigator.pop(context);
                            _fetchAndShowRoute(p);
                          },
                        ),
                      ),
                    );
                  },
                ),

                // COUCHE 4 : Boutons flottants
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ValueListenableBuilder<double>(
                        valueListenable: _rotationNotifier,
                        builder: (context, rotation, _) => FloatingMapButtons(
                          mapController: _mapController,
                          trackingState: _trackingState,
                          rotation: rotation,
                          onMyLocationPressed: () {
                            if (_trackingState == 0) {
                              setState(() => _trackingState = 1);
                              _alignController.add(15.0);
                            } else if (_trackingState == 1) {
                              setState(() => _trackingState = 2);
                            } else {
                              setState(() => _trackingState = 1);
                              _mapController.rotate(0);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // UI Supérieure : Échelle et Indicateur de statut (Loader / Connectivité)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListenableBuilder(
                            listenable: Listenable.merge([_zoomNotifier, _centerLatNotifier]),
                            builder: (context, _) => MapScaleWidget(
                              zoom: _zoomNotifier.value,
                              latitude: _centerLatNotifier.value,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MapTopLoader(isLoading: _isLoadingPharmacies),
                        ],
                      ),
                    ),
                  ),
                ),

                // Panneau de navigation
                if (_routePoints.isNotEmpty && _currentRoute != null && _currentRoute!.steps.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final steps = _currentRoute!.steps;
                      String distanceText = '0 m';
                      String instructionText = 'Arrivée';
                      IconData icon = Icons.check_circle_outline;

                      // Use distance of step 0 (distance to reach maneuver 1)
                      // and instruction of step 1
                      if (steps.length > 1) {
                        double dist = steps[0].distance;
                        if (dist > 1000) {
                          distanceText = '${(dist / 1000).toStringAsFixed(1)} km';
                        } else {
                          distanceText = '${dist.round()} m';
                        }
                        instructionText = steps[1].instruction;
                        
                        // Map modifier to Icon
                        switch (steps[1].modifier) {
                          case 'left':
                          case 'sharp left':
                            icon = Icons.turn_left;
                            break;
                          case 'slight left':
                            icon = Icons.turn_slight_left;
                            break;
                          case 'right':
                          case 'sharp right':
                            icon = Icons.turn_right;
                            break;
                          case 'slight right':
                            icon = Icons.turn_slight_right;
                            break;
                          case 'uturn':
                            icon = Icons.u_turn_left;
                            break;
                          case 'straight':
                            icon = Icons.straight;
                            break;
                          default:
                            icon = Icons.turn_right;
                        }
                      }

                      return Align(
                        alignment: Alignment.topLeft,
                        child: NavigationBanner(
                          distance: distanceText,
                          instruction: instructionText,
                          directionIcon: icon,
                          onCancel: () {
                            setState(() {
                              _routePoints = [];
                              _currentRoute = null;
                            });
                          },
                        ),
                      );
                    }
                  ),
              ],
            ),

            // Barre de recherche
            ValueListenableBuilder<List<Pharmacy>>(
              valueListenable: _pharmaciesNotifier,
              builder: (context, pharmacies, _) => SearchBottomSheet(
                pharmacies: pharmacies,
                userPosition: _userPosition,
                onPharmacySelected: (pharmacy) {
                  if (pharmacy.latitude != null && pharmacy.longitude != null) {
                    _mapController.move(
                      LatLng(pharmacy.latitude!, pharmacy.longitude!),
                      16.0,
                    );
                    showPharmacyDetailsBottomSheet(context, pharmacy,
                        onDirectionsPressed: () {
                      Navigator.pop(context);
                      _fetchAndShowRoute(pharmacy);
                    });
                  }
                },
              ),
            ),

            if (_isRouting)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }




}
