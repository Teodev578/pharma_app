import 'package:flutter/material.dart';

class FloatingMapButtons extends StatelessWidget {
  const FloatingMapButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton(Icons.map, () {
          // Action changer de vue (satellite, etc.)
        }),
        const SizedBox(height: 8),
        _buildButton(Icons.near_me, () {
          // Action centrer sur l'utilisateur
        }),
      ],
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withOpacity(0.9),
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
