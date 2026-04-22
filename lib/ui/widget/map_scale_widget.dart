import 'dart:math';
import 'package:flutter/material.dart';

/// Echelle de carte avec mémoïsation — ne recalcule que si zoom ou latitude changent.
class MapScaleWidget extends StatefulWidget {
  final double zoom;
  final double latitude;

  const MapScaleWidget({
    super.key,
    required this.zoom,
    required this.latitude,
  });

  @override
  State<MapScaleWidget> createState() => _MapScaleWidgetState();
}

class _MapScaleWidgetState extends State<MapScaleWidget> {
  // Valeurs calculées cachées pour éviter les recalculs inutiles
  late double _barWidth;
  late String _label;

  @override
  void initState() {
    super.initState();
    _recalculate(widget.zoom, widget.latitude);
  }

  @override
  void didUpdateWidget(MapScaleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ne recalcule que si les inputs ont réellement changé
    if (oldWidget.zoom != widget.zoom || oldWidget.latitude != widget.latitude) {
      _recalculate(widget.zoom, widget.latitude);
    }
  }

  void _recalculate(double zoom, double latitude) {
    const double earthCircumference = 40075016.686;
    final double metersPerPixel = earthCircumference *
        cos(latitude * pi / 180) /
        (256 * pow(2, zoom));

    const double maxBarWidth = 100.0;
    final double maxMeters = maxBarWidth * metersPerPixel;
    final double scaleMeters = _getScaleDistance(maxMeters);

    _barWidth = scaleMeters / metersPerPixel;
    _label = scaleMeters >= 1000
        ? '${(scaleMeters / 1000).toStringAsFixed(scaleMeters % 1000 == 0 ? 0 : 1)} km'
        : '${scaleMeters.toInt()} m';
  }

  double _getScaleDistance(double maxMeters) {
    const List<double> increments = [
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: _barWidth,
            height: 2,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
