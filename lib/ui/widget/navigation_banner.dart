import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NavigationBanner extends StatelessWidget {
  final VoidCallback onCancel;
  final String distance;
  final String instruction;
  final IconData directionIcon;
  final String? totalDistance;

  const NavigationBanner({
    super.key,
    required this.onCancel,
    this.distance = '50 m',
    this.instruction = 'A droite',
    this.directionIcon = Icons.turn_right,
    this.totalDistance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Direction Icon
          Icon(
            directionIcon,
            color: theme.colorScheme.primary,
            size: 36,
          ),
          const SizedBox(width: 12),
          // Direction Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      distance,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (totalDistance != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '($totalDistance total)',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  instruction,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Close Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onCancel();
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outline, width: 1.5),
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close,
                color: theme.colorScheme.outline,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
