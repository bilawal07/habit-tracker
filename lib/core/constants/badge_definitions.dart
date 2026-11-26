/// Identifiers for the five milestone badges earned per task.
enum BadgeKey {
  firstSpark('first_spark'),
  flame3('flame_3'),
  comebackPhoenix('comeback'),
  inferno7('inferno_7'),
  unstoppable30('unstoppable_30');

  const BadgeKey(this.storageKey);

  final String storageKey;

  static BadgeKey fromStorageKey(String key) {
    return BadgeKey.values.firstWhere(
      (value) => value.storageKey == key,
      orElse: () => throw ArgumentError('Unknown badge key: $key'),
    );
  }
}

/// Static display metadata for each of the five badges.
class BadgeDefinition {
  const BadgeDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.targetDays,
  });

  final BadgeKey key;
  final String title;
  final String description;
  final int targetDays;
}

const List<BadgeDefinition> kBadgeDefinitions = [
  BadgeDefinition(
    key: BadgeKey.firstSpark,
    title: 'First Spark',
    description: 'Complete your very first day on a task.',
    targetDays: 1,
  ),
  BadgeDefinition(
    key: BadgeKey.flame3,
    title: '3-Day Flame',
    description: 'Reach a 3-day consecutive streak (Hot Fire).',
    targetDays: 3,
  ),
  BadgeDefinition(
    key: BadgeKey.comebackPhoenix,
    title: 'Comeback Phoenix',
    description: 'Turn a Cold streak back into Hot Fire.',
    targetDays: 3,
  ),
  BadgeDefinition(
    key: BadgeKey.inferno7,
    title: '7-Day Inferno',
    description: 'Reach a 7-day consecutive streak.',
    targetDays: 7,
  ),
  BadgeDefinition(
    key: BadgeKey.unstoppable30,
    title: '30-Day Unstoppable',
    description: 'Reach a 30-day consecutive streak.',
    targetDays: 30,
  ),
];
