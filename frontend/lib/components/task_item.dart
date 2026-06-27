import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../screens/task_detail_screen.dart';

/// Widget for displaying a task in a list with key information
class TaskItem extends StatelessWidget {
  final Task task;
  final String token;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTaskUpdated;

  const TaskItem({
    super.key,
    required this.task,
    required this.token,
    required this.onToggle,
    required this.onDelete,
    required this.onTaskUpdated,
  });

  /// Get priority color based on priority level
  Color _getPriorityColor() {
    switch (task.priority) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
      default:
        return Colors.greenAccent;
    }
  }

  /// Format the due date and time for display
  String _formatDueDate() {
    if (task.dueDate == null) return '';

    final parts = task.dueDate!.split('-');
    if (parts.length != 3) return task.dueDate!;

    final date = DateTime.parse(task.dueDate!);
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    }

    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDueDate = task.dueDate != null;
    final hasChecklist = task.checklistItems.isNotEmpty;
    final isOverdue =
        hasDueDate && DateTime.parse(task.dueDate!).isBefore(DateTime.now());

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(
              task: task,
              token: token,
              onTaskUpdated: onTaskUpdated,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: task.completed
              ? const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF047857)],
                )
              : const LinearGradient(
                  colors: [Color(0xFF111827), Color(0xFF1E293B)],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and completion checkbox
              Row(
                children: [
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: task.completed
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white54,
                          width: 1.5,
                        ),
                      ),
                      child: task.completed
                          ? const Icon(
                              Icons.check,
                              color: Color(0xFF047857),
                              size: 22,
                            )
                          : const Icon(
                              Icons.check_box_outline_blank,
                              color: Colors.white54,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.completed
                                ? Colors.white70
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: TextStyle(
                              color: task.completed
                                  ? Colors.white60
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Metadata row (category, priority, due date)
              Row(
                children: [
                  if (task.category.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.category,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: _getPriorityColor(), width: 0.5),
                    ),
                    child: Text(
                      task.priority,
                      style: TextStyle(
                        color: _getPriorityColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasDueDate) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? Colors.redAccent.withOpacity(0.2)
                            : Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOverdue
                              ? Colors.redAccent
                              : Colors.blueAccent,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        _formatDueDate(),
                        style: TextStyle(
                          color: isOverdue
                              ? Colors.redAccent
                              : Colors.blueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (task.notes.isNotEmpty)
                    const Tooltip(
                      message: 'Has notes',
                      child: Icon(
                        Icons.note_outlined,
                        size: 16,
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),

              // Checklist progress bar
              if (hasChecklist) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: task.checklistProgress,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                            task.checklistProgress == 1.0
                                ? Colors.greenAccent
                                : const Color(0xFF22C55E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${task.completedChecklistCount}/${task.totalChecklistCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

