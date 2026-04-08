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
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/services/supabase_service.dart';

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
        setState(() => _userPosition = userLatLng);
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
                      style: LocationMarkerStyle(
                        marker: DefaultLocationMarker(
                          color: theme.colorScheme.primary,
                        ),
                        markerSize: const Size(20, 20),
                      ),
                    );
                  },
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
                              _buildClusterWidget(context, markers.length),
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
                        onMyLocationPressed: () => _alignController.add(15.0),
                      ),
                    ),
                  ),
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
                  _showPharmacyDetails(context, pharmacy);
                }
              },
            ),

            if (_isLoadingPharmacies) _buildTopLoader(theme),
          ],
        ),
      ),
    );
  }

  // ─── WIDGETS AUXILIAIRES ─────────────────────────────────────────────────────

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

  // ─── BOTTOM SHEET DÉTAILS PHARMACIE ──────────────────────────────────────────

  void _showPharmacyDetails(BuildContext context, Pharmacy pharmacy) {
    final isOpen = pharmacy.statutActuel == 'Ouvert';
    final statusColor = isOpen
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.88,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // ── HEADER coloré selon statut ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(isDark ? 0.12 : 0.08),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poignée de drag
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Icône pharmacie + nom + badge statut
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.local_pharmacy_rounded,
                                color: statusColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pharmacy.nom,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                  // Badge statut avec point clignotant
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          pharmacy.statutActuel ?? 'Inconnu',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── INFOS ───────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Adresse
                        if (pharmacy.adresse != null)
                          _infoCard(
                            theme: theme,
                            icon: Icons.location_on_rounded,
                            iconColor: theme.colorScheme.primary,
                            label: 'Adresse',
                            content: pharmacy.adresse!,
                          ),

                        // Téléphone (cliquable → copier)
                        if (pharmacy.telephone != null)
                          _infoCard(
                            theme: theme,
                            icon: Icons.phone_rounded,
                            iconColor: const Color(0xFF22C55E),
                            label: 'Téléphone',
                            content: pharmacy.telephone!,
                            isClickable: true,
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: pharmacy.telephone!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Numéro copié'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),

                        // Horaires d'ouverture
                        if (pharmacy.horairesOuverture != null &&
                            pharmacy.horairesOuverture!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Horaires d'ouverture",
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.secondary,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...pharmacy.horairesOuverture!.map((h) {
                                  final horaire = h is Map ? h : {};
                                  final jour =
                                      horaire['jour']?.toString() ??
                                      h.toString();
                                  final heure =
                                      horaire['heure']?.toString() ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          child: Text(
                                            jour,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            heure,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.7),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Bouton Itinéraire
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              final url =
                                  pharmacy.itineraireGoogleMaps?.isNotEmpty ==
                                      true
                                  ? pharmacy.itineraireGoogleMaps!
                                  : (pharmacy.latitude != null &&
                                            pharmacy.longitude != null
                                        ? 'https://www.google.com/maps/dir/?api=1&destination=${pharmacy.latitude},${pharmacy.longitude}'
                                        : null);
                              if (url != null) {
                                Clipboard.setData(ClipboardData(text: url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Lien copié — collez dans Maps',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.directions_rounded),
                            label: const Text(
                              'Obtenir l\'itinéraire',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Card info réutilisable (adresse, téléphone…)
  Widget _infoCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String content,
    VoidCallback? onTap,
    bool isClickable = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: isClickable
              ? Border.all(color: iconColor.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isClickable ? iconColor : null,
                      fontWeight: isClickable ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            if (isClickable)
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: iconColor.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }
}
