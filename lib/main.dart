import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharma_app/ui/screens/onboarding_screen.dart';
import 'package:pharma_app/ui/screens/welcome_screen.dart';
import 'package:pharma_app/ui/screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  runApp(MainApp(hasSeenOnboarding: hasSeenOnboarding));
}

class MainApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const MainApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.green;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pharma App',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: hasSeenOnboarding ? WelcomeScreen.routeName : OnboardingScreen.routeName,
      routes: {
        OnboardingScreen.routeName: (context) => const OnboardingScreen(),
        WelcomeScreen.routeName: (context) => const WelcomeScreen(),
        MapScreen.routeName: (context) => const MapScreen(),
      },
    );
  }
}
