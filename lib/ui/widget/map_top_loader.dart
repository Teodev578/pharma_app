import 'package:flutter/material.dart';
import 'package:pharma_app/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Loader et indicateur d'état (chargement / connectivité).
/// Affiche un shimmer pendant le chargement ou un message si hors-ligne.
class MapTopLoader extends StatefulWidget {
  final bool isLoading;

  const MapTopLoader({super.key, this.isLoading = false});

  @override
  State<MapTopLoader> createState() => _MapTopLoaderState();
}

class _MapTopLoaderState extends State<MapTopLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: _connectivityService.connectivityStream,
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];
        final isOffline =
            results.isEmpty || results.contains(ConnectivityResult.none);

        if (!isOffline && !widget.isLoading) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _shimmerAnim,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: isOffline ? _buildOfflineInfo() : _buildShimmerContent(),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShimmerBox(width: 14, height: 14, radius: 7, anim: _shimmerAnim),
        const SizedBox(width: 12),
        _ShimmerBox(width: 160, height: 12, radius: 6, anim: _shimmerAnim),
      ],
    );
  }

  Widget _buildOfflineInfo() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 14),
        SizedBox(width: 8),
        Text(
          'Vous êtes hors connexion',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
    final baseColor = Colors.white.withValues(alpha: 0.1);
    final highlightColor = Colors.white.withValues(alpha: 0.3);

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
