import 'package:flutter/material.dart';

class GlobalErrorScreen extends StatelessWidget {
  final FlutterErrorDetails? details;

  const GlobalErrorScreen({super.key, this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.errorContainer,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bug_report_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                "Oups ! Quelque chose s'est mal passé.",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Une erreur inattendue est survenue. Nos développeurs ont été informés.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  // Redémarrer l'application (simplifié ici par un retour au début)
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Redémarrer l'application"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
