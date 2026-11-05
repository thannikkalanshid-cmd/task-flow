import 'package:flutter/material.dart';
import '../components/task_item.dart';
import '../models/task_model.dart';

class CalendarScreen extends StatefulWidget {
  final List<Task> tasks;
  final String token;
  final VoidCallback onTaskUpdated;
  const CalendarScreen({super.key, required this.tasks, required this.token, required this.onTaskUpdated});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();

  List<Task> get _selectedTasks => widget.tasks.where((task) => task.dueDate == _date(_selected)).toList();
  String _date(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final dayCount = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7;
    return Container(
      color: const Color(0xFF070B1E),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left, color: Colors.white)), Expanded(child: Text('${_month.month}/${_month.year}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))), IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right, color: Colors.white))]),
        const SizedBox(height: 12),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text('S', style: TextStyle(color: Colors.white54)), Text('M', style: TextStyle(color: Colors.white54)), Text('T', style: TextStyle(color: Colors.white54)), Text('W', style: TextStyle(color: Colors.white54)), Text('T', style: TextStyle(color: Colors.white54)), Text('F', style: TextStyle(color: Colors.white54)), Text('S', style: TextStyle(color: Colors.white54))]),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: leading + dayCount, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (_, index) {
          if (index < leading) return const SizedBox();
          final day = DateTime(_month.year, _month.month, index - leading + 1);
          final tasks = widget.tasks.where((task) => task.dueDate == _date(day)).toList();
          final selected = _date(day) == _date(_selected); final today = _date(day) == _date(DateTime.now());
          return InkWell(onTap: () => setState(() => _selected = day), child: Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: selected ? const Color(0xFF6366F1) : (today ? Colors.white12 : Colors.transparent), borderRadius: BorderRadius.circular(10)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${day.day}', style: const TextStyle(color: Colors.white)), if (tasks.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.center, children: tasks.take(3).map((task) => Container(width: 5, height: 5, margin: const EdgeInsets.all(1), decoration: BoxDecoration(color: task.completed ? Colors.greenAccent : Colors.orangeAccent, shape: BoxShape.circle))).toList())])));
        }),
        const SizedBox(height: 18), Text('Tasks for ${_date(_selected)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        if (_selectedTasks.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No tasks for this day', style: TextStyle(color: Colors.white54)))) else ..._selectedTasks.map((task) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskItem(task: task, token: widget.token, onToggle: () {}, onDelete: () {}, onTaskUpdated: widget.onTaskUpdated))),
      ]),
    );
  }
}
