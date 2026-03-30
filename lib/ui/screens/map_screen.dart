import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
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
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCenter,
              zoom: 14.0,
            ),
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('current_location'),
                position: _initialCenter,
                infoWindow: const InfoWindow(title: 'Ma Position'),
              ),
            },
          ),

          // 2. BOUTONS FLOTTANTS (Map & Localisation)
          const Positioned(top: 50, right: 16, child: FloatingMapButtons()),

          // 3. LE BOTTOM SHEET (Barre de recherche et menu)
          const SearchBottomSheet(),
        ],
      ),
    );
  }
}
