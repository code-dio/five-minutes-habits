import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/habit.dart';

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
          background: const Color(0xFFF5F5F5), // Light gray background
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
          onError: Colors.white,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00704A), // Starbucks Green
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00704A), // Starbucks Green
          foregroundColor: Colors.white,
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
  void dispose() {
    // Dispose all timers
    for (var controller in _timerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addHabit(String name, int durationMinutes) {
    if (name.trim().isEmpty) return;

    final creationTime = DateTime.now().millisecondsSinceEpoch;
    final durationSeconds = durationMinutes * 60;

    setState(() {
      // Add habit to all days from the selected date onwards (next 365 days)
      for (int i = 0; i < 365; i++) {
        final targetDate = _selectedDate.add(Duration(days: i));
        final dateKey = _dateKey(targetDate);

        final habit = Habit(
          id: '$dateKey-${name.trim()}-$creationTime-$i',
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
            return AlertDialog(
              title: const Text('Add New Habit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter habit name',
                        border: OutlineInputBorder(),
                        labelText: 'Habit Name',
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
                    const SizedBox(height: 20),
                    const Text(
                      'Duration:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedDuration,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Select Duration',
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      _addHabit(nameController.text.trim(), selectedDuration);
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
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
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'Five Minute Habits',
          style: GoogleFonts.dancingScript(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _showCalendarDialog,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
        margin: const EdgeInsets.only(bottom: 8),
        child: _buildHabitsTab(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHabitDialog,
        tooltip: 'Add Habit',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHabitsTab() {
    return Column(
      children: [
        // Date selector - always visible, horizontally scrollable (7 days visible)
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Show today and previous 6 days (7 days total)
              final today = DateTime.now();

              return Row(
                children: List.generate(7, (index) {
                  // Show 6 days ago to today (index 0 = 6 days ago, index 6 = today)
                  final date = today.subtract(Duration(days: 6 - index));
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isToday = _isSameDay(date, today);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : isToday && !isSelected
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[300]!,
                            width: isToday ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getWeekdayAbbreviation(date.weekday),
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
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
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No habits yet',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add a habit',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
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
                          },
                          onTap: () => _showHabitStats(_currentHabits[index]),
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Habit Complete! 🎉'),
          content: Text('Great job completing "${widget.habit.name}"!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
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
    final fillColor =
        _remainingSeconds > 0
            ? const Color(0xFF00704A).withOpacity(
              0.15,
            ) // Starbucks Green with opacity
            : const Color(
              0xFF1C7549,
            ).withOpacity(0.2); // Accent Green with opacity

    return Card(
      margin: const EdgeInsets.only(left: 8, right: 8, top: 1, bottom: 2),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          children: [
            // Color fill based on progress
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(color: fillColor),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Habit name (title)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.habit.name,
                        textAlign: TextAlign.left,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration:
                              _isCompleted ? TextDecoration.lineThrough : null,
                          color:
                              _isCompleted
                                  ? Colors.grey
                                  : Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                        ),
                      ),
                    ),
                  ),
                  // Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timer controls
                      if (_isCompleted)
                        // Cancel/Undo button for completed habits
                        IconButton(
                          icon: const Icon(Icons.undo, size: 18),
                          onPressed: _resetTimer,
                          tooltip: 'Cancel',
                          color: Theme.of(context).colorScheme.secondary,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        )
                      else if (!_isRunning &&
                          _remainingSeconds == _totalDuration)
                        IconButton(
                          icon: const Icon(Icons.play_arrow, size: 18),
                          onPressed: _startTimer,
                          tooltip: 'Start',
                          color: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        )
                      else if (_isRunning)
                        IconButton(
                          icon: const Icon(Icons.pause, size: 18),
                          onPressed: _stopTimer,
                          tooltip: 'Pause',
                          color: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow, size: 18),
                              onPressed: _startTimer,
                              tooltip: 'Resume',
                              color: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: _resetTimer,
                              tooltip: 'Reset',
                              color: Theme.of(context).colorScheme.secondary,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Time display
                  Text(
                    _formatTime(_remainingSeconds),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          _totalDuration == 0 && !_isCompleted
                              ? Colors
                                  .black87 // "Immediate" in black
                              : _remainingSeconds <= 60 && _isRunning
                              ? Colors.red
                              : _remainingSeconds == 0
                              ? Colors.green
                              : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HabitStatsScreen extends StatelessWidget {
  final Habit habit;
  final Map<String, List<Habit>> habitsByDate;
  final Map<String, bool> habitCompletionStatus;
  final String Function(DateTime) dateKey;

  const HabitStatsScreen({
    super.key,
    required this.habit,
    required this.habitsByDate,
    required this.habitCompletionStatus,
    required this.dateKey,
  });

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
      final dateKey = this.dateKey(date);
      final habits = habitsByDate[dateKey] ?? [];

      // Find habits with the same name (this habit instance)
      final habitInstances = habits.where((h) => h.name == habit.name).toList();
      int completedCount = 0;

      for (var h in habitInstances) {
        if (habitCompletionStatus[h.id] == true) {
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
    final firstDayOfMonth = DateTime(today.year, today.month, 1);
    final lastDayOfMonth = DateTime(today.year, today.month + 1, 0);

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
      final date = DateTime(today.year, today.month, i);
      final dateKey = this.dateKey(date);
      final habits = habitsByDate[dateKey] ?? [];

      final habitInstances = habits.where((h) => h.name == habit.name).toList();
      int completedCount = 0;

      for (var h in habitInstances) {
        if (habitCompletionStatus[h.id] == true) {
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          habit.name,
          style: GoogleFonts.dancingScript(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 2,
      ),
      body: SingleChildScrollView(
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
            const SizedBox(height: 24),

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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
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
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monthly Tracking
            Text(
              'Monthly Tracking',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
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

                      return Container(
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
                      );
                    },
                  ),
                ],
              ),
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
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
