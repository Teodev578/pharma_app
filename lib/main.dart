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

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  final bool hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
  
  runApp(MainApp(
    hasSeenOnboarding: hasSeenOnboarding,
    hasSeenWelcome: hasSeenWelcome,
  ));
}

class MainApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  final bool hasSeenWelcome;
  const MainApp({
    super.key,
    required this.hasSeenOnboarding,
    required this.hasSeenWelcome,
  });

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF10B981); // Emerald green for a premium look
    final lightTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme);
    final darkTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pharma App',
      themeMode: ThemeMode.system,
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
        MapScreen.routeName: (context) => const MapScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
      },
    );
  }
}
