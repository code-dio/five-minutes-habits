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

  @override
  void dispose() {
    // Dispose all timers
    for (var controller in _timerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addHabit(String name) {
    if (name.trim().isEmpty) return;

    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );

    setState(() {
      _habits.add(habit);
      _remainingSeconds[habit.id] = 300; // 5 minutes = 300 seconds
      _timerControllers[habit.id] = TimerController();
    });
  }

  void _deleteHabit(String id) {
    setState(() {
      _habits.removeWhere((habit) => habit.id == id);
      _timerControllers[id]?.dispose();
      _timerControllers.remove(id);
      _remainingSeconds.remove(id);
    });
  }

  void _showAddHabitDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Habit'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter habit name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) {
              _addHabit(nameController.text);
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addHabit(nameController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
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
              : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _habits.length,
                itemBuilder: (context, index) {
                  final habit = _habits[index];
                  return HabitCard(
                    habit: habit,
                    timerController: _timerControllers[habit.id]!,
                    remainingSeconds: _remainingSeconds[habit.id]!,
                    onDelete: () => _deleteHabit(habit.id),
                    onTimeUpdate: (seconds) {
                      setState(() {
                        _remainingSeconds[habit.id] = seconds;
                      });
                    },
                  );
                },
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
  final VoidCallback onDelete;
  final Function(int) onTimeUpdate;

  const HabitCard({
    super.key,
    required this.habit,
    required this.timerController,
    required this.remainingSeconds,
    required this.onDelete,
    required this.onTimeUpdate,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  bool _isRunning = false;
  bool _isExpanded = false;
  int _remainingSeconds = 300;
  int _totalDuration = 300; // 5 minutes in seconds

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingSeconds;
  }

  @override
  void didUpdateWidget(HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != oldWidget.remainingSeconds) {
      _remainingSeconds = widget.remainingSeconds;
    }
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
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
                _resetTimer();
              },
              child: const Text('Done'),
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
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.habit.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
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
                // Circular progress indicator
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: _getProgress(),
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _remainingSeconds > 0
                                ? Colors.deepPurple
                                : Colors.green,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              _remainingSeconds <= 60 && _isRunning
                                  ? Colors.red
                                  : Colors.black87,
                        ),
                      ),
                    ],
                  ),
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
