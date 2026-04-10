import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';
import 'package:pharma_app/ui/widget/pharmacy_details_bottom_sheet.dart';
import 'package:pharma_app/ui/widget/map_cluster_widget.dart';
import 'package:pharma_app/ui/widget/map_top_loader.dart';
import 'package:pharma_app/ui/widget/map_scale_widget.dart';
import 'package:pharma_app/ui/widget/pharmacy_marker.dart';
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
  List<Pharmacy> _pharmacies = [];
  List<Marker> _cachedMarkers = [];
  LatLng? _userPosition;
  LatLng? _pendingMove;
  bool _mapReady = false;
  int _trackingState = 0; // 0: tracking disabled, 1: position, 2: heading
  double _rotation = 0.0;
  double _zoom = 15.0;
  double _centerLat = 6.137;
  List<LatLng> _routePoints = [];
  RouteInfo? _currentRoute;
  bool _isRouting = false;

  late final StreamController<double?> _alignController;

  @override
  void initState() {
    super.initState();
    _alignController = StreamController<double?>.broadcast();
    _fetchPharmacies();
    _centerOnUserLocation();
  }

  Future<void> _centerOnUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied)
        return;

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
    }
  }

  Future<void> _fetchPharmacies() async {
    try {
      final pharmacies = await SupabaseService().getPharmacies();
      if (mounted) {
        setState(() => _pharmacies = pharmacies);
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => completer.complete(),
        );
        await completer.future;
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) _updateMarkers();
      }
    } catch (e) {
      debugPrint('Supabase error: $e');
      if (mounted) setState(() => _isLoadingPharmacies = false);
    }
  }

  void _updateMarkers() {
    final newMarkers = _pharmacies
        .where((p) => p.latitude != null && p.longitude != null)
        .map(
          (p) => PharmacyMarker.build(
            context: context,
            point: LatLng(p.latitude!, p.longitude!),
            pharmacy: p,
            onDirectionsPressed: () {
              Navigator.pop(context); // Fermer le bottom sheet pour voir la carte
              _fetchAndShowRoute(p);
            },
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

  Future<void> _fetchAndShowRoute(Pharmacy pharmacy) async {
    if (_userPosition == null) return;
    if (pharmacy.latitude == null || pharmacy.longitude == null) return;

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
      }
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
                ),
                onPositionChanged: (position, hasGesture) {
                  if (position.rotation != _rotation ||
                      position.zoom != _zoom ||
                      position.center.latitude != _centerLat) {
                    setState(() {
                      _rotation = position.rotation;
                      _zoom = position.zoom;
                      _centerLat = position.center.latitude;
                    });
                  }
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

                // COUCHE 3 : Clusters de pharmacies
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
                              MapClusterWidget(count: markers.length),
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
                      child: FloatingMapButtons(
                        mapController: _mapController,
                        trackingState: _trackingState,
                        rotation: _rotation,
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

                // Échelle de la carte
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MapScaleWidget(
                        zoom: _zoom,
                        latitude: _centerLat,
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
            SearchBottomSheet(
              pharmacies: _pharmacies,
              onPharmacySelected: (pharmacy) {
                if (pharmacy.latitude != null && pharmacy.longitude != null) {
                  _mapController.move(
                    LatLng(pharmacy.latitude!, pharmacy.longitude!),
                    16.0,
                  );
                  showPharmacyDetailsBottomSheet(context, pharmacy, onDirectionsPressed: () {
                    Navigator.pop(context); // Close bottom sheet to see map
                    _fetchAndShowRoute(pharmacy);
                  });
                }
              },
            ),

            if (_isLoadingPharmacies) const MapTopLoader(),
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
