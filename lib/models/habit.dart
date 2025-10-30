class Habit {
  final String id;
  final String name;
  final DateTime createdAt;
  
  Habit({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  
  Habit copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

