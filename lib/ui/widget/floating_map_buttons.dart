import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

// Widget regroupant les boutons flottants de contrôle de la carte (Zoom, Position, etc.)
class FloatingMapButtons extends StatelessWidget {
  // Le contrôleur permet de manipuler la carte (bouger, zoomer) depuis l'extérieur du widget FlutterMap
  final MapController mapController;
  // Callback déclenché quand on appuie sur le bouton de localisation
  final VoidCallback onMyLocationPressed;
  final int trackingState; // 0: none, 1: position, 2: compass
  final double rotation;

  const FloatingMapButtons({
    super.key,
    required this.mapController,
    required this.onMyLocationPressed,
    this.trackingState = 0,
    this.rotation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Vérifie si la carte est pivotée (avec une petite tolérance pour les virgules flottantes)
    final isRotated = rotation.abs() > 0.1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Bouton Boussole (visible uniquement si la carte est pivotée)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: isRotated
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildButton(
                    context,
                    Icons.navigation,
                    () {
                      HapticFeedback.mediumImpact();
                      mapController.rotate(0);
                    },
                    rotation: rotation,
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Groupe Zoom (+ / -) unifié
        _buildZoomGroup(context),
        const SizedBox(height: 12),

        // Bouton "Ma position" : 0=Off, 1=Centré, 2=Boussole
        _buildButton(
          context,
          trackingState == 2
              ? Icons.explore
              : (trackingState == 1 ? Icons.my_location : Icons.location_searching),
          () {
            HapticFeedback.mediumImpact();
            onMyLocationPressed();
          },
          isPrimary: trackingState != 0,
        ),
      ],
    );
  }

  // Groupe de boutons Zoom unifié (Style Pilule / Segments)
  Widget _buildZoomGroup(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRawButton(
                context,
                Icons.add,
                () {
                  HapticFeedback.lightImpact();
                  final zoom = mapController.camera.zoom + 1;
                  mapController.move(mapController.camera.center, zoom);
                },
              ),
              Container(
                height: 1,
                width: 32,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              _buildRawButton(
                context,
                Icons.remove,
                () {
                  HapticFeedback.lightImpact();
                  final zoom = mapController.camera.zoom - 1;
                  mapController.move(mapController.camera.center, zoom);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper pour les boutons sans bordures internes du groupe Zoom
  Widget _buildRawButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: colorScheme.onSurface,
            size: 24,
          ),
        ),
      ),
    );
  }

  // Helper pour construire un bouton circulaire stylisé
  Widget _buildButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed, {
    bool isPrimary = false,
    double? rotation,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget iconWidget = Icon(
      icon,
      color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
      size: 24,
    );

    // Si on a une rotation, on fait pivoter l'icône de manière fluide
    if (rotation != null) {
      iconWidget = Transform.rotate(
        angle: -rotation * (math.pi / 180),
        child: iconWidget,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isPrimary
            ? colorScheme.primary.withValues(alpha: 0.95)
            : colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? colorScheme.primary.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isPrimary
              ? Colors.transparent
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: iconWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

