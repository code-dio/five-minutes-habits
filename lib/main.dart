import 'package:flutter/material.dart';
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

    final habit = Habit(
      id: '${_dateKey(_selectedDate)}-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      createdAt: DateTime.now(),
      durationMinutes: durationMinutes,
      date: _selectedDate,
    );

    final durationSeconds = durationMinutes * 60;
    final dateKey = _dateKey(_selectedDate);

    setState(() {
      _habitsByDate.putIfAbsent(dateKey, () => []).add(habit);
      _remainingSeconds[habit.id] = durationSeconds;
      _habitDurations[habit.id] = durationSeconds;
      _timerControllers[habit.id] = TimerController();
    });
  }

  void _deleteHabit(String id) {
    setState(() {
      // Find and remove habit from the appropriate date
      for (var habits in _habitsByDate.values) {
        habits.removeWhere((habit) => habit.id == id);
      }
      _timerControllers[id]?.dispose();
      _timerControllers.remove(id);
      _remainingSeconds.remove(id);
      _habitDurations.remove(id);
    });
  }

  void _confirmDeleteHabit(String id, String habitName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Habit'),
          content: Text('Are you sure you want to delete "$habitName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteHabit(id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Five Minute Habits'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _showCalendarDialog,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: Column(
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
                // Show 7 days with selected date in the middle (3 before, selected, 3 after)
                final today = DateTime.now();

                return Row(
                  children: List.generate(7, (index) {
                    final date = _selectedDate.subtract(
                      Duration(days: 3 - index),
                    ); // 3 days before to 3 days after selected date
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
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
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
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
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
                            onDelete:
                                () => _confirmDeleteHabit(
                                  _currentHabits[index].id,
                                  _currentHabits[index].name,
                                ),
                            onTimeUpdate: (seconds) {
                              setState(() {
                                _remainingSeconds[_currentHabits[index].id] =
                                    seconds;
                              });
                            },
                          ),
                      ],
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHabitDialog,
        tooltip: 'Add Habit',
        child: const Icon(Icons.add),
      ),
    );
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
  final VoidCallback onDelete;
  final Function(int) onTimeUpdate;

  const HabitCard({
    super.key,
    required this.habit,
    required this.timerController,
    required this.remainingSeconds,
    required this.totalDuration,
    required this.onDelete,
    required this.onTimeUpdate,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  bool _isRunning = false;
  bool _isCompleted = false;
  late int _remainingSeconds;
  late int _totalDuration;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingSeconds;
    _totalDuration = widget.totalDuration;
  }

  @override
  void didUpdateWidget(HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != oldWidget.remainingSeconds) {
      _remainingSeconds = widget.remainingSeconds;
      // Update completion state based on remaining seconds
      if (_remainingSeconds == 0 && _totalDuration > 0) {
        _isCompleted = true;
      } else if (_remainingSeconds == _totalDuration) {
        _isCompleted = false;
      }
    }
    if (widget.totalDuration != oldWidget.totalDuration) {
      _totalDuration = widget.totalDuration;
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
                // Habit name (title)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.habit.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration:
                            _isCompleted ? TextDecoration.lineThrough : null,
                        color:
                            _isCompleted
                                ? Colors.grey
                                : Theme.of(context).textTheme.titleLarge?.color,
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
                    else if (!_isRunning && _remainingSeconds == _totalDuration)
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: widget.onDelete,
                      tooltip: 'Delete',
                      color: Colors.red,
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
          ),
        ],
      ),
    );
  }
}
