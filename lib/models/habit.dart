class Habit {
  final String id;
  final String name;
  final DateTime createdAt;
  final int durationMinutes; // Duration in minutes (1-5)
  
  Habit({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.durationMinutes,
  });
  
  Habit copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? durationMinutes,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
  
  int get durationSeconds => durationMinutes * 60;
}

