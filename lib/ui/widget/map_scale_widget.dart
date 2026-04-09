import 'dart:math';
import 'package:flutter/material.dart';

class MapScaleWidget extends StatelessWidget {
  final double zoom;
  final double latitude;

  const MapScaleWidget({
    super.key,
    required this.zoom,
    required this.latitude,
  });

  @override
  Widget build(BuildContext context) {
    // Calcul des mètres par pixel selon la latitude et le zoom
    // Formule : S = C * cos(lat) / (256 * 2^zoom)
    // C = Circonférence de la Terre (équatoriale) ≈ 40075016.686 mètres
    const double earthCircumference = 40075016.686;
    final double metersPerPixel = earthCircumference *
        cos(latitude * pi / 180) /
        (256 * pow(2, zoom));

    // On veut une barre d'échelle d'environ 100-150 pixels maximum
    const double maxBarWidth = 100.0;
    final double maxMeters = maxBarWidth * metersPerPixel;

    // Trouver un nombre "rond" de mètres pour l'échelle
    final double scaleMeters = _getScaleDistance(maxMeters);
    final double barWidth = scaleMeters / metersPerPixel;

    final String label = scaleMeters >= 1000
        ? '${(scaleMeters / 1000).toStringAsFixed(scaleMeters % 1000 == 0 ? 0 : 1)} km'
        : '${scaleMeters.toInt()} m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: barWidth,
            height: 2,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getScaleDistance(double maxMeters) {
    final List<double> increments = [
      1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000
    ];
    
    double best = increments.first;
    for (final inc in increments) {
      if (inc <= maxMeters) {
        best = inc;
      } else {
        break;
      }
    }
    return best;
  }
}
