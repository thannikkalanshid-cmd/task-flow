/// ChecklistItem model representing a single checklist item within a task
class ChecklistItem {
  final int? id;
  final String title;
  final bool completed;
  final int order;
  final String? createdAt;
  final String? updatedAt;

  ChecklistItem({
    this.id,
    required this.title,
    required this.completed,
    required this.order,
    this.createdAt,
    this.updatedAt,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'],
      title: json['title'] ?? '',
      completed: json['completed'] ?? false,
      order: json['order'] ?? 0,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'completed': completed,
      'order': order,
    };
  }
}

/// Task model representing a single task with enhanced features
class Task {
  final int id;
  final String title;
  final String description;
  final String category;
  final String priority; // 'low', 'medium', 'high'
  final String? dueDate; // YYYY-MM-DD format
  final String? dueTime; // HH:MM format
  final String notes;
  final bool completed;
  final String? createdAt;
  final String? updatedAt;
  final int owner;
  final List<ChecklistItem> checklistItems;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.dueDate,
    this.dueTime,
    required this.notes,
    required this.completed,
    this.createdAt,
    this.updatedAt,
    required this.owner,
    this.checklistItems = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    final items = (json['checklist_items'] as List<dynamic>?)
            ?.map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    return Task(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'General',
      priority: json['priority'] ?? 'medium',
      dueDate: json['due_date'],
      dueTime: json['due_time'],
      notes: json['notes'] ?? '',
      completed: json['completed'] ?? false,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      owner: json['owner'] ?? 0,
      checklistItems: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'due_date': dueDate,
      'due_time': dueTime,
      'notes': notes,
      'completed': completed,
    };
  }

  /// Get the number of completed checklist items
  int get completedChecklistCount =>
      checklistItems.where((item) => item.completed).length;

  /// Get the total number of checklist items
  int get totalChecklistCount => checklistItems.length;

  /// Get the progress percentage of the task
  double get checklistProgress {
    if (totalChecklistCount == 0) return 0;
    return completedChecklistCount / totalChecklistCount;
  }

  /// Create a copy of this task with updated fields
  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? dueDate,
    String? dueTime,
    String? notes,
    bool? completed,
    String? createdAt,
    String? updatedAt,
    int? owner,
    List<ChecklistItem>? checklistItems,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      owner: owner ?? this.owner,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }
}
