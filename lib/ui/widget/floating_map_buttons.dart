import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

// Widget regroupant les boutons flottants de contrôle de la carte (Zoom, Position, etc.)
class FloatingMapButtons extends StatelessWidget {
  // Le contrôleur permet de manipuler la carte (bouger, zoomer) depuis l'extérieur du widget FlutterMap
  final MapController mapController;
  // Callback déclenché quand on appuie sur le bouton de localisation
  final VoidCallback onMyLocationPressed;
  final int trackingState; // 0: none, 1: position, 2: compass

  const FloatingMapButtons({
    super.key,
    required this.mapController,
    required this.onMyLocationPressed,
    this.trackingState = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bouton pour repointer vers le nord
        _buildButton(context, Icons.explore_outlined, () {
          mapController.rotate(0);
        }),
        const SizedBox(height: 8),
        // Bouton Zoom + (rapproche la caméra)
        _buildButton(context, Icons.add, () {
          final zoom = mapController.camera.zoom + 1;
          mapController.move(mapController.camera.center, zoom);
        }),
        const SizedBox(height: 2),
        // Bouton Zoom - (éloigne la caméra)
        _buildButton(context, Icons.remove, () {
          final zoom = mapController.camera.zoom - 1;
          mapController.move(mapController.camera.center, zoom);
        }),
        const SizedBox(height: 8),
        // Bouton "Ma position" : 0=Off, 1=Centré, 2=Boussole
        _buildButton(
          context,
          trackingState == 2
              ? Icons.explore
              : (trackingState == 1 ? Icons.my_location : Icons.location_searching),
          onMyLocationPressed,
          isPrimary: trackingState != 0,
        ),
      ],
    );
  }

  // Helper pour construire un bouton circulaire stylisé
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

