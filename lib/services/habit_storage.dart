import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

class HabitStorage {
  static const String _habitsByDateKey = 'habits_by_date';
  static const String _remainingSecondsKey = 'remaining_seconds';
  static const String _habitDurationsKey = 'habit_durations';
  static const String _habitCompletionStatusKey = 'habit_completion_status';

  // Save habits data to local storage
  static Future<void> saveHabitsData({
    required Map<String, List<Habit>> habitsByDate,
    required Map<String, int> remainingSeconds,
    required Map<String, int> habitDurations,
    required Map<String, bool> habitCompletionStatus,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Convert habitsByDate to JSON
    final habitsByDateJson = <String, dynamic>{};
    for (var entry in habitsByDate.entries) {
      habitsByDateJson[entry.key] =
          entry.value
              .map(
                (habit) => {
                  'id': habit.id,
                  'uniqueHabitId': habit.uniqueHabitId,
                  'name': habit.name,
                  'createdAt': habit.createdAt.toIso8601String(),
                  'durationMinutes': habit.durationMinutes,
                  'date': habit.date.toIso8601String(),
                },
              )
              .toList();
    }
    await prefs.setString(_habitsByDateKey, jsonEncode(habitsByDateJson));

    // Save remaining seconds
    await prefs.setString(_remainingSecondsKey, jsonEncode(remainingSeconds));

    // Save habit durations
    await prefs.setString(_habitDurationsKey, jsonEncode(habitDurations));

    // Save completion status
    final completionStatusJson = <String, bool>{};
    for (var entry in habitCompletionStatus.entries) {
      completionStatusJson[entry.key] = entry.value;
    }
    await prefs.setString(
      _habitCompletionStatusKey,
      jsonEncode(completionStatusJson),
    );
  }

  // Load habits data from local storage
  static Future<Map<String, dynamic>> loadHabitsData() async {
    final prefs = await SharedPreferences.getInstance();

    final result = <String, dynamic>{
      'habitsByDate': <String, List<Habit>>{},
      'remainingSeconds': <String, int>{},
      'habitDurations': <String, int>{},
      'habitCompletionStatus': <String, bool>{},
    };

    // Load habitsByDate
    final habitsByDateJsonString = prefs.getString(_habitsByDateKey);
    if (habitsByDateJsonString != null) {
      final habitsByDateJson =
          jsonDecode(habitsByDateJsonString) as Map<String, dynamic>;
      final habitsByDate = <String, List<Habit>>{};

      for (var entry in habitsByDateJson.entries) {
        final habitsList =
            (entry.value as List).map((habitJson) {
              final habitMap = habitJson as Map<String, dynamic>;
              final id = habitMap['id'] as String;
              return Habit(
                id: id,
                uniqueHabitId: (habitMap['uniqueHabitId'] as String?) ?? id,
                name: habitMap['name'] as String,
                createdAt: DateTime.parse(habitMap['createdAt'] as String),
                durationMinutes: habitMap['durationMinutes'] as int,
                date: DateTime.parse(habitMap['date'] as String),
              );
            }).toList();
        habitsByDate[entry.key] = habitsList;
      }
      result['habitsByDate'] = habitsByDate;
    }

    // Load remaining seconds
    final remainingSecondsJsonString = prefs.getString(_remainingSecondsKey);
    if (remainingSecondsJsonString != null) {
      final remainingSecondsJson =
          jsonDecode(remainingSecondsJsonString) as Map<String, dynamic>;
      final remainingSeconds = <String, int>{};
      for (var entry in remainingSecondsJson.entries) {
        remainingSeconds[entry.key] = entry.value as int;
      }
      result['remainingSeconds'] = remainingSeconds;
    }

    // Load habit durations
    final habitDurationsJsonString = prefs.getString(_habitDurationsKey);
    if (habitDurationsJsonString != null) {
      final habitDurationsJson =
          jsonDecode(habitDurationsJsonString) as Map<String, dynamic>;
      final habitDurations = <String, int>{};
      for (var entry in habitDurationsJson.entries) {
        habitDurations[entry.key] = entry.value as int;
      }
      result['habitDurations'] = habitDurations;
    }

    // Load completion status
    final habitCompletionStatusJsonString = prefs.getString(
      _habitCompletionStatusKey,
    );
    if (habitCompletionStatusJsonString != null) {
      final habitCompletionStatusJson =
          jsonDecode(habitCompletionStatusJsonString) as Map<String, dynamic>;
      final habitCompletionStatus = <String, bool>{};
      for (var entry in habitCompletionStatusJson.entries) {
        habitCompletionStatus[entry.key] = entry.value as bool;
      }
      result['habitCompletionStatus'] = habitCompletionStatus;
    }

    return result;
  }

  // Clear all stored habits data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_habitsByDateKey);
    await prefs.remove(_remainingSecondsKey);
    await prefs.remove(_habitDurationsKey);
    await prefs.remove(_habitCompletionStatusKey);
  }
}
