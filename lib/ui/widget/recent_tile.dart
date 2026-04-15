import 'package:flutter/material.dart';

class RecentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? status;
  final VoidCallback? onTap;
  final String? searchQuery;
  final String? distance;

  const RecentTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.status,
    this.onTap,
    this.searchQuery,
    this.distance,
  });

  Widget _buildHighlightedText(String text, String? query, TextStyle? style, Color highlightColor) {
    if (query == null || query.isEmpty) return Text(text, style: style);
    
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);
    
    if (index == -1) return Text(text, style: style);
    
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: style?.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final String statusLower = status?.toLowerCase() ?? '';
    final bool isOpen = statusLower == 'ouvert' || statusLower == 'ouverte';
    final bool isClosed = statusLower == 'fermé' || statusLower == 'fermee';
    final bool isDeGarde = statusLower == 'de garde';
    final bool isUnknown =
        statusLower.isEmpty ||
        statusLower == 'inconnu' ||
        (!isOpen && !isClosed && !isDeGarde);

    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;

    if (isOpen || isDeGarde) {
      statusBgColor = colorScheme.primaryContainer;
      statusTextColor = colorScheme.onPrimaryContainer;
      statusIcon = Icons.check_circle;
    } else if (isClosed) {
      statusBgColor = colorScheme.errorContainer;
      statusTextColor = colorScheme.onErrorContainer;
      statusIcon = Icons.access_time_filled_rounded;
    } else {
      statusBgColor = const Color(0xFFFFE0B2);
      statusTextColor = const Color(0xFFE65100);
      statusIcon = Icons.warning_amber_rounded;
    }

    String displayStatus = isUnknown ? 'Vérifier sur place' : status!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusTextColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                displayStatus,
                                style: TextStyle(
                                  color: statusTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildHighlightedText(
                        title,
                        searchQuery,
                        textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (distance != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        distance!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
