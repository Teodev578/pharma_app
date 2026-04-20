import 'package:flutter/material.dart';

/// Skeleton loader affiché pendant le chargement des pharmacies.
/// Remplace le spinner bloquant par une animation shimmer non-intrusive.
class MapTopLoader extends StatefulWidget {
  const MapTopLoader({super.key});

  @override
  State<MapTopLoader> createState() => _MapTopLoaderState();
}

class _MapTopLoaderState extends State<MapTopLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _shimmerAnim,
          builder: (context, child) {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShimmerBox(width: 14, height: 14, radius: 7, anim: _shimmerAnim),
                    const SizedBox(width: 12),
                    _ShimmerBox(width: 160, height: 12, radius: 6, anim: _shimmerAnim),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Animation<double> anim;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final highlightColor = isDark ? Colors.grey.shade600 : Colors.grey.shade100;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (anim.value - 0.5).clamp(0.0, 1.0),
                anim.value.clamp(0.0, 1.0),
                (anim.value + 0.5).clamp(0.0, 1.0),
              ],
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        ),
      ),
    );
  }
}
