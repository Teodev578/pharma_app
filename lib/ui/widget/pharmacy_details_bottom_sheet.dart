import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pharma_app/models/pharmacy.dart';

/// Affiche une BottomSheet présentant les détails d'une pharmacie.
/// Intègre des comportements premium : retours haptiques, bouton flottant,
/// actions rapides en ligne et horaires rétractables.
void showPharmacyDetailsBottomSheet(BuildContext context, Pharmacy pharmacy, {VoidCallback? onDirectionsPressed}) {
  final isOpen = pharmacy.statutActuel == 'Ouvert';
  bool isHoursExpanded = false; // État local pour le toggle des horaires

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent, // Rendu du fond géré par le Container principal de DraggableScrollableSheet
    isScrollControlled: true, // Permet un dimensionnement plus fin du BottomSheet
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          
          // Configuration adaptative des couleurs selon le mode sombre/clair
          final openBgColor = isOpen 
              ? (isDark ? const Color(0xFF1B4332) : const Color(0xFFA8E6BB))
              : (isDark ? theme.colorScheme.errorContainer : theme.colorScheme.errorContainer);
          final openTextColor = isOpen 
              ? (isDark ? const Color(0xFFA8E6BB) : Colors.black)
              : theme.colorScheme.onErrorContainer;
              
          // Couleur de fond générale des cartes
          final cardBgColor = isDark 
              ? theme.colorScheme.surfaceContainerHighest 
              : const Color(0xFFD8ECD8); 

          // Couleur de fond pour le gros bouton de navigation
          final buttonBgColor = isDark ? theme.colorScheme.primary : const Color(0xFF095834);

          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : const Color(0xFFF7F9F8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
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
                      // Contenu défilant principal
                      ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120), // Espace supplémentaire en bas pour le bouton
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // --- POIGNÉE DE DRAG ---
                          Center(
                            child: Container(
                              width: 48,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          
                          // --- TITRE DE LA PHARMACIE ---
                          Text(
                            pharmacy.nom,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // --- STATUT ET ACTIONS RAPIDES ---
                          Row(
                            children: [
                              // Badge (Ouvert / Fermé)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: openBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOpen ? Icons.check_circle : Icons.access_time_filled_rounded,
                                      size: 18,
                                      color: openTextColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      pharmacy.statutActuel ?? 'Inconnu',
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
                              
                              // Quick Action : Téléphone
                              if (pharmacy.telephone != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: IconButton.filledTonal(
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
                                      backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                
                              // Quick Action : Partager
                              IconButton.filledTonal(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Lien de la pharmacie copié (Simulé)'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    )
                                  );
                                },
                                icon: const Icon(Icons.share_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // --- CARTE D'ADRESSE ---
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

                          // --- CARTE TÉLÉPHONE ---
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
                              trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface, size: 36),
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final Uri phoneUri = Uri(
                                  scheme: 'tel',
                                  path: pharmacy.telephone!.replaceAll(RegExp(r'\s+'), ''),
                                );
                                if (await canLaunchUrl(phoneUri)) {
                                  await launchUrl(phoneUri);
                                }
                              },
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                Clipboard.setData(ClipboardData(text: pharmacy.telephone!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Numéro copié',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: theme.colorScheme.inverseSurface,
                                  ),
                                );
                              },
                            ),

                          // --- CARTE DES HORAIRES (Animée et rétractable) ---
                          if (pharmacy.horairesOuverture != null && pharmacy.horairesOuverture!.isNotEmpty)
                            _buildMockupCard(
                              theme: theme,
                              bgColor: cardBgColor,
                              icon: Icons.access_time_filled_rounded,
                              label: 'Horaires d\'ouverture',
                              trailing: Icon(
                                isHoursExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                                                    color: theme.colorScheme.primary, // Texte cliquable visible
                                                  ),
                                                  overflow: TextOverflow.visible,
                                                ),
                                              ),
                                            ],
                                          )
                                        ]
                                ),
                              ),
                            ),
                          
                          // Espace supplémentaire transparent pour ne pas être caché par le bouton flottant
                          const SizedBox(height: 16),
                        ],
                      ),
                      
                      // --- BOUTON DE NAVIGATION FLOTTANT ---
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
                                isDark ? theme.colorScheme.surface : const Color(0xFFF7F9F8),
                                isDark ? theme.colorScheme.surface : const Color(0xFFF7F9F8),
                                (isDark ? theme.colorScheme.surface : const Color(0xFFF7F9F8)).withOpacity(0.0),
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
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                if (onDirectionsPressed != null) onDirectionsPressed();
                              },
                              icon: const Icon(Icons.directions, size: 24),
                              label: const Text('Obtenir l\'itinéraire', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
        }
      );
    },
  );
}

/// [_buildMockupCard] : Génère un bloc d'information standardisé,
/// constitué d'une étiquette (pillule bleue), d'un contenu et d'un fond vert clair (en mode clair).
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
  final isDark = theme.brightness == Brightness.dark;
  
  // Couleur de fond typique du badge titre de la carte (Label Pilule bleue)
  final labelBgColor = isDark 
      ? theme.colorScheme.secondaryContainer.withOpacity(0.6) 
      : const Color(0xFFCDEAFC); // Bleu tendre de la maquette

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(
      color: Colors.transparent, // Essentiel pour les animations 'Ink' (ondulation du InkWell)
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
                    // --- Étiquette supérieure (Pilule) ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: labelBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // --- Contenu principal de la carte (ex : "+228 1234567") ---
                    child,
                  ],
                ),
              ),
              // Élément additionnel optionnel superposé à droite de la ligne
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing,
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
