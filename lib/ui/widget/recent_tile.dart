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

    final statusLower = status?.toLowerCase() ?? '';
    if (statusLower == 'de garde') {
      bgColor = const Color(0xFFDCE5D8);
      iconBgColor = const Color(0xFF266649);
    } else if (statusLower == 'fermée' || statusLower == 'fermee') {
      bgColor = const Color(0xFFFDEBEE);
      iconBgColor = Colors.red.shade800;
    } else {
      bgColor = colorScheme.surfaceContainerHighest;
      iconBgColor = colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_pharmacy, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.black87),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
