import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour HapticFeedback
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharma_app/ui/screens/welcome_screen.dart';

// --- DONNÉES ---
class OnboardingStep {
  final String title;
  final String content;
  final IconData? icon; // Solution temporaire
  final String?
  assetPath; // PRÉPARATION: Chemin vers ton image/lottie (ex: 'assets/images/step1.png')

  OnboardingStep({
    required this.title,
    required this.content,
    this.icon,
    this.assetPath,
  });
}

class OnboardingScreen extends StatefulWidget {
  static const String routeName = '/splash';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // 2. CORRECTION DES ICÔNES ET PRÉPARATION ASSETS
  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: "Pharmacies de garde",
      content:
          "Trouvez instantanément les pharmacies ouvertes en dehors des horaires habituels, même la nuit.",
      icon: Icons.local_pharmacy_rounded,
    ),
    OnboardingStep(
      title: "Autour de vous",
      content:
          "Visualisez les pharmacies sur une carte interactive pour voir celles qui sont les plus proches.",
      icon: Icons.map_rounded,
    ),
    OnboardingStep(
      title: "Disponibilité temps réel",
      content:
          "Vérifiez l'ouverture en direct pour éviter les déplacements inutiles et gagner du temps.",
      icon: Icons.update_rounded,
    ),
    OnboardingStep(
      title: "Trajet optimisé",
      content: "Obtenez l'itinéraire le plus rapide pour rejoindre votre pharmacie en un clin d'œil.",
      icon: Icons.directions_car_rounded,
    ),
  ];

  bool _notificationsEnabled = false;
  bool _locationEnabled = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus();
    }
  }

  Future<void> _checkPermissionsStatus() async {
    try {
      final notifStatus = await Permission.notification.status;
      final locationStatus = await Permission.locationWhenInUse.status;
      if (mounted) {
        setState(() {
          _notificationsEnabled = notifStatus.isGranted;
          _locationEnabled = locationStatus.isGranted;
        });
      }
    } on MissingPluginException {
      debugPrint("Plugin Permission non trouvé. Soit un 'Stop et Relancer' est nécessaire, soit l'OS (ex: Linux) n'est pas supporté par le plugin.");
    } catch (e) {
      debugPrint("Erreur de statut de permission: $e");
    }
  }

  Future<void> _togglePermission(Permission permission, bool value) async {
    if (_isRequestingPermission) return;
    await HapticFeedback.lightImpact();

    if (value) {
      _isRequestingPermission = true;
      try {
        final status = await permission.request();
        if (status.isPermanentlyDenied) {
          await HapticFeedback.heavyImpact();
          if (mounted) _showSettingsDialog(permission: permission);
        } else {
          if (mounted) {
            setState(() {
              if (permission == Permission.notification) {
                _notificationsEnabled = status.isGranted;
              } else if (permission == Permission.locationWhenInUse) {
                _locationEnabled = status.isGranted;
              }
            });
          }
          if (status.isGranted) await HapticFeedback.lightImpact();
        }
      } on MissingPluginException {
        debugPrint("MissingPluginException: Redémarrage complet nécessaire, ou OS non supporté (Linux).");
        // Simule l'activation de la permission pour ne pas bloquer l'UI sur Linux Desktop
        if (mounted) {
          setState(() {
            if (permission == Permission.notification) _notificationsEnabled = true;
            else if (permission == Permission.locationWhenInUse) _locationEnabled = true;
          });
        }
      } catch (e) {
        debugPrint("Erreur permission: $e");
      } finally {
        _isRequestingPermission = false;
      }
    } else {
      _showSettingsDialog(permission: permission, isRevoking: true);
    }
  }

  void _showSettingsDialog({Permission? permission, bool isRevoking = false}) {
    String title = "Permission requise";
    String description = "Activez cette permission dans les paramètres pour continuer.";

    if (isRevoking) {
      title = "Désactivation";
      description = "Pour désactiver cette permission, vous devez passer par les paramètres de l'appareil.";
    } else if (permission == Permission.notification) {
      title = "Notifications";
      description = "Autorisez les notifications pour rester informé des gardes en temps réel.";
    } else if (permission == Permission.locationWhenInUse) {
      title = "Localisation";
      description = "Autorisez l'accès à votre position pour trouver les pharmacies proches.";
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Plus tard"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Paramètres"),
          ),
        ],
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    await HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(WelcomeScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isLastPage = _currentIndex == _steps.length;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final Color primaryColor = colorScheme.primary;

    // Couleur de fond des bulles : plus dynamique avec M3
    final Color bubbleColor = colorScheme.primaryContainer.withValues(alpha: 0.2);
    final Color accentBubbleColor = colorScheme.secondaryContainer.withValues(alpha: 0.15);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // --- DÉCORATION SUBTILE (VASE STYLE) ---
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            top: _currentIndex % 2 == 0 ? -120 : -60,
            right: _currentIndex % 2 == 0 ? -60 : -180,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bubbleColor, // Gris très léger
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            bottom: _currentIndex % 2 == 0 ? -80 : -140,
            left: _currentIndex % 2 == 0 ? -140 : -40,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBubbleColor,
              ),
            ),
          ),

          // --- CONTENU ---
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _steps.length + 1,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      if (index == _steps.length) {
                        return _buildPermissionPage(
                          colorScheme,
                          textTheme,
                          isLandscape,
                          primaryColor,
                        );
                      }
                      return _buildOnboardingPage(
                        _steps[index],
                        colorScheme,
                        textTheme,
                        isLandscape,
                        index == _currentIndex,
                        primaryColor,
                      );
                    },
                  ),
                ),

                // Navigation
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: isLandscape ? 8.0 : 32.0,
                  ),
                  child: _buildBottomNavigation(
                    isLastPage,
                    colorScheme,
                    primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(
    bool isLastPage,
    ColorScheme colorScheme,
    Color activeColor,
  ) {
    // M3 : Utilisation des couleurs primaires pour l'action principale
    final btnBgColor = colorScheme.primary;
    final btnFgColor = colorScheme.onPrimary;

    if (isLastPage) {
      return Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _finishOnboarding,
          icon: Icon(Icons.check_circle_rounded, size: 20, color: btnFgColor),
          label: Text("Commencer", style: TextStyle(color: btnFgColor, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: btnBgColor,
            foregroundColor: btnFgColor,
            elevation: 0,
            minimumSize: const Size(180, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _pageController.animateToPage(
              _steps.length,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutQuart,
            );
          },
          child: Text(
            "Passer",
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: List.generate(_steps.length, (index) {
            final active = _currentIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 10,
              width: active ? 28 : 10,
              decoration: BoxDecoration(
                color: active
                    ? activeColor
                    : activeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
        IconButton.filled(
          onPressed: () {
            HapticFeedback.lightImpact();
            _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
            );
          },
          icon: Icon(Icons.chevron_right_rounded, size: 28, color: btnFgColor),
          style: IconButton.styleFrom(
            backgroundColor: btnBgColor,
            foregroundColor: btnFgColor,
            elevation: 0,
            minimumSize: const Size(64, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingPage(
    OnboardingStep step,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLandscape,
    bool isActive,
    Color monoColor,
  ) {
    final content = isLandscape
        ? Row(
            children: [
              Expanded(
                child: _buildAnimatedIllustration(step, isActive, monoColor),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: _buildStepText(step, textTheme, colorScheme, false),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              _buildAnimatedIllustration(step, isActive, monoColor),
              const SizedBox(height: 48), // Espace fixe au lieu de Spacer
              _buildStepText(step, textTheme, colorScheme, true),
              const Spacer(flex: 2),
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: content,
    );
  }

  // 3. LOGIQUE D'ASSETS OU ICONES
  Widget _buildAnimatedIllustration(
    OnboardingStep step,
    bool isActive,
    Color monoColor,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Center(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Cercle gris très pâle pour encadrer l'illustration
            color: monoColor.withValues(alpha: 0.05),
          ),
          child: step.assetPath != null
              // S'il y a un vrai asset (Image/SVG/Rive), on l'affiche ici
              ? Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Image.asset(step.assetPath!, fit: BoxFit.contain),
                )
              // Sinon, on affiche l'icône système (Style Monochrome)
              : Icon(
                  step.icon,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
        ),
      ),
    );
  }

  Widget _buildStepText(
    OnboardingStep step,
    TextTheme textTheme,
    ColorScheme colorScheme,
    bool center,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          // Utilisation du style Material 3 Headline
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          step.content,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionPage(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLandscape,
    Color monoColor,
  ) {
    final List<Widget> permissionCards = [
      _buildPermissionCard(
        context,
        "📍",
        "Localisation",
        "Pour afficher les pharmacies proches de vous.",
        _locationEnabled,
        (val) => _togglePermission(Permission.locationWhenInUse, val),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      const SizedBox(height: 16),
      _buildPermissionCard(
        context,
        "🔔",
        "Notifications",
        "Pour ne rater aucune mise à jour des gardes.",
        _notificationsEnabled,
        (val) => _togglePermission(Permission.notification, val),
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
    ];

    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text("Dernière étape", style: textTheme.displayMedium),
                  const SizedBox(height: 16),
                  Text(
                    "Autorisez ces accès pour que l'expérience Pharma soit parfaite.",
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: permissionCards,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            "Dernière étape",
            style: textTheme.displayMedium?.copyWith(fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Autorisez ces accès pour que l'expérience Pharma soit parfaite.",
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 48),
          ...permissionCards,
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    String iconEmoji,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color bgColor,
    Color textColor,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textColor.withValues(alpha: 0.1), width: 1.5),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(iconEmoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: textColor,
                activeTrackColor: textColor.withValues(alpha: 0.3),
                inactiveThumbColor: textColor.withValues(alpha: 0.8),
                inactiveTrackColor: textColor.withValues(alpha: 0.1),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.transparent;
                  }
                  return textColor.withValues(alpha: 0.5);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
