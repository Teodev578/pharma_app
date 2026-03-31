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
        _buildButton(Icons.map, () {
          // Action changer de vue (satellite, etc.)
          // Note: flutter_map tile layers can be swapped.
        }),
        const SizedBox(height: 8),
        _buildButton(Icons.near_me, () {
          // Action centrer sur Lomé (en attendant la géolocalisation réelle)
          mapController.move(const LatLng(6.137, 1.212), 14.0);
        }),
      ],
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

