import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

// Widget regroupant les boutons flottants de contrôle de la carte.
// StatefulWidget pour gérer les animations d'entrée et de transition.
class FloatingMapButtons extends StatefulWidget {
  final MapController mapController;
  final VoidCallback onMyLocationPressed;
  final int trackingState; // 0: none, 1: position, 2: compass
  final double rotation;

  const FloatingMapButtons({
    super.key,
    required this.mapController,
    required this.onMyLocationPressed,
    this.trackingState = 0,
    this.rotation = 0.0,
  });

  @override
  State<FloatingMapButtons> createState() => _FloatingMapButtonsState();
}

class _FloatingMapButtonsState extends State<FloatingMapButtons>
    with TickerProviderStateMixin {
  // --- Animation d'entrée (slide depuis la droite + fade) ---
  late final AnimationController _entranceController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // --- Bounce on tap pour chaque bouton ---
  late final AnimationController _bounceZoomPlusCtrl;
  late final AnimationController _bounceZoomMinusCtrl;
  late final AnimationController _bounceLocationCtrl;
  late final AnimationController _bounceCompassCtrl;

  // --- Animation de zoom fluide (interpolation entre niveaux de zoom) ---
  late final AnimationController _zoomAnimCtrl;
  Animation<double>? _zoomAnim;

  @override
  void initState() {
    super.initState();

    // Animation d'entrée : slide depuis la droite + fade-in staggeré
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Bounce controllers (commencent à 1 = taille normale)
    _bounceZoomPlusCtrl = _makeBounceController();
    _bounceZoomMinusCtrl = _makeBounceController();
    _bounceLocationCtrl = _makeBounceController();
    _bounceCompassCtrl = _makeBounceController();

    // Contrôleur de zoom fluide
    _zoomAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Déclencher l'animation d'entrée après un léger délai
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _entranceController.forward();
    });
  }

  AnimationController _makeBounceController() {
    return AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1.0,
    );
  }

  /// Squeeze → release avec easeOutBack pour un effet élastique
  void _triggerBounce(AnimationController ctrl) {
    ctrl
        .animateTo(
          0.82,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeIn,
        )
        .then((_) => ctrl.animateTo(
              1.0,
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOutBack,
            ));
  }

  /// Anime le zoom de la valeur courante vers [targetZoom] de façon fluide
  void _animateZoom(double targetZoom) {
    // Annuler toute animation de zoom en cours
    _zoomAnim?.removeListener(_onZoomAnimTick);
    _zoomAnimCtrl.stop();

    final startZoom = widget.mapController.camera.zoom;
    _zoomAnim = Tween<double>(begin: startZoom, end: targetZoom).animate(
      CurvedAnimation(parent: _zoomAnimCtrl, curve: Curves.easeOutCubic),
    );
    _zoomAnim!.addListener(_onZoomAnimTick);
    _zoomAnimCtrl.forward(from: 0);
  }

  void _onZoomAnimTick() {
    final anim = _zoomAnim;
    if (anim != null && mounted) {
      widget.mapController.move(widget.mapController.camera.center, anim.value);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bounceZoomPlusCtrl.dispose();
    _bounceZoomMinusCtrl.dispose();
    _bounceLocationCtrl.dispose();
    _bounceCompassCtrl.dispose();
    _zoomAnim?.removeListener(_onZoomAnimTick);
    _zoomAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRotated = widget.rotation.abs() > 0.1;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Boussole — apparition avec scale élastique + fade
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: isRotated
                  ? Padding(
                      key: const ValueKey('compass'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Tooltip(
                        message: 'Pointer vers le Nord',
                        preferBelow: false,
                        child: _buildBouncingButton(
                          ctrl: _bounceCompassCtrl,
                          child: _buildCompassButton(context),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-compass')),
            ),

            // Groupe Zoom
            _buildZoomGroup(context),
            const SizedBox(height: 12),

            // Bouton localisation avec transition d'icône et aura animée
            Tooltip(
              message: widget.trackingState == 0
                  ? 'Centrer sur ma position'
                  : widget.trackingState == 1
                      ? 'Activer la boussole'
                      : 'Désactiver le suivi',
              preferBelow: false,
              child: _buildBouncingButton(
                ctrl: _bounceLocationCtrl,
                child: _buildAnimatedLocationButton(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Enveloppe un widget dans un scale piloté par un bounce controller
  Widget _buildBouncingButton({
    required AnimationController ctrl,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) => Transform.scale(scale: ctrl.value, child: child),
    );
  }

  /// Bouton boussole (simple, non-primary)
  Widget _buildCompassButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _triggerBounce(_bounceCompassCtrl);
        widget.mapController.rotate(0);
      },
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Transform.rotate(
                angle: -widget.rotation * (math.pi / 180),
                child: Icon(
                  Icons.navigation,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bouton de localisation avec transition d'icône et glow animé
  Widget _buildAnimatedLocationButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPrimary = widget.trackingState != 0;

    final IconData iconData = widget.trackingState == 2
        ? Icons.explore
        : (widget.trackingState == 1
            ? Icons.my_location
            : Icons.location_searching);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _triggerBounce(_bounceLocationCtrl);
        widget.onMyLocationPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isPrimary
              ? colorScheme.primary.withValues(alpha: 0.95)
              : colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? colorScheme.primary.withValues(alpha: 0.40)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isPrimary ? 24 : 12,
              spreadRadius: isPrimary ? 3 : 0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              // AnimatedSwitcher avec rotation + scale entre les 3 états
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: RotationTransition(
                    turns: Tween<double>(begin: 0.12, end: 0.0)
                        .animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                ),
                child: Icon(
                  iconData,
                  key: ValueKey(widget.trackingState),
                  color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Groupe Zoom (+ / -)
  Widget _buildZoomGroup(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBouncingButton(
                ctrl: _bounceZoomPlusCtrl,
                child: _buildRawButton(
                  context,
                  Icons.add,
                  () {
                    HapticFeedback.lightImpact();
                    _triggerBounce(_bounceZoomPlusCtrl);
                    _animateZoom(widget.mapController.camera.zoom + 1);
                  },
                ),
              ),
              Container(
                height: 1,
                width: 32,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              _buildBouncingButton(
                ctrl: _bounceZoomMinusCtrl,
                child: _buildRawButton(
                  context,
                  Icons.remove,
                  () {
                    HapticFeedback.lightImpact();
                    _triggerBounce(_bounceZoomMinusCtrl);
                    _animateZoom(widget.mapController.camera.zoom - 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bouton simple sans décor externe (utilisé dans le groupe zoom)
  Widget _buildRawButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: colorScheme.onSurface, size: 24),
        ),
      ),
    );
  }
}
