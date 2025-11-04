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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
  final List<Habit> _habits = [];
  final Map<String, TimerController> _timerControllers = {};
  final Map<String, int> _remainingSeconds = {};
  final Map<String, int> _habitDurations =
      {}; // Store duration in seconds for each habit

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
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      createdAt: DateTime.now(),
      durationMinutes: durationMinutes,
    );

    final durationSeconds = durationMinutes * 60;

    setState(() {
      _habits.add(habit);
      _remainingSeconds[habit.id] = durationSeconds;
      _habitDurations[habit.id] = durationSeconds;
      _timerControllers[habit.id] = TimerController();
    });
  }

  void _deleteHabit(String id) {
    setState(() {
      _habits.removeWhere((habit) => habit.id == id);
      _timerControllers[id]?.dispose();
      _timerControllers.remove(id);
      _remainingSeconds.remove(id);
      _habitDurations.remove(id);
    });
  }

  void _reorderHabits(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final habit = _habits.removeAt(oldIndex);
      _habits.insert(newIndex, habit);
    });
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
                      items:
                          [1, 2, 3, 4, 5].map((minutes) {
                            return DropdownMenuItem<int>(
                              value: minutes,
                              child: Text(
                                '$minutes minute${minutes > 1 ? 's' : ''}',
                              ),
                            );
                          }).toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Five Minute Habits'),
        elevation: 2,
      ),
      body:
          _habits.isEmpty
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ReorderableListView(
                padding: const EdgeInsets.all(8),
                onReorder: _reorderHabits,
                children: [
                  for (int index = 0; index < _habits.length; index++)
                    HabitCard(
                      key: ValueKey(_habits[index].id),
                      habit: _habits[index],
                      timerController: _timerControllers[_habits[index].id]!,
                      remainingSeconds: _remainingSeconds[_habits[index].id]!,
                      totalDuration: _habitDurations[_habits[index].id]!,
                      onDelete: () => _deleteHabit(_habits[index].id),
                      onTimeUpdate: (seconds) {
                        setState(() {
                          _remainingSeconds[_habits[index].id] = seconds;
                        });
                      },
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
  bool _isExpanded = false;
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
    }
    if (widget.totalDuration != oldWidget.totalDuration) {
      _totalDuration = widget.totalDuration;
    }
    if (_remainingSeconds == 0) {
      _isCompleted = true;
    } else if (_remainingSeconds == _totalDuration) {
      _isCompleted = false;
    }
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _isCompleted = false;
    });

    _tick();
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
    widget.onTimeUpdate(_remainingSeconds);
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
            _isExpanded = false;
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
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    return 1.0 - (_remainingSeconds / _totalDuration);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.drag_handle, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.habit.name,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration:
                                  _isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                              color:
                                  _isCompleted
                                      ? Colors.grey
                                      : Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      // Stop propagation by handling delete separately
                      widget.onDelete();
                    },
                    color: Colors.red,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                // Horizontal progress bar
                Column(
                  children: [
                    // Time display
                    Text(
                      _formatTime(_remainingSeconds),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            _remainingSeconds <= 60 && _isRunning
                                ? Colors.red
                                : _remainingSeconds == 0
                                ? Colors.green
                                : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    LinearProgressIndicator(
                      value: _getProgress(),
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _remainingSeconds > 0
                            ? Colors.deepPurple
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Timer controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isRunning && _remainingSeconds == _totalDuration)
                      ElevatedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      )
                    else if (_isRunning)
                      ElevatedButton.icon(
                        onPressed: _stopTimer,
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _startTimer,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Resume'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _resetTimer,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
