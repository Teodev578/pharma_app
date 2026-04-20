import 'package:flutter/material.dart';
import 'package:pharma_app/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onTap;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ConnectivityService connectivityService = ConnectivityService();

    return StreamBuilder<List<ConnectivityResult>>(
      stream: connectivityService.connectivityStream,
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];
        final isOffline =
            results.isEmpty || results.contains(ConnectivityResult.none);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            height: 56, // Hauteur standard M3 SearchBar
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  isOffline ? Icons.wifi_off : Icons.search,
                  color: isOffline ? Colors.orangeAccent : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onTap: onTap,
                    enabled: !isOffline,
                    style: textTheme.bodyLarge?.copyWith(
                      color: isOffline
                          ? colorScheme.onSurface.withValues(alpha: 0.5)
                          : colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: isOffline
                          ? "Hors connexion..."
                          : "Recherche de pharmacie...",
                      hintStyle: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (!isOffline && (controller?.text.isNotEmpty ?? false))
                  IconButton(
                    icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                    onPressed: () {
                      controller?.clear();
                      if (onClear != null) onClear!();
                      if (onChanged != null) onChanged!('');
                      FocusScope.of(context).unfocus();
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    tooltip: 'Profil',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
