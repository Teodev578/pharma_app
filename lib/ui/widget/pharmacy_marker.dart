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
    final isOpen = pharmacy.statutActuel == 'Ouvert';
    final colorScheme = Theme.of(context).colorScheme;
    final stableKey = ValueKey('marker_${point.latitude}_${point.longitude}');

    return Marker(
      point: point,
      width: 200,
      height: 44,
      child: GestureDetector(
        onTap: () => showPharmacyDetailsBottomSheet(context, pharmacy, onDirectionsPressed: onDirectionsPressed),
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
              Positioned(
                top: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
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
