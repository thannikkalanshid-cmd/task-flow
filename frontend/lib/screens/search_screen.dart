import 'package:flutter/material.dart';
import '../components/task_item.dart';
import '../models/task_model.dart';

class SearchScreen extends StatefulWidget {
  final List<Task> tasks;
  final String token;
  final VoidCallback onTaskUpdated;

  const SearchScreen({
    super.key,
    required this.tasks,
    required this.token,
    required this.onTaskUpdated,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.toLowerCase();

    final filteredTasks = widget.tasks.where((task) {
      return '${task.title} ${task.description} ${task.category} ${task.notes}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return Container(
      color: const Color(0xFF08122A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search tasks',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white70,
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF1E293B),
              ),
            ),
          ),
          Expanded(
            child: filteredTasks.isEmpty
                ? const Center(
                    child: Text(
                      'No matching tasks',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];

                      return TaskItem(
                        task: task,
                        token: widget.token,
                        onToggle: () {},
                        onDelete: () {},
                        onTaskUpdated: widget.onTaskUpdated,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}