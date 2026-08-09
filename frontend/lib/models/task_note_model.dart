class TaskNote {
  final int id;
  final int taskId;
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskNote(
      {required this.id,
      required this.taskId,
      required this.title,
      required this.content,
      this.createdAt,
      this.updatedAt});

  factory TaskNote.fromJson(Map<String, dynamic> json) => TaskNote(
        id: json['id'] as int,
        taskId: json['task'] as int,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}
