import 'package:flutter/material.dart';

import '../../core/constants/badge_definitions.dart';

/// Shared visual icon and accent metadata for each of the five badges.
class BadgeVisual {
  const BadgeVisual({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}

const Map<BadgeKey, BadgeVisual> kBadgeVisuals = {
  BadgeKey.firstSpark: BadgeVisual(
    icon: Icons.auto_awesome,
    color: Color(0xFFFF9800),
  ),
  BadgeKey.flame3: BadgeVisual(
    icon: Icons.local_fire_department,
    color: Color(0xFFFF5722),
  ),
  BadgeKey.comebackPhoenix: BadgeVisual(
    icon: Icons.whatshot,
    color: Color(0xFFE65100),
  ),
  BadgeKey.inferno7: BadgeVisual(
    icon: Icons.bolt,
    color: Color(0xFFD84315),
  ),
  BadgeKey.unstoppable30: BadgeVisual(
    icon: Icons.emoji_events,
    color: Color(0xFFB71C1C),
  ),
};

BadgeDefinition badgeDefinitionFor(BadgeKey key) {
  return kBadgeDefinitions.firstWhere((def) => def.key == key);
}
