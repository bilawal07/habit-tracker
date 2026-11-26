/// Fixed daily notification time slot.
class ReminderSlot {
  const ReminderSlot({
    required this.index,
    required this.hour,
    required this.minute,
    required this.label,
  });

  final int index;
  final int hour;
  final int minute;
  final String label;
}

/// Strict Fire Mode daily slots (fired only if tasks remain unchecked today).
const List<ReminderSlot> kStrictReminderSlots = [
  ReminderSlot(index: 0, hour: 6, minute: 0, label: '6:00 AM'),
  ReminderSlot(index: 1, hour: 13, minute: 0, label: '1:00 PM'),
  ReminderSlot(index: 2, hour: 20, minute: 0, label: '8:00 PM'),
  ReminderSlot(index: 3, hour: 23, minute: 0, label: '11:00 PM'),
];

/// Standard Mode daily slots (lighter cadence).
const List<ReminderSlot> kStandardReminderSlots = [
  ReminderSlot(index: 0, hour: 6, minute: 0, label: '6:00 AM'),
  ReminderSlot(index: 2, hour: 20, minute: 0, label: '8:00 PM'),
];
