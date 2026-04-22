import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/services/settings_controller.dart';
import 'package:pharma_app/ui/widget/pharmacy_details_bottom_sheet.dart';

class PharmacyMarker {
  /// Seuil de zoom à partir duquel les labels de pharmacies sont affichés.
  static const double labelZoomThreshold = 15.5;

  /// Seuil de zoom en dessous duquel les icônes sont réduites.
  static const double smallIconZoomThreshold = 14.0;

  /// Crée un objet [Marker] configuré pour afficher une pharmacie.
  static Marker build({
    required LatLng point,
    required Pharmacy pharmacy,
    required SettingsController settingsController,
    VoidCallback? onDirectionsPressed,
    void Function(String)? onMessage,
    bool showLabel = false,
    double scale = 1.0,
  }) {
    // Calcul des dimensions fixes
    final double iconSize = 44.0 * scale;
    final double markerWidth = showLabel ? 200 : iconSize;
    final double markerHeight = showLabel ? 72 : iconSize;

    return Marker(
      point: point,
      width: markerWidth,
      height: markerHeight,
      // On utilise le nouveau widget optimisé comme child du Marker
      child: PharmacyMarkerWidget(
        pharmacy: pharmacy,
        settingsController: settingsController,
        showLabel: showLabel,
        scale: scale,
        onDirectionsPressed: onDirectionsPressed,
        onMessage: onMessage,
      ),
    );
  }
}

/// Widget optimisé pour le rendu haute performance d'un marqueur de pharmacie.
class PharmacyMarkerWidget extends StatelessWidget {
  final Pharmacy pharmacy;
  final SettingsController settingsController;
  final bool showLabel;
  final double scale;
  final VoidCallback? onDirectionsPressed;
  final void Function(String)? onMessage;

  const PharmacyMarkerWidget({
    super.key,
    required this.pharmacy,
    required this.settingsController,
    this.showLabel = false,
    this.scale = 1.0,
    this.onDirectionsPressed,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Définition des couleurs selon le statut (Ouvert / Fermé / Inconnu)
    // On évite les calculs complexes dans le build si possible.
    final status = pharmacy.statutActuel?.toLowerCase();
    final Color markerBgColor;
    final Color markerIconColor;

    if (status == 'ouvert') {
      markerBgColor = colorScheme.primaryContainer;
      markerIconColor = colorScheme.primary;
    } else if (status == 'fermé') {
      markerBgColor = colorScheme.errorContainer;
      markerIconColor = colorScheme.error;
    } else {
      markerBgColor = colorScheme.tertiaryContainer;
      markerIconColor = colorScheme.tertiary;
    }

    // Calcul des tailles d'icônes
    final double iconSize = 44.0 * scale;
    final double innerIconSize = 20.0 * scale;

    return GestureDetector(
      onTap: () => showPharmacyDetailsBottomSheet(
        context,
        pharmacy,
        settingsController: settingsController,
        onDirectionsPressed: onDirectionsPressed,
        onMessage: onMessage,
      ),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône ronde principale
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: markerBgColor,
              shape: BoxShape.circle,
              // Optimisation : Pas de bordure complexe lors du dézoom
              border: scale < 1.0
                  ? null
                  : Border.all(
                      color: colorScheme.surface,
                      width: 3.0 * scale,
                    ),
            ),
            child: Icon(
              Icons.local_pharmacy,
              color: markerIconColor,
              size: innerIconSize,
            ),
          ),
          
          // Label de la pharmacie - optimisé
          if (showLabel) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                // Utilisation de couleurs opaques ou simples pour le GPU
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                // Optimisation : Pas d'ombres en phase de dézoom ou si non nécessaire
                boxShadow: scale < 1.0 
                  ? null 
                  : const [
                      BoxShadow(
                        color: Color(0x14000000), // noir alpha 0.08 pré-calculé
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
              ),
              child: Text(
                pharmacy.nom,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 11, // Garde la taille spécifique pour la carte
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
