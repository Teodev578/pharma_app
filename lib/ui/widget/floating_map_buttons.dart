import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

// Widget regroupant les boutons flottants de contrôle de la carte (Zoom, Position, etc.)
class FloatingMapButtons extends StatelessWidget {
  // Le contrôleur permet de manipuler la carte (bouger, zoomer) depuis l'extérieur du widget FlutterMap
  final MapController mapController;
  // Callback déclenché quand on appuie sur le bouton de localisation
  final VoidCallback onMyLocationPressed;

  const FloatingMapButtons({
    super.key,
    required this.mapController,
    required this.onMyLocationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bouton pour changer de calque ou de vue (Prévu pour une future version)
        _buildButton(context, Icons.layers_outlined, () {
          // Action changer de vue (implémentation future)
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
        // Bouton "Ma position" : Recentre la carte sur la position réelle de l'utilisateur
        _buildButton(
          context,
          Icons.my_location,
          onMyLocationPressed, // Utilise le callback fourni pour recentrer
          isPrimary: true, // Couleur plus vive pour le bouton principal
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

