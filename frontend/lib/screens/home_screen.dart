import 'package:flutter/material.dart';
import '../components/task_item.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token;

  const HomeScreen({super.key, required this.token});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<Task> _tasks = [];
  bool _isBusy = false;
  int _selectedIndex = 0;
  String _selectedFilter = 'all'; // 'all', 'active', 'completed'

  ApiService get _authorizedService => ApiService(token: widget.token);

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Load tasks from backend
  Future<void> _loadTasks() async {
    setState(() => _isBusy = true);
    try {
      final tasks = await _authorizedService.fetchTasks();
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      _showMessage('Failed to load tasks: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Create a new task
  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      _showMessage('Enter a task title first', isError: true);
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _authorizedService.createTask(
        title: title,
        description: description,
      );
      _taskController.clear();
      _descriptionController.clear();
      await _loadTasks();
      _showMessage('Task created successfully');
    } catch (e) {
      _showMessage('Unable to create task: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Toggle task completion status
  Future<void> _toggleTask(Task task) async {
    try {
      await _authorizedService.updateTask(
        task.id,
        completed: !task.completed,
      );
      await _loadTasks();
    } catch (e) {
      _showMessage('Unable to update task: $e', isError: true);
    }
  }

  /// Delete a task
  Future<void> _deleteTask(Task task) async {
    final confirmed = await _showConfirmDialog(
      'Delete Task',
      'Are you sure you want to delete "${task.title}"?',
    );

    if (!confirmed) return;

    try {
      await _authorizedService.deleteTask(task.id);
      await _loadTasks();
      _showMessage('Task deleted successfully');
    } catch (e) {
      _showMessage('Unable to delete task: $e', isError: true);
    }
  }

  /// Show message to user
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show confirmation dialog
  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Get filtered tasks based on current filter
  List<Task> get _filteredTasks {
    switch (_selectedFilter) {
      case 'active':
        return _tasks.where((task) => !task.completed).toList();
      case 'completed':
        return _tasks.where((task) => task.completed).toList();
      case 'all':
      default:
        return _tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildTaskScreen(),
      ProfileScreen(token: widget.token),
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('TaskFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF22C55E),
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFF111827),
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Build the main task screen
  Widget _buildTaskScreen() {
    final filteredTasks = _filteredTasks;
    final completedTasks = _tasks.where((task) => task.completed).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF08122A), Color(0xFF0F172A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          child: ListView(
            children: [
              // Dashboard card
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your task dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatCard('Total', _tasks.length.toString()),
                        const SizedBox(width: 12),
                        _buildStatCard('Completed', completedTasks.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Add task card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _taskController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Task title',
                        prefixIcon:
                            const Icon(Icons.edit_note, color: Colors.white70),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: const Icon(
                          Icons.description_outlined,
                          color: Colors.white70,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : _addTask,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text(
                          'Add Task',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filter buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterButton('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterButton('Active', 'active'),
                    const SizedBox(width: 8),
                    _buildFilterButton('Completed', 'completed'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tasks list
              _isBusy
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    )
                  : filteredTasks.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 56,
                                color: Colors.white24,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No tasks',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add a task to get started',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return TaskItem(
                              task: task,
                              token: widget.token,
                              onToggle: () => _toggleTask(task),
                              onDelete: () => _deleteTask(task),
                              onTaskUpdated: _loadTasks,
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a stat card for dashboard
  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build filter button
  Widget _buildFilterButton(String label, String filter) {
    final isSelected = _selectedFilter == filter;
    return ElevatedButton(
      onPressed: () {
        setState(() => _selectedFilter = filter);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFF6366F1) : const Color(0xFF111827),
        foregroundColor: Colors.white,
        // The app theme uses Size.fromHeight(52), whose width is infinite.
        // Filter buttons live in a horizontally scrolling Row, so they must
        // use their intrinsic (finite) width instead.
        minimumSize: Size.zero,
        side: isSelected
            ? BorderSide.none
            : const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
