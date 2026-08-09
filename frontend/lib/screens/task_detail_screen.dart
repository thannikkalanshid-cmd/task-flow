import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
import '../models/task_note_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'note_editor_screen.dart';

/// Task detail and edit screen with support for all task fields
class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final String token;
  final VoidCallback onTaskUpdated;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.token,
    required this.onTaskUpdated,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _checklistController;

  late String _selectedPriority;
  late String? _selectedDueDate;
  late String? _selectedDueTime;
  late bool _isCompleted;
  late List<ChecklistItem> _checklistItems;
  late List<Attachment> _attachments;
  List<TaskNote> _taskNotes = [];
  late int? _reminderMinutes;

  bool _isLoading = false;
  bool _isEditing = false;
  bool _notesLoading = true;

  late ApiService _apiService;

  String get _reminderLabel =>
      {
        0: 'At due time',
        10: '10 minutes before',
        30: '30 minutes before',
        60: '1 hour before',
      }[_reminderMinutes] ??
      'At due time';

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(token: widget.token);

    // Initialize controllers
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController =
        TextEditingController(text: widget.task.description);
    _categoryController = TextEditingController(text: widget.task.category);
    _checklistController = TextEditingController();

    // Initialize other fields
    _selectedPriority = widget.task.priority;
    _selectedDueDate = widget.task.dueDate;
    _selectedDueTime = widget.task.dueTime;
    _isCompleted = widget.task.completed;
    _checklistItems = List.from(widget.task.checklistItems);
    _attachments = List.from(widget.task.attachments);
    _reminderMinutes = widget.task.reminderMinutes;
    _loadNotes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _checklistController.dispose();
    super.dispose();
  }

  /// Save task changes to backend
  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      _showMessage('Task title cannot be empty', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updated = await _apiService.updateTask(
        widget.task.id,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        priority: _selectedPriority,
        dueDate: _selectedDueDate,
        dueTime: _selectedDueTime,
        completed: _isCompleted,
        reminderMinutes: _reminderMinutes,
      );
      await NotificationService.instance.schedule(updated);

      widget.onTaskUpdated();
      if (mounted) {
        _showMessage('Task updated successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      _showMessage('Failed to update task: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Delete the current task
  Future<void> _deleteTask() async {
    final confirmed = await _showConfirmDialog(
      'Delete Task',
      'Are you sure you want to delete this task?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.deleteTask(widget.task.id);
      widget.onTaskUpdated();
      if (mounted) {
        _showMessage('Task deleted successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      _showMessage('Failed to delete task: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Add a checklist item
  Future<void> _addChecklistItem() async {
    final title = _checklistController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final item = await _apiService.addChecklistItem(
        widget.task.id,
        title: title,
        order: _checklistItems.length,
      );

      setState(() {
        _checklistItems.add(item);
        _checklistController.clear();
      });

      _showMessage('Checklist item added');
    } catch (e) {
      _showMessage('Failed to add checklist item: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Toggle a checklist item completion status
  Future<void> _toggleChecklistItem(ChecklistItem item) async {
    try {
      final updated = await _apiService.updateChecklistItem(
        item.id!,
        completed: !item.completed,
      );

      setState(() {
        final index = _checklistItems.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _checklistItems[index] = updated;
        }
      });
    } catch (e) {
      _showMessage('Failed to update checklist item: $e', isError: true);
    }
  }

  /// Delete a checklist item
  Future<void> _deleteChecklistItem(ChecklistItem item) async {
    final confirmed = await _showConfirmDialog(
      'Delete Item',
      'Remove this checklist item?',
    );

    if (!confirmed) return;

    try {
      await _apiService.deleteChecklistItem(item.id!);

      setState(() {
        _checklistItems.removeWhere((i) => i.id == item.id);
      });

      _showMessage('Checklist item deleted');
    } catch (e) {
      _showMessage('Failed to delete checklist item: $e', isError: true);
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _notesLoading = true);
    try {
      final notes = await _apiService.getTaskNotes(widget.task.id);
      if (mounted) setState(() => _taskNotes = notes);
    } catch (_) {
      if (mounted) _showMessage('Could not load notes', isError: true);
    } finally {
      if (mounted) setState(() => _notesLoading = false);
    }
  }

  Future<void> _openNoteEditor([TaskNote? note]) async {
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => NoteEditorScreen(
                taskId: widget.task.id, token: widget.token, note: note)));
    if (changed == true) {
      await _loadNotes();
      if (mounted)
        _showMessage(note == null ? 'Note created' : 'Notes updated');
    }
  }

  Widget _buildNotesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Notes',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        TextButton.icon(
            onPressed: _isLoading ? null : () => _openNoteEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Add Note')),
      ]),
      if (_notesLoading)
        const Center(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator()))
      else if (_taskNotes.isEmpty)
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Text('No notes yet',
                  style: TextStyle(color: Colors.white70)),
              TextButton.icon(
                  onPressed: () => _openNoteEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add your first note')),
            ]))
      else
        ..._taskNotes.map((note) => Card(
            color: const Color(0xFF111827),
            child: ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined,
                  color: Color(0xFF818CF8)),
              title: Text(note.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(note.content.isEmpty ? 'No content' : note.content,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openNoteEditor(note),
            ))),
    ]);
  }

  Future<void> _pickAndUploadAttachment() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'zip',
        'mp4',
        'mov',
        'mp3',
        'wav'
      ],
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.uploadAttachment(
          taskId: widget.task.id, bytes: file.bytes!, filename: file.name);
      widget.onTaskUpdated();
      _showMessage('Attachment uploaded. Reopen this task to view it.');
    } catch (error) {
      _showMessage('Unable to upload attachment: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    final confirmed = await _showConfirmDialog(
        'Delete attachment', 'Remove ${attachment.originalName}?');
    if (!confirmed) return;
    try {
      await _apiService.deleteAttachment(attachment.id);
      setState(
          () => _attachments.removeWhere((item) => item.id == attachment.id));
      widget.onTaskUpdated();
      _showMessage('Attachment deleted.');
    } catch (error) {
      _showMessage('Unable to delete attachment: $error', isError: true);
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      _showMessage('Unable to open attachment.', isError: true);
    }
  }

  /// Pick a date for the task
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate != null
          ? DateTime.parse(_selectedDueDate!)
          : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked.toIso8601String().split('T')[0];
      });
    }
  }

  /// Pick a time for the task
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime != null
          ? TimeOfDay(
              hour: int.parse(_selectedDueTime!.split(':')[0]),
              minute: int.parse(_selectedDueTime!.split(':')[1]),
            )
          : TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDueTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  /// Show a confirmation dialog
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
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show a message to the user
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _checklistItems.where((i) => i.completed).length;
    final totalCount = _checklistItems.length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _isLoading ? null : _deleteTask,
          ),
        ],
      ),
      body: _isLoading && _selectedDueDate == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Task Title',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() => _isEditing = true),
                  ),
                  const SizedBox(height: 16),

                  _buildDropdown(
                    label: 'Reminder',
                    value: _reminderLabel,
                    onChanged: (value) {
                      setState(() {
                        _reminderMinutes = {
                          'At due time': 0,
                          '10 minutes before': 10,
                          '30 minutes before': 30,
                          '1 hour before': 60
                        }[value];
                        _isEditing = true;
                      });
                    },
                    items: const [
                      'At due time',
                      '10 minutes before',
                      '30 minutes before',
                      '1 hour before'
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Completion checkbox
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isCompleted,
                          onChanged: (value) {
                            setState(() {
                              _isCompleted = value ?? false;
                              _isEditing = true;
                            });
                          },
                          fillColor: MaterialStateProperty.all(
                            const Color(0xFF6366F1),
                          ),
                        ),
                        Text(
                          _isCompleted ? 'Completed' : 'Mark as completed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category and Priority row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Category',
                          value: _categoryController.text,
                          onChanged: (value) {
                            _categoryController.text = value;
                            _isEditing = true;
                          },
                          items: [
                            'General',
                            'Work',
                            'Personal',
                            'Shopping',
                            'Health'
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Priority',
                          value: _selectedPriority,
                          onChanged: (value) {
                            setState(() {
                              _selectedPriority = value;
                              _isEditing = true;
                            });
                          },
                          items: ['low', 'medium', 'high'],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Due Date and Time
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white24,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Due Date',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedDueDate ?? 'No date',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white24,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Due Time',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedDueTime ?? 'No time',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter task description',
                      filled: true,
                      fillColor: const Color(0xFF111827),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() => _isEditing = true),
                  ),
                  const SizedBox(height: 20),

                  // Independent notes are intentionally separate from the legacy Task.notes field.
                  _buildNotesSection(),
                  const SizedBox(height: 24),

                  // Checklist section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Checklist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (totalCount > 0)
                        Text(
                          '$completedCount/$totalCount',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Checklist progress bar
                  if (totalCount > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: completedCount / totalCount,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(completedCount == totalCount
                              ? 0xFF22C55E
                              : 0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Checklist items
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _checklistItems.length,
                    itemBuilder: (context, index) {
                      final item = _checklistItems[index];
                      return _buildChecklistItem(item);
                    },
                  ),

                  // Add checklist item input
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _checklistController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add checklist item',
                            filled: true,
                            fillColor: const Color(0xFF111827),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _addChecklistItem,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Attachments',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      TextButton.icon(
                          onPressed:
                              _isLoading ? null : _pickAndUploadAttachment,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Upload')),
                    ],
                  ),
                  if (_attachments.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('No attachments yet.',
                            style: TextStyle(color: Colors.white54)))
                  else
                    ..._attachments.map((attachment) => Card(
                          color: const Color(0xFF111827),
                          child: ListTile(
                            leading: Icon(attachment.originalName
                                    .toLowerCase()
                                    .endsWith('.pdf')
                                ? Icons.picture_as_pdf_outlined
                                : Icons.insert_drive_file_outlined),
                            title: Text(attachment.originalName,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => _openAttachment(attachment),
                            trailing: IconButton(
                                tooltip: 'Delete attachment',
                                onPressed: () => _deleteAttachment(attachment),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent)),
                          ),
                        )),
                  const SizedBox(height: 12),

                  // Save button
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveTask,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  /// Build a checklist item widget
  Widget _buildChecklistItem(ChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: item.completed,
            onChanged: (_) => _toggleChecklistItem(item),
            fillColor: MaterialStateProperty.all(
              const Color(0xFF6366F1),
            ),
          ),
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: item.completed ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _deleteChecklistItem(item),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a dropdown widget
  Widget _buildDropdown({
    required String label,
    required String value,
    required Function(String) onChanged,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButton<String>(
            value: value.isNotEmpty ? value : items.first,
            isExpanded: true,
            underline: const SizedBox(),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ))
                .toList(),
            onChanged: (val) => onChanged(val ?? items.first),
            dropdownColor: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
