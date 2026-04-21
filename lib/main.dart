import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharma_app/ui/screens/onboarding_screen.dart';
import 'package:pharma_app/ui/screens/welcome_screen.dart';
import 'package:pharma_app/ui/screens/map_screen.dart';
import 'package:pharma_app/ui/screens/settings_screen.dart';
import 'package:pharma_app/core/config.dart';
import 'package:pharma_app/ui/widget/global_error_screen.dart';
import 'package:pharma_app/services/settings_controller.dart';
import 'package:pharma_app/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Gestion des erreurs Flutter (Framework)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('GlobalError: ${details.exception}');
  };

  // Gestion des erreurs d'affichage (UI)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return GlobalErrorScreen(details: details);
  };

  // Initialisation par défaut pour éviter les erreurs de late initialization
  final settingsController = SettingsController(SettingsService());
  bool hasSeenOnboarding = false;
  bool hasSeenWelcome = false;

  try {
    // Initialisation de Supabase (peut échouer ou être lente si hors ligne)
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 2));

    // Initialisation des paramètres
    await settingsController.loadSettings();

    final prefs = await SharedPreferences.getInstance();
    hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation : $e');
    // On continue quand même pour lancer l'app en mode limité
  }

  runApp(
    MainApp(
      settingsController: settingsController,
      hasSeenOnboarding: hasSeenOnboarding,
      hasSeenWelcome: hasSeenWelcome,
    ),
  );
}

class MainApp extends StatelessWidget {
  final SettingsController settingsController;
  final bool hasSeenOnboarding;
  final bool hasSeenWelcome;
  
  const MainApp({
    super.key,
    required this.settingsController,
    required this.hasSeenOnboarding,
    required this.hasSeenWelcome,
  });

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF10B981); // Emerald green for a premium look
    final lightTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    );
    final darkTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          showPerformanceOverlay: false,
          debugShowCheckedModeBanner: false,
          title: 'Pharma App',
          themeMode: settingsController.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
            ),
            textTheme: lightTextTheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
            ),
            textTheme: darkTextTheme,
            useMaterial3: true,
          ),
          initialRoute: !hasSeenOnboarding
              ? OnboardingScreen.routeName
              : !hasSeenWelcome
              ? WelcomeScreen.routeName
              : MapScreen.routeName,
          routes: {
            OnboardingScreen.routeName: (context) => const OnboardingScreen(),
            WelcomeScreen.routeName: (context) => const WelcomeScreen(),
            MapScreen.routeName: (context) => MapScreen(settingsController: settingsController),
            SettingsScreen.routeName: (context) => SettingsScreen(controller: settingsController),
          },
        );
      },
    );
  }
}
