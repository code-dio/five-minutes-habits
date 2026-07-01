import '../models/habit.dart';

abstract class BaseHabitStorage {
  Future<Map<String, dynamic>> loadHabitsData();
  
  Future<void> saveHabitsData({
    required Map<String, List<Habit>> habitsByDate,
    required Map<String, int> remainingSeconds,
    required Map<String, int> habitDurations,
    required Map<String, bool> habitCompletionStatus,
  });
  
  Future<void> upsertHabit(
    Habit habit, {
    required int durationSeconds,
    required int remainingSeconds,
    required bool isCompleted,
  });
  
  Future<void> updateHabitProgress(
    String habitId, {
    required int remainingSeconds,
    required bool isCompleted,
  });
  
  Future<void> deleteHabitsByUniqueId(String uniqueHabitId);
  
  Future<void> updateHabitNameAndDuration(
    String uniqueHabitId, {
    required String name,
    required int durationMinutes,
    required int durationSeconds,
  });
}
