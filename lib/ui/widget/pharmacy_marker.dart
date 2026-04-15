import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/ui/widget/pharmacy_details_bottom_sheet.dart';

class PharmacyMarker {
  static Marker build({
    required BuildContext context,
    required LatLng point,
    required Pharmacy pharmacy,
    VoidCallback? onDirectionsPressed,
  }) {
    final status = pharmacy.statutActuel?.toLowerCase();
    final isOpen = status == 'ouvert';
    final isClosed = status == 'fermé';
    final colorScheme = Theme.of(context).colorScheme;
    final stableKey = ValueKey('marker_${point.latitude}_${point.longitude}');

    // Définition des couleurs selon le statut (Ouvert / Fermé / Inconnu)
    final Color markerBgColor;
    final Color markerIconColor;

    if (isOpen) {
      markerBgColor = Colors.green.shade100;
      markerIconColor = Colors.green;
    } else if (isClosed) {
      markerBgColor = Colors.red.shade100;
      markerIconColor = Colors.red;
    } else {
      // Orange pour statut inconnu / À vérifier
      markerBgColor = const Color(0xFFFFE0B2); // Orange 100
      markerIconColor = const Color(0xFFE65100); // Orange 900
    }

    return Marker(
      point: point,
      width: 200,
      height: 44,
      child: GestureDetector(
        onTap: () => showPharmacyDetailsBottomSheet(context, pharmacy,
            onDirectionsPressed: onDirectionsPressed),
        behavior: HitTestBehavior.deferToChild,
        child: RepaintBoundary(
          key: stableKey,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: markerBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 3),
                ),
                child: Icon(
                  Icons.local_pharmacy,
                  color: markerIconColor,
                  size: 20,
                ),
              ),
              Positioned(
                top: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pharmacy.nom,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
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
