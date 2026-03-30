import 'package:flutter/material.dart';
import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Coordonnées de Lomé
  final LatLng _initialCenter = const LatLng(6.137, 1.212);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. LA CARTE EN ARRIÈRE-PLAN
          FlutterMap(
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.votre_nom.pharmacie_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _initialCenter,
                    width: 60,
                    height: 60,
                    child: _buildLocationMarker(),
                  ),
                ],
              ),
            ],
          ),

          // 2. BOUTONS FLOTTANTS (Map & Localisation)
          const Positioned(top: 50, right: 16, child: FloatingMapButtons()),

          // 3. LE BOTTOM SHEET (Barre de recherche et menu)
          const SearchBottomSheet(),
        ],
      ),
    );
  }

  // Petit widget privé pour le point bleu de localisation
  Widget _buildLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withOpacity(0.3),
      ),
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}
