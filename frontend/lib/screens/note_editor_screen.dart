import 'package:flutter/material.dart';
import '../models/task_note_model.dart';
import '../services/api_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final int taskId;
  final String token;
  final TaskNote? note;
  const NoteEditorScreen(
      {super.key, required this.taskId, required this.token, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _content =
      TextEditingController(text: widget.note?.content ?? '');
  late final ApiService _api = ApiService(token: widget.token);
  bool _saving = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _message('A note title is required', true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.note == null) {
        await _api.createTaskNote(widget.taskId,
            title: _title.text.trim(), content: _content.text);
      } else {
        await _api.updateTaskNote(widget.note!.id,
            title: _title.text.trim(), content: _content.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _message('Could not save note', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete this note?'),
              content: const Text('This action cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete')),
              ],
            ));
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _api.deleteTaskNote(widget.note!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _message('Could not delete note', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, bool error) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.redAccent : Colors.green));

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
            actions: [
              if (widget.note != null)
                IconButton(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline)),
              TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save')),
            ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    TextField(
                        controller: _title,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 16),
                    Expanded(
                        child: TextField(
                            controller: _content,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                                labelText: 'Content',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder()))),
                  ]),
                ))),
      );
}
