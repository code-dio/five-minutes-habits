import '../models/habit.dart';
import 'base_habit_storage.dart';
import 'habit_storage.dart';

class LocalHabitStorage implements BaseHabitStorage {
  @override
  Future<Map<String, dynamic>> loadHabitsData() async {
    return HabitStorage.loadHabitsData();
  }

  @override
  Future<void> saveHabitsData({
    required Map<String, List<Habit>> habitsByDate,
    required Map<String, int> remainingSeconds,
    required Map<String, int> habitDurations,
    required Map<String, bool> habitCompletionStatus,
  }) async {
    await HabitStorage.saveHabitsData(
      habitsByDate: habitsByDate,
      remainingSeconds: remainingSeconds,
      habitDurations: habitDurations,
      habitCompletionStatus: habitCompletionStatus,
    );
  }

  @override
  Future<void> upsertHabit(
    Habit habit, {
    required int durationSeconds,
    required int remainingSeconds,
    required bool isCompleted,
  }) async {
    final data = await loadHabitsData();
    final habitsByDate = data['habitsByDate'] as Map<String, List<Habit>>;
    final remaining = data['remainingSeconds'] as Map<String, int>;
    final durations = data['habitDurations'] as Map<String, int>;
    final completion = data['habitCompletionStatus'] as Map<String, bool>;

    final dateKey = _dateKey(habit.date);
    final list = habitsByDate.putIfAbsent(dateKey, () => []);

    final index = list.indexWhere((h) => h.id == habit.id);
    if (index >= 0) {
      list[index] = habit;
    } else {
      list.add(habit);
    }

    durations[habit.id] = durationSeconds;
    remaining[habit.id] = remainingSeconds;
    completion[habit.id] = isCompleted;

    await saveHabitsData(
      habitsByDate: habitsByDate,
      remainingSeconds: remaining,
      habitDurations: durations,
      habitCompletionStatus: completion,
    );
  }

  @override
  Future<void> updateHabitProgress(
    String habitId, {
    required int remainingSeconds,
    required bool isCompleted,
  }) async {
    final data = await loadHabitsData();
    final habitsByDate = data['habitsByDate'] as Map<String, List<Habit>>;
    final remaining = data['remainingSeconds'] as Map<String, int>;
    final durations = data['habitDurations'] as Map<String, int>;
    final completion = data['habitCompletionStatus'] as Map<String, bool>;

    remaining[habitId] = remainingSeconds;
    completion[habitId] = isCompleted;

    await saveHabitsData(
      habitsByDate: habitsByDate,
      remainingSeconds: remaining,
      habitDurations: durations,
      habitCompletionStatus: completion,
    );
  }

  @override
  Future<void> deleteHabitsByUniqueId(String uniqueHabitId) async {
    final data = await loadHabitsData();
    final habitsByDate = data['habitsByDate'] as Map<String, List<Habit>>;
    final remaining = data['remainingSeconds'] as Map<String, int>;
    final durations = data['habitDurations'] as Map<String, int>;
    final completion = data['habitCompletionStatus'] as Map<String, bool>;

    for (var list in habitsByDate.values) {
      final toRemove = list.where((h) => h.uniqueHabitId == uniqueHabitId).toList();
      for (var habit in toRemove) {
        list.remove(habit);
        remaining.remove(habit.id);
        durations.remove(habit.id);
        completion.remove(habit.id);
      }
    }

    await saveHabitsData(
      habitsByDate: habitsByDate,
      remainingSeconds: remaining,
      habitDurations: durations,
      habitCompletionStatus: completion,
    );
  }

  @override
  Future<void> updateHabitNameAndDuration(
    String uniqueHabitId, {
    required String name,
    required int durationMinutes,
    required int durationSeconds,
  }) async {
    final data = await loadHabitsData();
    final habitsByDate = data['habitsByDate'] as Map<String, List<Habit>>;
    final remaining = data['remainingSeconds'] as Map<String, int>;
    final durations = data['habitDurations'] as Map<String, int>;
    final completion = data['habitCompletionStatus'] as Map<String, bool>;

    for (var list in habitsByDate.values) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].uniqueHabitId == uniqueHabitId) {
          final isCompleted = completion[list[i].id] ?? false;
          list[i] = list[i].copyWith(
            name: name,
            durationMinutes: durationMinutes,
          );
          durations[list[i].id] = durationSeconds;
          if (!isCompleted) {
            remaining[list[i].id] = durationSeconds;
          }
        }
      }
    }

    await saveHabitsData(
      habitsByDate: habitsByDate,
      remainingSeconds: remaining,
      habitDurations: durations,
      habitCompletionStatus: completion,
    );
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
