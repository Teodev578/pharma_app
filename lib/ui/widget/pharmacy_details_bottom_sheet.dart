import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/services/settings_controller.dart';

/// Affiche une BottomSheet présentant les détails d'une pharmacie.
/// Intègre des comportements premium : retours haptiques, bouton flottant,
/// actions rapides en ligne et horaires rétractables.
void showPharmacyDetailsBottomSheet(
  BuildContext context,
  Pharmacy pharmacy, {
  VoidCallback? onDirectionsPressed,
  required SettingsController settingsController,
  void Function(String)? onMessage,
}) {
  final status = pharmacy.statutActuel?.toLowerCase();
  final bool isOpen = status == 'ouvert' || status == 'ouverte';
  final bool isClosed = status == 'fermé' || status == 'fermee';
  final bool isDeGarde = status == 'de garde';
  final bool isUnknown =
      status == null ||
      status == 'inconnu' ||
      (!isOpen && !isClosed && !isDeGarde);

  bool isHoursExpanded = false; // État local pour le toggle des horaires

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);

          // Statut Material 3 Tokens
          final Color statusBgColor;
          final Color statusTextColor;
          final IconData statusIcon;

          if (isOpen || isDeGarde) {
            statusBgColor = theme.colorScheme.primaryContainer;
            statusTextColor = theme.colorScheme.onPrimaryContainer;
            statusIcon = Icons.check_circle;
          } else if (isClosed) {
            statusBgColor = theme.colorScheme.errorContainer;
            statusTextColor = theme.colorScheme.onErrorContainer;
            statusIcon = Icons.access_time_filled_rounded;
          } else {
            statusBgColor = theme.colorScheme.tertiaryContainer;
            statusTextColor = theme.colorScheme.onTertiaryContainer;
            statusIcon = Icons.warning_amber_rounded;
          }

          String displayStatus = isUnknown
              ? 'Vérifier sur place'
              : pharmacy.statutActuel!;
          final cardBgColor = theme.colorScheme.surfaceContainerHighest;
          final sheetBgColor = theme.colorScheme.surfaceContainerLow;

          final bool isFavorite = settingsController.isFavorite(pharmacy.nom);

          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: sheetBgColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28), // M3 ExtraLarge top
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.15),
                      spreadRadius: 0,
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28), // M3 ExtraLarge top
                  ),
                  child: Stack(
                    children: [
                      ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Center(
                            child: Container(
                              width: 48,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8), // Handle
                              ),
                            ),
                          ),

                          Text(
                            pharmacy.nom,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 18,
                                          color: statusTextColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            displayStatus,
                                            style: TextStyle(
                                              color: statusTextColor,
                                              fontSize: 14, // Slightly smaller to help
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (pharmacy.telephone != null)
                                IconButton.filledTonal(
                                  onPressed: () async {
                                    HapticFeedback.selectionClick();
                                    final Uri phoneUri = Uri(
                                      scheme: 'tel',
                                      path: pharmacy.telephone!.replaceAll(
                                        RegExp(r'\s+'),
                                        '',
                                      ),
                                    );
                                    if (await canLaunchUrl(phoneUri)) {
                                      await launchUrl(phoneUri);
                                    }
                                  },
                                  icon: const Icon(Icons.phone),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        theme.colorScheme.secondaryContainer,
                                    foregroundColor:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),

                              IconButton.filledTonal(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  await settingsController.toggleFavorite(
                                    pharmacy.nom,
                                  );
                                  onMessage?.call(
                                    isFavorite
                                        ? 'Retiré des favoris'
                                        : 'Ajouté aux favoris ❤️',
                                  );
                                },
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite 
                                      ? theme.colorScheme.tertiary 
                                      : theme.colorScheme.onSecondaryContainer,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  onMessage?.call('Lien de la pharmacie copié (Simulé)');
                                },
                                icon: const Icon(Icons.share_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                  foregroundColor:
                                      theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          if (pharmacy.adresse != null)
                            _buildMockupCard(
                              theme: theme,
                              bgColor: cardBgColor,
                              icon: Icons.location_on,
                              label: 'adresse',
                              child: Text(
                                pharmacy.adresse!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),

                          if (pharmacy.telephone != null)
                            _buildMockupCard(
                              theme: theme,
                              bgColor: cardBgColor,
                              icon: Icons.phone,
                              label: 'Téléphone',
                              child: Text(
                                pharmacy.telephone!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                              trailing: Icon(
                                Icons.copy_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Clipboard.setData(
                                  ClipboardData(text: pharmacy.telephone!),
                                );
                                onMessage?.call('Numéro copié');
                              },
                            ),

                          if (pharmacy.horairesOuverture != null &&
                              pharmacy.horairesOuverture!.isNotEmpty)
                            _buildMockupCard(
                              theme: theme,
                              bgColor: cardBgColor,
                              icon: Icons.access_time_filled_rounded,
                              label: 'Horaires',
                              trailing: Icon(
                                isHoursExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 28,
                              ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  isHoursExpanded = !isHoursExpanded;
                                });
                              },
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.fastOutSlowIn,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: isHoursExpanded
                                      ? pharmacy.horairesOuverture!.map((h) {
                                          final horaire = h is Map ? h : {};
                                          final jour =
                                              horaire['jour']?.toString() ??
                                              h.toString();
                                          final heure =
                                              horaire['heure']?.toString() ??
                                              '';
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  jour,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface,
                                                      ),
                                                ),
                                                Text(
                                                  heure,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList()
                                      : [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "Voir les horaires de la semaine",
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                  overflow:
                                                      TextOverflow.visible,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),

                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                sheetBgColor,
                                sheetBgColor,
                                sheetBgColor.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16), // M3 Large button
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                if (onDirectionsPressed != null)
                                  onDirectionsPressed();
                              },
                              icon: const Icon(Icons.directions, size: 24),
                              label: const Text(
                                'Obtenir l\'itinéraire',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

/// [_buildMockupCard] : Génère un bloc d'information standardisé Material 3.
Widget _buildMockupCard({
  required ThemeData theme,
  required Color bgColor,
  required IconData icon,
  required String label,
  required Widget child,
  Widget? trailing,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  final labelBgColor = theme.colorScheme.secondaryContainer;
  final labelTextColor = theme.colorScheme.onSecondaryContainer;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16), // M3 Medium
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: labelBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: labelTextColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: labelTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    child,
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 16), trailing],
            ],
          ),
        ),
      ),
    ),
  );
}
