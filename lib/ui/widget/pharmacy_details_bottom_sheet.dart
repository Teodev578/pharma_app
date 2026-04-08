import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_app/models/pharmacy.dart';

void showPharmacyDetailsBottomSheet(BuildContext context, Pharmacy pharmacy) {
  final isOpen = pharmacy.statutActuel == 'Ouvert';
  final statusColor = isOpen
      ? const Color(0xFF22C55E)
      : const Color(0xFFEF4444);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
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
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Header Area with Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusColor.withOpacity(isDark ? 0.2 : 0.1),
                          statusColor.withOpacity(0.02),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Handle
                        Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        
                        // Icon and Title
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.local_pharmacy_rounded, color: statusColor, size: 32),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pharmacy.nom,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isOpen ? Icons.check_circle_rounded : Icons.access_time_rounded,
                                          size: 16,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          pharmacy.statutActuel ?? 'Inconnu',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Content Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pharmacy.adresse != null)
                          _infoCard(
                            theme: theme,
                            icon: Icons.location_on_rounded,
                            iconColor: theme.colorScheme.primary,
                            label: 'Adresse',
                            content: pharmacy.adresse!,
                          ),
                        if (pharmacy.telephone != null)
                          _infoCard(
                            theme: theme,
                            icon: Icons.phone_rounded,
                            iconColor: const Color(0xFF22C55E),
                            label: 'Téléphone',
                            content: pharmacy.telephone!,
                            isClickable: true,
                            onTap: () {
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
                          
                        // Horaires Opening
                        if (pharmacy.horairesOuverture != null && pharmacy.horairesOuverture!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            "Horaires d'ouverture",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                            ),
                            child: Column(
                              children: pharmacy.horairesOuverture!.map((h) {
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
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        heure,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Directions Button
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              final url = pharmacy.itineraireGoogleMaps?.isNotEmpty == true
                                      ? pharmacy.itineraireGoogleMaps!
                                      : (pharmacy.latitude != null && pharmacy.longitude != null
                                          ? 'https://www.google.com/maps/dir/?api=1&destination=${pharmacy.latitude},${pharmacy.longitude}'
                                          : null);
                              if (url != null) {
                                Clipboard.setData(ClipboardData(text: url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Lien copié — collez dans Maps',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.directions_rounded, size: 22),
                            label: const Text('Obtenir l\'itinéraire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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
}

/// Card info réutilisable (adresse, téléphone…)
Widget _infoCard({
  required ThemeData theme,
  required IconData icon,
  required Color iconColor,
  required String label,
  required String content,
  VoidCallback? onTap,
  bool isClickable = false,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isClickable ? iconColor : theme.colorScheme.onSurface,
                        fontWeight: isClickable ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isClickable)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.copy_rounded, size: 18, color: iconColor),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
