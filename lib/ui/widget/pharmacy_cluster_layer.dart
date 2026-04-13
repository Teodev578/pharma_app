import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:pharma_app/ui/widget/map_cluster_widget.dart';

/// Widget dédié à la couche de clusters de pharmacies.
/// En le séparant de MapScreen, son rebuild est découplé des mises à jour
/// de caméra (zoom, rotation, position) et n'a lieu que lorsque
/// la liste [markers] change réellement.
class PharmacyClusterLayer extends StatelessWidget {
  final List<Marker> markers;
  final MapController mapController;

  const PharmacyClusterLayer({
    super.key,
    required this.markers,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();

    return MarkerClusterLayer(
      mapController: mapController,
      mapCamera: MapCamera.of(context),
      options: MarkerClusterLayerOptions(
        markers: markers,
        size: const Size(44, 44),
        maxClusterRadius: 45,
        builder: (context, markers) =>
            MapClusterWidget(count: markers.length),
      ),
    );
  }
}
