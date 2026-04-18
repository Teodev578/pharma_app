import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:pharma_app/ui/widget/map_cluster_widget.dart';
import 'package:pharma_app/ui/widget/pharmacy_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:pharma_app/models/pharmacy.dart';

/// Widget dédié à la couche de clusters de pharmacies.
/// Reconstruit uniquement quand [zoom] franchit un palier OU que [pharmacies] change.
/// Le rayon de clustering et l'affichage des labels s'adaptent au niveau de zoom.
class PharmacyClusterLayer extends StatelessWidget {
  final List<Pharmacy> pharmacies;
  final MapController mapController;
  final double zoom;
  final VoidCallback? Function(Pharmacy pharmacy)? onDirectionsPressedBuilder;

  const PharmacyClusterLayer({
    super.key,
    required this.pharmacies,
    required this.mapController,
    required this.zoom,
    this.onDirectionsPressedBuilder,
  });

  /// Rayon de clustering adapté au zoom courant.
  int _clusterRadius() {
    if (zoom < 12) return 120;
    if (zoom < 13) return 90;
    if (zoom < 14) return 70;
    if (zoom < 15) return 50;
    if (zoom < 16) return 30;
    return 20;
  }

  @override
  Widget build(BuildContext context) {
    if (pharmacies.isEmpty) return const SizedBox.shrink();

    final bool showLabel = zoom >= PharmacyMarker.labelZoomThreshold;
    final double scale = zoom < PharmacyMarker.smallIconZoomThreshold ? 0.75 : 1.0;

    // Construction des markers avec les bons paramètres contextuels
    final List<Marker> markers = pharmacies
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => PharmacyMarker.build(
              context: context,
              point: LatLng(p.latitude!, p.longitude!),
              pharmacy: p,
              showLabel: showLabel,
              scale: scale,
              onDirectionsPressed: onDirectionsPressedBuilder?.call(p),
            ))
        .toList();

    return MarkerClusterLayer(
      mapController: mapController,
      mapCamera: MapCamera.of(context),
      options: MarkerClusterLayerOptions(
        markers: markers,
        size: const Size(44, 44),
        maxClusterRadius: _clusterRadius(),
        builder: (context, markers) => MapClusterWidget(count: markers.length),
      ),
    );
  }
}
