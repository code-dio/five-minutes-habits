import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habit.dart';
import 'base_habit_storage.dart';

class FirestoreHabitStorage implements BaseHabitStorage {
  final String uid;

  FirestoreHabitStorage(this.uid);

  CollectionReference<Map<String, dynamic>> get _habitsRef =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('habits');

  @override
  Future<Map<String, dynamic>> loadHabitsData() async {
    final result = <String, dynamic>{
      'habitsByDate': <String, List<Habit>>{},
      'remainingSeconds': <String, int>{},
      'habitDurations': <String, int>{},
      'habitCompletionStatus': <String, bool>{},
      'isOffline': false,
    };

    QuerySnapshot<Map<String, dynamic>> snapshot;
    bool isOffline = false;

    try {
      snapshot = await _habitsRef.get().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          isOffline = true;
          return _habitsRef.get(const GetOptions(source: Source.cache));
        },
      );
    } catch (e) {
      isOffline = true;
      try {
        snapshot = await _habitsRef.get(const GetOptions(source: Source.cache));
      } catch (cacheError) {
        return result;
      }
    }

    final habitsByDate = <String, List<Habit>>{};
    final remainingSeconds = <String, int>{};
    final habitDurations = <String, int>{};
    final habitCompletionStatus = <String, bool>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final id = data['id'] as String;
      final habit = Habit(
        id: id,
        uniqueHabitId: data['uniqueHabitId'] as String,
        name: data['name'] as String,
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        durationMinutes: data['durationMinutes'] as int,
        date: (data['date'] as Timestamp).toDate(),
      );

      final dateKey = _dateKey(habit.date);
      habitsByDate.putIfAbsent(dateKey, () => []).add(habit);

      final durationSeconds = habit.durationMinutes * 60;
      habitDurations[id] = data['durationSeconds'] as int? ?? durationSeconds;
      remainingSeconds[id] = data['remainingSeconds'] as int? ?? durationSeconds;
      habitCompletionStatus[id] = data['isCompleted'] as bool? ?? false;
    }

    result['habitsByDate'] = habitsByDate;
    result['remainingSeconds'] = remainingSeconds;
    result['habitDurations'] = habitDurations;
    result['habitCompletionStatus'] = habitCompletionStatus;
    result['isOffline'] = isOffline;

    return result;
  }

  @override
  Future<void> saveHabitsData({
    required Map<String, List<Habit>> habitsByDate,
    required Map<String, int> remainingSeconds,
    required Map<String, int> habitDurations,
    required Map<String, bool> habitCompletionStatus,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final habits in habitsByDate.values) {
      for (final habit in habits) {
        final ref = _habitsRef.doc(habit.id);
        batch.set(ref, {
          'id': habit.id,
          'uniqueHabitId': habit.uniqueHabitId,
          'name': habit.name,
          'createdAt': Timestamp.fromDate(habit.createdAt),
          'durationMinutes': habit.durationMinutes,
          'date': Timestamp.fromDate(habit.date),
          'durationSeconds': habitDurations[habit.id] ?? habit.durationMinutes * 60,
          'remainingSeconds': remainingSeconds[habit.id] ?? habit.durationMinutes * 60,
          'isCompleted': habitCompletionStatus[habit.id] ?? false,
        });
      }
    }

    await batch.commit();
  }

  @override
  Future<void> upsertHabit(
    Habit habit, {
    required int durationSeconds,
    required int remainingSeconds,
    required bool isCompleted,
  }) async {
    await _habitsRef.doc(habit.id).set({
      'id': habit.id,
      'uniqueHabitId': habit.uniqueHabitId,
      'name': habit.name,
      'createdAt': Timestamp.fromDate(habit.createdAt),
      'durationMinutes': habit.durationMinutes,
      'date': Timestamp.fromDate(habit.date),
      'durationSeconds': durationSeconds,
      'remainingSeconds': remainingSeconds,
      'isCompleted': isCompleted,
    });
  }

  @override
  Future<void> updateHabitProgress(
    String habitId, {
    required int remainingSeconds,
    required bool isCompleted,
  }) async {
    await _habitsRef.doc(habitId).update({
      'remainingSeconds': remainingSeconds,
      'isCompleted': isCompleted,
    });
  }

  @override
  Future<void> deleteHabitsByUniqueId(String uniqueHabitId) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _habitsRef
          .where('uniqueHabitId', isEqualTo: uniqueHabitId)
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => _habitsRef
                .where('uniqueHabitId', isEqualTo: uniqueHabitId)
                .get(const GetOptions(source: Source.cache)),
          );
    } catch (e) {
      try {
        snapshot = await _habitsRef
            .where('uniqueHabitId', isEqualTo: uniqueHabitId)
            .get(const GetOptions(source: Source.cache));
      } catch (cacheError) {
        return;
      }
    }
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> updateHabitNameAndDuration(
    String uniqueHabitId, {
    required String name,
    required int durationMinutes,
    required int durationSeconds,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _habitsRef
          .where('uniqueHabitId', isEqualTo: uniqueHabitId)
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => _habitsRef
                .where('uniqueHabitId', isEqualTo: uniqueHabitId)
                .get(const GetOptions(source: Source.cache)),
          );
    } catch (e) {
      try {
        snapshot = await _habitsRef
            .where('uniqueHabitId', isEqualTo: uniqueHabitId)
            .get(const GetOptions(source: Source.cache));
      } catch (cacheError) {
        return;
      }
    }
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      final isCompleted = doc.data()['isCompleted'] as bool? ?? false;
      batch.update(doc.reference, {
        'name': name,
        'durationMinutes': durationMinutes,
        'durationSeconds': durationSeconds,
        if (!isCompleted) 'remainingSeconds': durationSeconds,
      });
    }
    await batch.commit();
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
