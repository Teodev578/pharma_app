import 'package:flutter/material.dart';

class RecentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? status;
  final VoidCallback? onTap;

  const RecentTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color bgColor;
    Color iconBgColor;
    Color iconColor = Colors.white;
    Color textColor = colorScheme.onSurface;
    Color subtitleColor = colorScheme.onSurfaceVariant;

    final statusLower = status?.toLowerCase() ?? '';
    if (statusLower == 'de garde') {
      bgColor = const Color(0xFFDCE5D8); 
      iconBgColor = const Color(0xFF266649);
      textColor = const Color(0xFF1E1E1E);
      subtitleColor = const Color(0xFF333333);
    } else if (statusLower == 'fermée' || statusLower == 'fermee') {
      bgColor = colorScheme.errorContainer;
      iconBgColor = colorScheme.error;
      iconColor = colorScheme.onError;
      textColor = colorScheme.onErrorContainer;
      subtitleColor = colorScheme.onErrorContainer.withOpacity(0.8);
    } else {
      bgColor = colorScheme.surfaceContainerHighest;
      iconBgColor = colorScheme.primary;
      iconColor = colorScheme.onPrimary;
      textColor = colorScheme.onSurface;
      subtitleColor = colorScheme.onSurfaceVariant;
    }

    return Card(
      elevation: 0,
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconBgColor,
              foregroundColor: iconColor,
              radius: 24,
              child: const Icon(Icons.local_pharmacy),
            ),
            title: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: subtitleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(Icons.chevron_right, color: subtitleColor),
          ),
        ),
      ),
    );
  }
}
