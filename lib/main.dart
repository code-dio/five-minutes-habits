import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/habit.dart';
import 'services/habit_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Five Minute Habits',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF00704A), // Starbucks Green
          secondary: const Color(0xFF1C7549), // Accent Green
          tertiary: const Color(0xFF35855D), // Light Green
          surface: Colors.white,
          background: const Color(0xFFFAFAFA), // Softer background
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
          onError: Colors.white,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF00704A),
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00704A), width: 2),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Store habits per date: Map<date (normalized to day), List<Habit>>
  final Map<String, List<Habit>> _habitsByDate = {};
  final Map<String, TimerController> _timerControllers = {};
  final Map<String, int> _remainingSeconds = {};
  final Map<String, int> _habitDurations =
      {}; // Store duration in seconds for each habit
  final Map<String, bool> _habitCompletionStatus =
      {}; // Track completion status for each habit
  DateTime _selectedDate = DateTime.now();

  // Helper to normalize date to day (remove time component)
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  // Get habits for selected date
  List<Habit> get _currentHabits {
    final key = _dateKey(_selectedDate);
    return _habitsByDate[key] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  @override
  void dispose() {
    // Save habits before disposing
    _saveHabits();
    // Dispose all timers
    for (var controller in _timerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Load habits from local storage
  Future<void> _loadHabits() async {
    try {
      final data = await HabitStorage.loadHabitsData();

      setState(() {
        _habitsByDate.clear();
        _remainingSeconds.clear();
        _habitDurations.clear();
        _habitCompletionStatus.clear();
        _timerControllers.clear();

        // Load habits by date
        final habitsByDate = data['habitsByDate'] as Map<String, List<Habit>>;
        _habitsByDate.addAll(habitsByDate);

        // Load remaining seconds
        final remainingSeconds = data['remainingSeconds'] as Map<String, int>;
        _remainingSeconds.addAll(remainingSeconds);

        // Load habit durations
        final habitDurations = data['habitDurations'] as Map<String, int>;
        _habitDurations.addAll(habitDurations);

        // Load completion status
        final habitCompletionStatus =
            data['habitCompletionStatus'] as Map<String, bool>;
        _habitCompletionStatus.addAll(habitCompletionStatus);

        // Initialize timer controllers for all habits
        for (var habits in _habitsByDate.values) {
          for (var habit in habits) {
            if (!_timerControllers.containsKey(habit.id)) {
              _timerControllers[habit.id] = TimerController();
            }
          }
        }
      });
    } catch (e) {
      // If loading fails, start with empty data
      debugPrint('Error loading habits: $e');
    }
  }

  // Save habits to local storage
  Future<void> _saveHabits() async {
    try {
      await HabitStorage.saveHabitsData(
        habitsByDate: _habitsByDate,
        remainingSeconds: _remainingSeconds,
        habitDurations: _habitDurations,
        habitCompletionStatus: _habitCompletionStatus,
      );
    } catch (e) {
      debugPrint('Error saving habits: $e');
    }
  }

  void _addHabit(String name, int durationMinutes) {
    if (name.trim().isEmpty) return;

    final creationTime = DateTime.now().millisecondsSinceEpoch;
    final durationSeconds = durationMinutes * 60;
    // Generate unique habit ID that will be shared across all instances
    final uniqueHabitId = '${name.trim()}-$creationTime';

    setState(() {
      // Add habit to all days from the selected date onwards (next 365 days)
      for (int i = 0; i < 365; i++) {
        final targetDate = _selectedDate.add(Duration(days: i));
        final dateKey = _dateKey(targetDate);

        final habit = Habit(
          id: '$dateKey-${name.trim()}-$creationTime-$i',
          uniqueHabitId: uniqueHabitId,
          name: name.trim(),
          createdAt: DateTime.now(),
          durationMinutes: durationMinutes,
          date: targetDate,
        );

        _habitsByDate.putIfAbsent(dateKey, () => []).add(habit);
        _remainingSeconds[habit.id] = durationSeconds;
        _habitDurations[habit.id] = durationSeconds;
        _timerControllers[habit.id] = TimerController();
        _habitCompletionStatus[habit.id] = false; // Initially not completed
      }
    });
    _saveHabits();
  }

  void _reorderHabits(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final habits = _currentHabits;
      final habit = habits.removeAt(oldIndex);
      habits.insert(newIndex, habit);
    });
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final day = date.day;
    final year = date.year;

    return '$weekday, $month $day, $year';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getWeekdayAbbreviation(int weekday) {
    const abbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbreviations[weekday - 1];
  }

  void _showAddHabitDialog() {
    final TextEditingController nameController = TextEditingController();
    int selectedDuration = 5; // Default to 5 minutes

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF00704A), Color(0xFF1C7549)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add New Habit',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                hintText: 'Enter habit name',
                                labelText: 'Habit Name',
                                prefixIcon: const Icon(Icons.fitness_center),
                              ),
                              autofocus: true,
                              onSubmitted: (_) {
                                if (nameController.text.trim().isNotEmpty) {
                                  _addHabit(
                                    nameController.text.trim(),
                                    selectedDuration,
                                  );
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Duration:',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: selectedDuration,
                              decoration: const InputDecoration(
                                labelText: 'Select Duration',
                                prefixIcon: Icon(Icons.timer),
                              ),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: 0,
                                  child: Text('Immed.'),
                                ),
                                ...([1, 2, 3, 4, 5].map((minutes) {
                                  return DropdownMenuItem<int>(
                                    value: minutes,
                                    child: Text(
                                      '$minutes minute${minutes > 1 ? 's' : ''}',
                                    ),
                                  );
                                })),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedDuration = value;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Actions
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00704A), Color(0xFF1C7549)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () {
                                if (nameController.text.trim().isNotEmpty) {
                                  _addHabit(
                                    nameController.text.trim(),
                                    selectedDuration,
                                  );
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Add',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCalendarDialog() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    ).then((selectedDate) {
      if (selectedDate != null) {
        setState(() {
          _selectedDate = selectedDate;
        });
      }
    });
  }

  void _showHabitStats(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => HabitStatsScreen(
              habit: habit,
              habitsByDate: _habitsByDate,
              habitCompletionStatus: _habitCompletionStatus,
              dateKey: _dateKey,
              onDateSelected: (DateTime selectedDate) {
                // Navigate back and update the selected date
                Navigator.pop(context);
                setState(() {
                  _selectedDate = selectedDate;
                });
              },
            ),
      ),
    );
  }

  void _showHabitOptionsDialog(
    String habitId,
    String habitName,
    int currentDuration,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00704A), Color(0xFF1C7549)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Edit',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showModifyHabitDialog(habitId, habitName, currentDuration);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete, color: Colors.red[700], size: 20),
                  ),
                  title: Text(
                    'Delete',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteHabit(habitId, habitName);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteHabit(String id) {
    setState(() {
      // Find the original habit to get its unique habit ID
      Habit? originalHabit;
      for (var entry in _habitsByDate.entries) {
        try {
          originalHabit = entry.value.firstWhere((habit) => habit.id == id);
          break;
        } catch (e) {
          continue;
        }
      }

      if (originalHabit == null) return;

      final uniqueHabitId = originalHabit.uniqueHabitId;

      // Collect all habit IDs to clean up
      final idsToRemove = <String>[];

      // Remove all habits with the same unique habit ID from all dates
      for (var entry in _habitsByDate.entries) {
        final habits = entry.value;
        habits.removeWhere((habit) {
          if (habit.uniqueHabitId == uniqueHabitId) {
            idsToRemove.add(habit.id);
            return true;
          }
          return false;
        });
      }

      // Clean up all related data for all matching habit IDs
      for (var habitId in idsToRemove) {
        _timerControllers[habitId]?.dispose();
        _timerControllers.remove(habitId);
        _remainingSeconds.remove(habitId);
        _habitDurations.remove(habitId);
        _habitCompletionStatus.remove(habitId);
      }
    });
    _saveHabits();
  }

  void _confirmDeleteHabit(String id, String habitName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red[700],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Delete Habit',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Are you sure you want to delete "$habitName"?\n\n'
                    'Warning: This will remove the habit from all dates and delete all of its history.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deleteHabit(id);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _modifyHabit(String id, String newName, int newDurationMinutes) {
    setState(() {
      final newDurationSeconds = newDurationMinutes * 60;

      // Find the original habit
      Habit? originalHabit;
      for (var entry in _habitsByDate.entries) {
        try {
          originalHabit = entry.value.firstWhere((habit) => habit.id == id);
          break;
        } catch (e) {
          continue;
        }
      }

      if (originalHabit == null) return;

      final uniqueHabitId = originalHabit.uniqueHabitId;

      // Update all habits with the same unique habit ID across all dates
      for (var entry in _habitsByDate.entries) {
        final habits = entry.value;
        for (int i = 0; i < habits.length; i++) {
          final habit = habits[i];
          // Update habits that match the unique habit ID
          if (habit.uniqueHabitId == uniqueHabitId) {
            // Update the habit's name and duration
            final updatedHabit = Habit(
              id: habit.id, // Keep the same ID
              uniqueHabitId:
                  habit.uniqueHabitId, // Keep the same unique habit ID
              name: newName,
              createdAt: habit.createdAt,
              durationMinutes: newDurationMinutes,
              date: habit.date,
            );

            // Update duration and remaining seconds if not completed
            if (!(_habitCompletionStatus[habit.id] ?? false)) {
              _habitDurations[habit.id] = newDurationSeconds;
              _remainingSeconds[habit.id] = newDurationSeconds;
            }

            habits[i] = updatedHabit;
          }
        }
      }
    });
    _saveHabits();
  }

  void _showModifyHabitDialog(
    String habitId,
    String currentName,
    int currentDuration,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    int selectedDuration = currentDuration;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF00704A), Color(0xFF1C7549)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Edit Habit',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                hintText: 'Enter habit name',
                                labelText: 'Habit Name',
                                prefixIcon: Icon(Icons.fitness_center),
                              ),
                              autofocus: true,
                              onSubmitted: (_) {
                                if (nameController.text.trim().isNotEmpty) {
                                  _modifyHabit(
                                    habitId,
                                    nameController.text.trim(),
                                    selectedDuration,
                                  );
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Duration:',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: selectedDuration,
                              decoration: const InputDecoration(
                                labelText: 'Select Duration',
                                prefixIcon: Icon(Icons.timer),
                              ),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: 0,
                                  child: Text('Immed.'),
                                ),
                                ...([1, 2, 3, 4, 5].map((minutes) {
                                  return DropdownMenuItem<int>(
                                    value: minutes,
                                    child: Text(
                                      '$minutes minute${minutes > 1 ? 's' : ''}',
                                    ),
                                  );
                                })),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedDuration = value;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Actions
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00704A), Color(0xFF1C7549)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () {
                                if (nameController.text.trim().isNotEmpty) {
                                  _modifyHabit(
                                    habitId,
                                    nameController.text.trim(),
                                    selectedDuration,
                                  );
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Save',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00704A),
                const Color(0xFF1C7549),
                const Color(0xFF35855D),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            title: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
              },
              child: Text(
                'Five Minute Habits',
                style: GoogleFonts.dancingScript(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            elevation: 0,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _showCalendarDialog,
                  tooltip: 'Select Date',
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.background, Colors.white],
          ),
        ),
        child: _buildHabitsTab(),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00704A), Color(0xFF1C7549)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00704A).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddHabitDialog,
          tooltip: 'Add Habit',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildHabitsTab() {
    return Column(
      children: [
        // Date selector - always visible, horizontally scrollable (7 days visible)
        Container(
          height: 90,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white.withOpacity(0.95)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Show 7 days with selected date in the center (3 before, selected, 3 after)
              final today = DateTime.now();

              return Row(
                children: List.generate(7, (index) {
                  // Show 3 days before selected date to 3 days after (selected date in center at index 3)
                  final date = _selectedDate.subtract(
                    Duration(days: 3 - index),
                  );
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isToday = _isSameDay(date, today);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          gradient:
                              isSelected
                                  ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF00704A),
                                      const Color(0xFF1C7549),
                                    ],
                                  )
                                  : null,
                          color:
                              isSelected
                                  ? null
                                  : isToday && !isSelected
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : isSelected
                                    ? Colors.transparent
                                    : Colors.grey[200]!,
                            width:
                                isToday
                                    ? 2.5
                                    : isSelected
                                    ? 0
                                    : 1,
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00704A,
                                      ).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getWeekdayAbbreviation(date.weekday),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${date.day}',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        // Habit list or empty state
        Expanded(
          child:
              _currentHabits.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF00704A).withOpacity(0.1),
                                const Color(0xFF1C7549).withOpacity(0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.fitness_center,
                            size: 80,
                            color: const Color(0xFF00704A).withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No habits yet',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add a habit',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                  : ReorderableListView(
                    padding: const EdgeInsets.all(8),
                    onReorder: _reorderHabits,
                    children: [
                      for (
                        int index = 0;
                        index < _currentHabits.length;
                        index++
                      )
                        HabitCard(
                          key: ValueKey(_currentHabits[index].id),
                          habit: _currentHabits[index],
                          timerController:
                              _timerControllers[_currentHabits[index].id]!,
                          remainingSeconds:
                              _remainingSeconds[_currentHabits[index].id]!,
                          totalDuration:
                              _habitDurations[_currentHabits[index].id]!,
                          isCompleted:
                              _habitCompletionStatus[_currentHabits[index]
                                  .id] ??
                              false,
                          onTimeUpdate: (seconds) {
                            setState(() {
                              _remainingSeconds[_currentHabits[index].id] =
                                  seconds;
                            });
                          },
                          onCompletionChanged: (isCompleted) {
                            setState(() {
                              _habitCompletionStatus[_currentHabits[index].id] =
                                  isCompleted;
                            });
                            _saveHabits();
                          },
                          onTap: () => _showHabitStats(_currentHabits[index]),
                          onLongPress:
                              () => _showHabitOptionsDialog(
                                _currentHabits[index].id,
                                _currentHabits[index].name,
                                _currentHabits[index].durationMinutes,
                              ),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    // Calculate statistics
    final totalDays = _habitsByDate.length;
    final totalHabits = _habitsByDate.values.expand((habits) => habits).length;

    // Get recent 7 days of data
    final today = DateTime.now();
    final recentDays = List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      final dateKey = _dateKey(date);
      final habits = _habitsByDate[dateKey] ?? [];
      final completedCount =
          habits
              .where((habit) => _habitCompletionStatus[habit.id] == true)
              .length;
      return {
        'date': date,
        'habits': habits,
        'totalCount': habits.length,
        'completedCount': completedCount,
      };
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Days',
                  totalDays.toString(),
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Habits',
                  totalHabits.toString(),
                  Icons.fitness_center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent 7 Days
          Text(
            'Recent 7 Days',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: recentDays.length,
              itemBuilder: (context, index) {
                final dayData = recentDays[index];
                final date = dayData['date'] as DateTime;
                final habits = dayData['habits'] as List<Habit>;
                final totalCount = dayData['totalCount'] as int;
                final completedCount = dayData['completedCount'] as int;
                final isToday = _isSameDay(date, today);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                            isToday
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getWeekdayAbbreviation(date.weekday),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  isToday
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  isToday
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      _formatDateForStatus(date),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        totalCount > 0
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$completedCount/$totalCount completed'),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value:
                                      totalCount > 0
                                          ? completedCount / totalCount
                                          : 0,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  children:
                                      habits.map((habit) {
                                        final isCompleted =
                                            _habitCompletionStatus[habit.id] ==
                                            true;
                                        return Chip(
                                          label: Text(
                                            habit.name,
                                            style: TextStyle(
                                              fontSize: 10,
                                              decoration:
                                                  isCompleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                            ),
                                          ),
                                          backgroundColor:
                                              isCompleted
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.2)
                                                  : Colors.grey[200],
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                ),
                              ],
                            )
                            : const Text('No habits'),
                    trailing:
                        totalCount > 0
                            ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  radius: 12,
                                  child: Text(
                                    '$completedCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(totalCount > 0 ? (completedCount / totalCount * 100).round() : 0)}%',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            )
                            : Icon(
                              Icons.remove_circle_outline,
                              color: Colors.grey[400],
                            ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateForStatus(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class TimerController {
  void dispose() {}
}

class HabitCard extends StatefulWidget {
  final Habit habit;
  final TimerController timerController;
  final int remainingSeconds;
  final int totalDuration;
  final bool isCompleted;
  final Function(int) onTimeUpdate;
  final Function(bool) onCompletionChanged;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HabitCard({
    super.key,
    required this.habit,
    required this.timerController,
    required this.remainingSeconds,
    required this.totalDuration,
    required this.isCompleted,
    required this.onTimeUpdate,
    required this.onCompletionChanged,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  bool _isRunning = false;
  late bool _isCompleted;
  late int _remainingSeconds;
  late int _totalDuration;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingSeconds;
    _totalDuration = widget.totalDuration;
    _isCompleted = widget.isCompleted;
  }

  @override
  void didUpdateWidget(HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != oldWidget.remainingSeconds) {
      _remainingSeconds = widget.remainingSeconds;
    }
    if (widget.totalDuration != oldWidget.totalDuration) {
      _totalDuration = widget.totalDuration;
    }
    if (widget.isCompleted != oldWidget.isCompleted) {
      _isCompleted = widget.isCompleted;
    }
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _isCompleted = false;
    });

    // If duration is 0 (immediate), complete immediately
    if (_totalDuration == 0) {
      setState(() {
        _remainingSeconds = 0;
        _isRunning = false;
        _isCompleted = true;
      });
      widget.onTimeUpdate(0);
      widget.onCompletionChanged(true);
      _showCompletionDialog();
    } else {
      _tick();
    }
  }

  void _stopTimer() {
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalDuration;
      _isCompleted = false;
    });
    // Update parent state with reset values
    widget.onTimeUpdate(_totalDuration);
    widget.onCompletionChanged(false);
  }

  void _tick() {
    if (!_isRunning) return;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRunning) return;

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          widget.onTimeUpdate(_remainingSeconds);

          if (_remainingSeconds == 0) {
            _isRunning = false;
            _isCompleted = true;
            widget.onCompletionChanged(true);
            _showCompletionDialog();
          } else {
            _tick();
          }
        } else {
          _isRunning = false;
        }
      });
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C7549), Color(0xFF35855D)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1C7549).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Habit Complete! 🎉',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Great job completing "${widget.habit.name}"!',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C7549),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(int seconds) {
    if (_totalDuration == 0) {
      // For immediate habits, show "Immed." when not done, "Done" when completed
      return _isCompleted ? 'Done' : 'Immed.';
    }
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    if (_totalDuration == 0) {
      return _isCompleted ? 1.0 : 0.0;
    }
    return 1.0 - (_remainingSeconds / _totalDuration);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();
    final isCompleted = _isCompleted;
    final isRunning = _isRunning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient:
            isCompleted
                ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1C7549).withOpacity(0.15),
                    const Color(0xFF35855D).withOpacity(0.1),
                  ],
                )
                : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.white.withOpacity(0.95)],
                ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isCompleted
                  ? const Color(0xFF1C7549).withOpacity(0.3)
                  : Colors.grey[200]!,
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isCompleted
                    ? const Color(0xFF1C7549).withOpacity(0.2)
                    : Colors.black.withOpacity(0.06),
            blurRadius: isCompleted ? 12 : 8,
            offset: Offset(0, isCompleted ? 6 : 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Progress gradient fill
              if (progress > 0 && !isCompleted)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF00704A).withOpacity(0.2),
                              const Color(0xFF1C7549).withOpacity(0.15),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Habit name (title)
                    Expanded(
                      child: Row(
                        children: [
                          if (isCompleted)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1C7549),
                                    Color(0xFF35855D),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              widget.habit.name,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration:
                                    isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                color:
                                    isCompleted
                                        ? Colors.grey[600]
                                        : Colors.black87,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Timer controls
                        if (isCompleted)
                          // Cancel/Undo button for completed habits
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.undo, size: 18),
                              onPressed: _resetTimer,
                              tooltip: 'Cancel',
                              color: Colors.grey[700],
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          )
                        else if (!isRunning &&
                            _remainingSeconds == _totalDuration)
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00704A), Color(0xFF1C7549)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00704A,
                                  ).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.play_arrow, size: 20),
                              onPressed: _startTimer,
                              tooltip: 'Start',
                              color: Colors.white,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          )
                        else if (isRunning)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.pause, size: 18),
                              onPressed: _stopTimer,
                              tooltip: 'Pause',
                              color: Colors.orange[700],
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00704A),
                                      Color(0xFF1C7549),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  onPressed: _startTimer,
                                  tooltip: 'Resume',
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  onPressed: _resetTimer,
                                  tooltip: 'Reset',
                                  color: Colors.grey[700],
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Time display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isCompleted
                                ? const Color(0xFF1C7549).withOpacity(0.1)
                                : isRunning && _remainingSeconds <= 60
                                ? Colors.red[50]
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatTime(_remainingSeconds),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              _totalDuration == 0 && !isCompleted
                                  ? Colors.black87
                                  : _remainingSeconds <= 60 && isRunning
                                  ? Colors.red[700]
                                  : isCompleted
                                  ? const Color(0xFF1C7549)
                                  : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HabitStatsScreen extends StatefulWidget {
  final Habit habit;
  final Map<String, List<Habit>> habitsByDate;
  final Map<String, bool> habitCompletionStatus;
  final String Function(DateTime) dateKey;
  final Function(DateTime)? onDateSelected;

  const HabitStatsScreen({
    super.key,
    required this.habit,
    required this.habitsByDate,
    required this.habitCompletionStatus,
    required this.dateKey,
    this.onDateSelected,
  });

  @override
  State<HabitStatsScreen> createState() => _HabitStatsScreenState();
}

class _HabitStatsScreenState extends State<HabitStatsScreen> {
  DateTime _selectedMonth = DateTime.now();

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getWeekdayAbbreviation(int weekday) {
    const abbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbreviations[weekday - 1];
  }

  List<Map<String, dynamic>> _getWeeklyStats() {
    final today = DateTime.now();
    final weekData = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateKey = widget.dateKey(date);
      final habits = widget.habitsByDate[dateKey] ?? [];

      // Find habits with the same unique habit ID (this habit instance)
      final habitInstances =
          habits
              .where((h) => h.uniqueHabitId == widget.habit.uniqueHabitId)
              .toList();
      int completedCount = 0;

      for (var h in habitInstances) {
        if (widget.habitCompletionStatus[h.id] == true) {
          completedCount++;
        }
      }

      weekData.add({
        'date': date,
        'completed': completedCount > 0,
        'total': habitInstances.length,
      });
    }

    return weekData;
  }

  List<Map<String, dynamic>> _getMonthlyStats() {
    final today = DateTime.now();
    final monthData = <Map<String, dynamic>>[];
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );

    // Get the weekday of the first day (1 = Monday, 7 = Sunday)
    // Adjust to start from Monday (0 = Monday, 6 = Sunday)
    int firstWeekday = firstDayOfMonth.weekday - 1;

    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstWeekday; i++) {
      monthData.add({
        'date': null,
        'completed': false,
        'total': 0,
        'isPlaceholder': true,
      });
    }

    // Add all days of the month
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, i);
      final dateKey = widget.dateKey(date);
      final habits = widget.habitsByDate[dateKey] ?? [];

      final habitInstances =
          habits.where((h) => h.name == widget.habit.name).toList();
      int completedCount = 0;

      for (var h in habitInstances) {
        if (widget.habitCompletionStatus[h.id] == true) {
          completedCount++;
        }
      }

      monthData.add({
        'date': date,
        'completed': completedCount > 0,
        'total': habitInstances.length,
        'isPlaceholder': false,
        'isFuture': date.isAfter(today),
      });
    }

    return monthData;
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showMonthYearPicker() {
    final currentYear = _selectedMonth.year;
    final currentMonth = _selectedMonth.month;
    int selectedYear = currentYear;
    int selectedMonth = currentMonth;

    final now = DateTime.now();
    final years =
        List.generate(
          now.year - 1999,
          (index) => 2000 + index,
        ).reversed.toList();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Month and Year'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month dropdown
                    DropdownButtonFormField<int>(
                      value: selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(months[index]),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedMonth = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Year dropdown
                    DropdownButtonFormField<int>(
                      value: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          years.map((year) {
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedYear = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(selectedYear, selectedMonth, 1);
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklyStats = _getWeeklyStats();
    final monthlyStats = _getMonthlyStats();
    final weeklyCompleted =
        weeklyStats.where((d) => d['completed'] == true).length;
    // Only count days up to today for monthly stats
    final monthlyCompleted =
        monthlyStats
            .where(
              (d) =>
                  d['completed'] == true &&
                  (d['isFuture'] as bool? ?? false) == false &&
                  (d['isPlaceholder'] as bool? ?? false) == false,
            )
            .length;
    final weeklyTotal = weeklyStats.length;
    // Only count days up to today for monthly total
    final monthlyTotal =
        monthlyStats
            .where(
              (d) =>
                  (d['isFuture'] as bool? ?? false) == false &&
                  (d['isPlaceholder'] as bool? ?? false) == false,
            )
            .length;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00704A),
                const Color(0xFF1C7549),
                const Color(0xFF35855D),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            title: GestureDetector(
              onTap: () {
                // Navigate back to today's habit list view
                if (widget.onDateSelected != null) {
                  widget.onDateSelected!(DateTime.now());
                } else {
                  Navigator.pop(context);
                }
              },
              child: Text(
                widget.habit.name,
                style: GoogleFonts.dancingScript(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            elevation: 0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Tracking
            Text(
              'Weekly Tracking',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.white.withOpacity(0.95)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Weekday headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children:
                        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                            .map(
                              (day) => Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 8),
                  // Weekly calendar grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children:
                        weeklyStats.map((day) {
                          final isCompleted = day['completed'] as bool;
                          final date = day['date'] as DateTime;
                          final isToday = _isSameDay(date, DateTime.now());

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (widget.onDateSelected != null) {
                                      widget.onDateSelected!(date);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color:
                                          isCompleted
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color:
                                            isToday
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                                : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                _getWeekdayAbbreviation(
                                                  date.weekday,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isCompleted
                                                          ? Colors.white
                                                          : Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${date.day}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isCompleted
                                                          ? Colors.white
                                                          : Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isCompleted)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monthly Tracking
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Tracking',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // Month navigation
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                              1,
                            );
                          });
                        },
                        tooltip: 'Previous month',
                      ),
                      GestureDetector(
                        onTap: _showMonthYearPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getMonthName(_selectedMonth),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            );
                          });
                        },
                        tooltip: 'Next month',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.white.withOpacity(0.95)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Weekday headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children:
                        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                            .map(
                              (day) => Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 8),
                  // Calendar grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1,
                        ),
                    itemCount: monthlyStats.length,
                    itemBuilder: (context, index) {
                      final day = monthlyStats[index];
                      final isPlaceholder =
                          day['isPlaceholder'] as bool? ?? false;
                      final date = day['date'] as DateTime?;
                      final isCompleted = day['completed'] as bool;
                      final isFuture = day['isFuture'] as bool? ?? false;
                      final isToday =
                          date != null && _isSameDay(date, DateTime.now());

                      if (isPlaceholder || date == null) {
                        return const SizedBox.shrink();
                      }

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Only allow tapping on past or today dates
                            if (!isFuture && widget.onDateSelected != null) {
                              widget.onDateSelected!(date);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isCompleted
                                      ? Theme.of(context).colorScheme.primary
                                      : isFuture
                                      ? Colors.grey[100]
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color:
                                    isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isCompleted
                                              ? Colors.white
                                              : isFuture
                                              ? Colors.grey[400]
                                              : Colors.grey[700],
                                    ),
                                  ),
                                ),
                                if (isCompleted)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Weekly',
                    '$weeklyCompleted/$weeklyTotal',
                    Icons.calendar_view_week,
                    weeklyTotal > 0 ? weeklyCompleted / weeklyTotal : 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Monthly',
                    '$monthlyCompleted/$monthlyTotal',
                    Icons.calendar_month,
                    monthlyTotal > 0 ? monthlyCompleted / monthlyTotal : 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    double progress,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.white.withOpacity(0.95)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00704A), Color(0xFF1C7549)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00704A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF00704A),
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
