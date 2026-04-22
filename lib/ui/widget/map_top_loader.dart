import 'package:flutter/material.dart';

/// Loader centralisant les retours utilisateurs et le chargement.
/// Utilisé en haut de la carte pour éviter de masquer le bas de l'écran.
class MapTopLoader extends StatefulWidget {
  final bool isLoading;
  final String? message;

  const MapTopLoader({
    super.key,
    this.isLoading = false,
    this.message,
  });

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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

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
    final theme = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (widget.message != null) {
      return Container(
        key: const ValueKey('message'),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.isLoading) {
      return Container(
        key: const ValueKey('shimmer'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedBuilder(
          animation: _shimmerAnim,
          builder: (context, child) => _buildShimmerContent(theme),
        ),
      );
    }

    return const SizedBox.shrink(key: ValueKey('empty'));
  }

  Widget _buildShimmerContent(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShimmerBox(
          width: 16,
          height: 16,
          radius: 8,
          anim: _shimmerAnim,
          theme: theme,
        ),
        const SizedBox(width: 12),
        _ShimmerBox(
          width: 140,
          height: 12,
          radius: 6,
          anim: _shimmerAnim,
          theme: theme,
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
  final ThemeData theme;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.anim,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1);
    final highlightColor =
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3);

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
