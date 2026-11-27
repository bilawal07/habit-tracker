import 'package:flutter/material.dart';

import '../../../core/constants/badge_definitions.dart';
import '../../../core/theme/app_colors.dart';
import '../badge_visuals.dart';

/// Displays a celebratory popup when checking in unlocks one or more new badges.
Future<void> showBadgeUnlockDialog(
  BuildContext context,
  List<BadgeKey> unlockedKeys, {
  VoidCallback? onViewBadges,
}) {
  if (unlockedKeys.isEmpty) return Future.value();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;
      final palette =
          theme.extension<HabitPalette>() ?? HabitPalette.light;

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: CircleAvatar(
          radius: 30,
          backgroundColor: palette.fireContainer,
          child: Icon(
            kBadgeVisuals[unlockedKeys.first]!.icon,
            size: 32,
            color: kBadgeVisuals[unlockedKeys.first]!.color,
          ),
        ),
        title: Text(
          unlockedKeys.length == 1
              ? 'Badge Unlocked!'
              : '${unlockedKeys.length} Badges Unlocked!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < unlockedKeys.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Builder(
                builder: (_) {
                  final def = badgeDefinitionFor(unlockedKeys[i]);
                  final visual = kBadgeVisuals[unlockedKeys[i]]!;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: visual.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: visual.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(visual.icon, color: visual.color, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                def.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                def.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          if (onViewBadges != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onViewBadges();
              },
              child: const Text('View Badges'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep Going'),
          ),
        ],
      );
    },
  );
}
