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

import 'package:pharma_app/services/settings_controller.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  final SettingsController settingsController;

  const MapScreen({super.key, required this.settingsController});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LatLng _initialCenter = const LatLng(6.137, 1.212);
  final MapController _mapController = MapController();

  bool _isLoadingPharmacies = true;
  // State Isolated via ValueNotifiers
  final ValueNotifier<List<Pharmacy>> _pharmaciesNotifier = ValueNotifier([]);
  final ValueNotifier<LatLng?> _userPositionNotifier = ValueNotifier(null);
  final ValueNotifier<int> _trackingStateNotifier = ValueNotifier(0); // 0: disabled, 1: position, 2: heading
  final ValueNotifier<List<LatLng>> _routePointsNotifier = ValueNotifier([]);
  final ValueNotifier<RouteInfo?> _currentRouteNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isRoutingNotifier = ValueNotifier(false);

  LatLng? _pendingMove;
  bool _mapReady = false;
  
  late final ValueNotifier<double> _rotationNotifier;
  late final ValueNotifier<double> _zoomNotifier;
  late final ValueNotifier<double> _centerLatNotifier;

  // Debounce timer pour éviter les rebuilds excessifs sur onPositionChanged
  Timer? _centerDebounce;
  // Rafraîchissement automatique des statuts via Realtime
  StreamSubscription<List<Pharmacy>>? _pharmaciesSubscription;
  // Stream d'arrivée — surveille la position pour stopper le routing auto
  StreamSubscription<Position>? _arrivalSubscription;

  late final StreamController<double?> _alignController;
  final ValueNotifier<String?> _messageNotifier = ValueNotifier(null);
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _rotationNotifier = ValueNotifier(0.0);
    _zoomNotifier = ValueNotifier(15.0);
    _centerLatNotifier = ValueNotifier(6.137);
    _alignController = StreamController<double?>.broadcast();
    _fetchPharmacies();
    _centerOnUserLocation();
    // Écoute des mises à jour en temps réel (Realtime)
    _subscribeToPharmacies();
  }

  void _subscribeToPharmacies() {
    _pharmaciesSubscription?.cancel();
    _pharmaciesSubscription = SupabaseService().pharmaciesStream().listen((
      pharmacies,
    ) {
      if (mounted) {
        _pharmaciesNotifier.value = pharmacies;
        // On marque le chargement comme terminé dès le premier event du stream
        if (_isLoadingPharmacies) {
          setState(() => _isLoadingPharmacies = false);
        }
      }
    });
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
        _userPositionNotifier.value = userLatLng;
        _trackingStateNotifier.value = 1;

        if (_mapReady) {
          _mapController.move(userLatLng, 15.0);
        } else {
          _pendingMove = userLatLng;
        }
      }
    } catch (e) {
      debugPrint('GPS error: $e');
      if (mounted) {
        _showMessage('Oups ! Nous n\'avons pas pu localiser votre position.');
      }
    }
  }

  void _showMessage(String message) {
    _messageTimer?.cancel();
    _messageNotifier.value = message;
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _messageNotifier.value = null;
      }
    });
  }

  void _showGpsPermissionDeniedSnackBar({required bool permanent}) {
    _showMessage(
      permanent
          ? 'La localisation est désactivée. Veuillez l\'autoriser dans les réglages de votre téléphone.'
          : 'L\'accès à la localisation a été refusé.',
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
        _showMessage('Nous n\'avons pas pu charger les pharmacies. Vérifiez votre connexion.');
      }
    }
  }

  Future<void> _fetchAndShowRoute(Pharmacy pharmacy) async {
    if (_userPositionNotifier.value == null) return;
    if (pharmacy.latitude == null || pharmacy.longitude == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      if (mounted) {
        _showMessage('Le calcul d\'itinéraire nécessite une connexion internet.');
      }
      return;
    }

    _isRoutingNotifier.value = true;
    _routePointsNotifier.value = []; // Clear previous route
    _currentRouteNotifier.value = null;

    final dest = LatLng(pharmacy.latitude!, pharmacy.longitude!);
    final routeInfo = await RoutingService().getRoute(_userPositionNotifier.value!, dest);

    if (mounted) {
      _currentRouteNotifier.value = routeInfo;
      _routePointsNotifier.value = routeInfo?.points ?? [];
      _isRoutingNotifier.value = false;

      if (_routePointsNotifier.value.isNotEmpty) {
        // Fit bounds to show the whole route
        final bounds = LatLngBounds.fromPoints(_routePointsNotifier.value);
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
    _arrivalSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter:
                10, // ne déclenche que si l'utilisateur bouge de +10m
          ),
        ).listen((pos) {
          final distanceM = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            destination.latitude,
            destination.longitude,
          );
          if (distanceM < 50 && mounted) {
            _clearRoute();
            _showMessage('Vous êtes arrivé à destination ✅');
          }
        });
  }

  void _clearRoute() {
    _arrivalSubscription?.cancel();
    _arrivalSubscription = null;
    _routePointsNotifier.value = [];
    _currentRouteNotifier.value = null;
  }

  @override
  void dispose() {
    _centerDebounce?.cancel();
    _pharmaciesSubscription?.cancel();
    _arrivalSubscription?.cancel();
    _rotationNotifier.dispose();
    _zoomNotifier.dispose();
    _centerLatNotifier.dispose();
    _messageTimer?.cancel();
    _messageNotifier.dispose();
    _trackingStateNotifier.dispose();
    _userPositionNotifier.dispose();
    _routePointsNotifier.dispose();
    _currentRouteNotifier.dispose();
    _isRoutingNotifier.dispose();
    _pharmaciesNotifier.dispose();
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
            RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  backgroundColor: bgColor,
                  initialCenter: _userPositionNotifier.value ?? _initialCenter,
                  initialZoom: 15.0,
                  maxZoom: 20.0,
                  minZoom: 4.0,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(4.0, -5.0), // Elargi Sud-Ouest (Golfe de Guinée / Côte d'Ivoire)
                      const LatLng(14.0, 5.0), // Elargi Nord-Est (Burkina / Bénin / Niger)
                    ),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                    rotationThreshold: 20.0,
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (position.rotation != _rotationNotifier.value) {
                      _rotationNotifier.value = position.rotation;
                    }
                    final double discreteZoom = (position.zoom * 2).roundToDouble() / 2;
                    if (discreteZoom != _zoomNotifier.value) {
                      _zoomNotifier.value = discreteZoom;
                    }
                    _centerDebounce?.cancel();
                    _centerDebounce = Timer(const Duration(milliseconds: 150), () {
                      if (position.center.latitude != _centerLatNotifier.value) {
                        _centerLatNotifier.value = position.center.latitude;
                      }
                    });
                    if (hasGesture && _trackingStateNotifier.value != 0) {
                      _trackingStateNotifier.value = 0;
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
                  TileLayer(
                    urlTemplate: tileUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.example.pharma_app',
                    maxNativeZoom: 19,
                    tileProvider: CancellableNetworkTileProvider(),
                    tileDisplay: const TileDisplay.fadeIn(),
                  ),

                  ValueListenableBuilder<int>(
                    valueListenable: _trackingStateNotifier,
                    builder: (context, trackingState, _) => CurrentLocationLayer(
                      alignPositionStream: _alignController.stream,
                      alignDirectionOnUpdate: trackingState == 2
                          ? AlignOnUpdate.always
                          : AlignOnUpdate.never,
                      style: LocationMarkerStyle(
                        marker: DefaultLocationMarker(
                          color: theme.colorScheme.primary,
                        ),
                        markerSize: const Size(20, 20),
                      ),
                    ),
                  ),

                  ValueListenableBuilder<List<LatLng>>(
                    valueListenable: _routePointsNotifier,
                    builder: (context, points, _) {
                      if (points.isEmpty) return const SizedBox.shrink();
                      return PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            color: theme.colorScheme.primary,
                            strokeWidth: 8,
                            borderColor: Colors.white,
                            borderStrokeWidth: 5,
                          ),
                        ],
                      );
                    },
                  ),

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
                            settingsController: widget.settingsController,
                            zoom: zoom,
                            onDirectionsPressedBuilder: (p) => () {
                              Navigator.pop(context);
                              _fetchAndShowRoute(p);
                            },
                            onMessage: _showMessage,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Top Left Stacked Overlay (Banner, Scale, Loader)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Navigation Banner
                        ValueListenableBuilder<RouteInfo?>(
                          valueListenable: _currentRouteNotifier,
                          builder: (context, route, _) {
                            if (route == null || route.steps.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            
                            final steps = route.steps;
                            String distanceText = '0 m';
                            String instructionText = 'Arrivée';
                            String? totalDistanceText;
                            IconData icon = Icons.check_circle_outline;

                            // Format total distance
                            if (route.distance > 1000) {
                              totalDistanceText = '${(route.distance / 1000).toStringAsFixed(1)} km';
                            } else {
                              totalDistanceText = '${route.distance.round()} m';
                            }

                            if (steps.length > 1) {
                              double dist = steps[0].distance;
                              if (dist > 1000) {
                                distanceText = '${(dist / 1000).toStringAsFixed(1)} km';
                              } else {
                                distanceText = '${dist.round()} m';
                              }
                              instructionText = steps[1].instruction;

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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: NavigationBanner(
                                distance: distanceText,
                                instruction: instructionText,
                                directionIcon: icon,
                                totalDistance: totalDistanceText,
                                onCancel: _clearRoute,
                              ),
                            );
                          },
                        ),

                        // Map Scale
                        ListenableBuilder(
                          listenable: Listenable.merge([_zoomNotifier, _centerLatNotifier]),
                          builder: (context, _) => MapScaleWidget(
                            zoom: _zoomNotifier.value,
                            latitude: _centerLatNotifier.value,
                          ),
                        ),
                        
                        const SizedBox(height: 8),

                        // Loader / Message
                        ValueListenableBuilder<String?>(
                          valueListenable: _messageNotifier,
                          builder: (context, message, _) => MapTopLoader(
                            isLoading: _isLoadingPharmacies,
                            message: message,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating Buttons
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_rotationNotifier, _trackingStateNotifier]),
                      builder: (context, _) => FloatingMapButtons(
                        mapController: _mapController,
                        trackingState: _trackingStateNotifier.value,
                        rotation: _rotationNotifier.value,
                        onMyLocationPressed: () {
                          HapticFeedback.mediumImpact();
                          final currentState = _trackingStateNotifier.value;
                          if (currentState == 0) {
                            _trackingStateNotifier.value = 1;
                            _alignController.add(15.0);
                          } else if (currentState == 1) {
                            _trackingStateNotifier.value = 2;
                          } else {
                            _trackingStateNotifier.value = 1;
                            _mapController.rotate(0);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Search Bar
            ValueListenableBuilder<List<Pharmacy>>(
              valueListenable: _pharmaciesNotifier,
              builder: (context, pharmacies, _) => ValueListenableBuilder<LatLng?>(
                valueListenable: _userPositionNotifier,
                builder: (context, userPos, _) => SearchBottomSheet(
                  pharmacies: pharmacies,
                  userPosition: userPos,
                  settingsController: widget.settingsController,
                  onPharmacySelected: (pharmacy) {
                    if (pharmacy.latitude != null && pharmacy.longitude != null) {
                      _mapController.move(
                        LatLng(pharmacy.latitude!, pharmacy.longitude!),
                        16.0,
                      );
                      showPharmacyDetailsBottomSheet(
                        context,
                        pharmacy,
                        settingsController: widget.settingsController,
                        onMessage: _showMessage,
                        onDirectionsPressed: () {
                          Navigator.pop(context);
                          _fetchAndShowRoute(pharmacy);
                        },
                      );
                    }
                  },
                ),
              ),
            ),

            // Routing Loader
            ValueListenableBuilder<bool>(
              valueListenable: _isRoutingNotifier,
              builder: (context, isRouting, _) {
                if (!isRouting) return const SizedBox.shrink();
                return const RepaintBoundary(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}
