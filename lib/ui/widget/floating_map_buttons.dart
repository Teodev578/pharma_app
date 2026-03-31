import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FloatingMapButtons extends StatelessWidget {
  final MapController mapController;

  const FloatingMapButtons({super.key, required this.mapController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton(context, Icons.layers_outlined, () {
          // Action changer de vue (implémentation future)
        }),
        const SizedBox(height: 8),
        _buildButton(context, Icons.add, () {
          final zoom = mapController.camera.zoom + 1;
          mapController.move(mapController.camera.center, zoom);
        }),
        const SizedBox(height: 2),
        _buildButton(context, Icons.remove, () {
          final zoom = mapController.camera.zoom - 1;
          mapController.move(mapController.camera.center, zoom);
        }),
        const SizedBox(height: 8),
        _buildButton(
          context,
          Icons.my_location,
          () {
            // Centre sur la position initiale (Lomé)
            mapController.move(const LatLng(6.137, 1.212), 15.0);
          },
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _buildButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed, {
    bool isPrimary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isPrimary
            ? colorScheme.primary
            : colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isPrimary
              ? Colors.transparent
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

