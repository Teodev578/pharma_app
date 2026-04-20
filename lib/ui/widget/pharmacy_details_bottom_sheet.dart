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

          // Statut (Ouvert = succès via primary, Fermé = erreur, Inconnu = Orange)
          final Color openBgColor;
          final Color openTextColor;
          final IconData openIcon;

          if (isOpen || isDeGarde) {
            openBgColor = theme.colorScheme.primaryContainer;
            openTextColor = theme.colorScheme.onPrimaryContainer;
            openIcon = Icons.check_circle;
          } else if (isClosed) {
            openBgColor = theme.colorScheme.errorContainer;
            openTextColor = theme.colorScheme.onErrorContainer;
            openIcon = Icons.access_time_filled_rounded;
          } else {
            openBgColor = const Color(0xFFFFE0B2);
            openTextColor = const Color(0xFFE65100);
            openIcon = Icons.warning_amber_rounded;
          }

          String displayStatus = isUnknown ? 'Vérifier sur place' : pharmacy.statutActuel!;
          final cardBgColor = theme.colorScheme.surfaceContainerHighest;
          final buttonBgColor = theme.colorScheme.primary;
          final buttonTextColor = theme.colorScheme.onPrimary;
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.15),
                          spreadRadius: 0,
                          blurRadius: 40,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(10),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: openBgColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(openIcon, size: 18, color: openTextColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          displayStatus,
                                          style: TextStyle(
                                            color: openTextColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (pharmacy.telephone != null)
                                    IconButton.filledTonal(
                                      onPressed: () async {
                                        HapticFeedback.selectionClick();
                                        final Uri phoneUri = Uri(
                                          scheme: 'tel',
                                          path: pharmacy.telephone!.replaceAll(RegExp(r'\s+'), ''),
                                        );
                                        if (await canLaunchUrl(phoneUri)) {
                                          await launchUrl(phoneUri);
                                        }
                                      },
                                      icon: const Icon(Icons.phone),
                                      style: IconButton.styleFrom(
                                        backgroundColor: theme.colorScheme.secondaryContainer,
                                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                                      ),
                                    ),

                                  IconButton.filledTonal(
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      await settingsController.toggleFavorite(pharmacy.nom);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isFavorite
                                                  ? 'Retiré des favoris'
                                                  : 'Ajouté aux favoris ❤️',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorite ? Colors.red : null,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.colorScheme.secondaryContainer,
                                      foregroundColor: isFavorite ? Colors.red : theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Lien de la pharmacie copié (Simulé)'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.share_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.colorScheme.secondaryContainer,
                                      foregroundColor: theme.colorScheme.onSecondaryContainer,
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
                                    Clipboard.setData(ClipboardData(text: pharmacy.telephone!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Numéro copié',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              if (pharmacy.horairesOuverture != null && pharmacy.horairesOuverture!.isNotEmpty)
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
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: isHoursExpanded
                                          ? pharmacy.horairesOuverture!.map((h) {
                                              final horaire = h is Map ? h : {};
                                              final jour = horaire['jour']?.toString() ?? h.toString();
                                              final heure = horaire['heure']?.toString() ?? '';
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      jour,
                                                      style: theme.textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        color: theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                    Text(
                                                      heure,
                                                      style: theme.textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w400,
                                                        color: theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList()
                                          : [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      "Voir les horaires de la semaine",
                                                      style: theme.textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        color: theme.colorScheme.primary,
                                                      ),
                                                      overflow: TextOverflow.visible,
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
                                    sheetBgColor.withOpacity(0.0),
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: buttonBgColor,
                                    foregroundColor: buttonTextColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    if (onDirectionsPressed != null) onDirectionsPressed();
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
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
