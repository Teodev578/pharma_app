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

  static Marker build({
    required BuildContext context,
    required LatLng point,
    required Pharmacy pharmacy,
    required SettingsController settingsController,
    VoidCallback? onDirectionsPressed,
    void Function(String)? onMessage,
    // Si true, affiche le nom sous l'icône (activé seulement à fort zoom)
    bool showLabel = false,
    // Facteur de mise à l'échelle de l'icône (1.0 = normal, 0.75 = petit)
    double scale = 1.0,
  }) {
    final status = pharmacy.statutActuel?.toLowerCase();
    final isOpen = status == 'ouvert';
    final isClosed = status == 'fermé';
    final theme = Theme.of(context);
    final stableKey = ValueKey('marker_${point.latitude}_${point.longitude}_${showLabel}_$scale');

    // Définition des couleurs selon le statut (Ouvert / Fermé / Inconnu)
    final Color markerBgColor;
    final Color markerIconColor;

    if (isOpen) {
      markerBgColor = theme.colorScheme.primaryContainer;
      markerIconColor = theme.colorScheme.primary;
    } else if (isClosed) {
      markerBgColor = theme.colorScheme.errorContainer;
      markerIconColor = theme.colorScheme.error;
    } else {
      markerBgColor = theme.colorScheme.tertiaryContainer;
      markerIconColor = theme.colorScheme.tertiary;
    }

    // Taille de l'icône adaptée au zoom
    final double iconSize = 44.0 * scale;
    final double innerIconSize = 20.0 * scale;

    // La largeur du Marker est réduite si pas de label (économie de layout)
    final double markerWidth = showLabel ? 200 : iconSize;

    return Marker(
      point: point,
      width: markerWidth,
      height: showLabel ? 68 : iconSize,
      child: GestureDetector(
        onTap: () => showPharmacyDetailsBottomSheet(
          context,
          pharmacy,
          settingsController: settingsController,
          onDirectionsPressed: onDirectionsPressed,
          onMessage: onMessage,
        ),
        behavior: HitTestBehavior.deferToChild,
        child: RepaintBoundary(
          key: stableKey,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: markerBgColor,
                  shape: BoxShape.circle,
                  border: scale < 1.0
                      ? null
                      : Border.all(
                    color: theme.colorScheme.surface,
                    width: 3.0 * scale,
                  ),
                ),
                child: Icon(
                  Icons.local_pharmacy,
                  color: markerIconColor,
                  size: innerIconSize,
                ),
              ),
              // Label de la pharmacie — uniquement si showLabel == true
              if (showLabel)
                Positioned(
                  top: iconSize + 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      pharmacy.nom,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
