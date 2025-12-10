class Habit {
  final String id;
  final String uniqueHabitId; // Unique ID shared across all instances of the same habit
  final String name;
  final DateTime createdAt;
  final int durationMinutes; // Duration in minutes (1-5)
  final DateTime date; // Date this habit is associated with

  Habit({
    required this.id,
    required this.uniqueHabitId,
    required this.name,
    required this.createdAt,
    required this.durationMinutes,
    required this.date,
  });

  Habit copyWith({
    String? id,
    String? uniqueHabitId,
    String? name,
    DateTime? createdAt,
    int? durationMinutes,
    DateTime? date,
  }) {
    return Habit(
      id: id ?? this.id,
      uniqueHabitId: uniqueHabitId ?? this.uniqueHabitId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      date: date ?? this.date,
    );
  }

  int get durationSeconds => durationMinutes * 60;
}
