import 'package:flutter/material.dart';

class MapTopLoader extends StatelessWidget {
  const MapTopLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Chargement des pharmacies...',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
