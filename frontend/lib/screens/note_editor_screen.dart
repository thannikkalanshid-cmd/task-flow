import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
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
  bool _uploading = false;

  // Files already stored on the server for this note.
  late final List<Attachment> _attachments =
      List<Attachment>.from(widget.note?.attachments ?? const []);
  // Files picked for a brand-new note; uploaded right after the note is created.
  final List<PlatformFile> _pending = [];

  static const _allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx',
    'xls', 'xlsx', 'zip', 'mp4', 'mov', 'mp3', 'wav'
  ];

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    // New note: it has no id yet, so keep the file until the note is saved.
    if (widget.note == null) {
      setState(() => _pending.add(file));
      return;
    }

    setState(() => _uploading = true);
    try {
      final uploaded = await _api.uploadAttachment(
          taskId: widget.taskId,
          noteId: widget.note!.id,
          bytes: file.bytes!,
          filename: file.name);
      if (mounted) setState(() => _attachments.add(uploaded));
      _message('Attachment added', false);
    } catch (error) {
      _message('Unable to upload attachment: $error', true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete attachment?'),
              content: Text('Remove ${attachment.originalName}?'),
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
    try {
      await _api.deleteAttachment(attachment.id);
      if (mounted) {
        setState(() => _attachments.removeWhere((a) => a.id == attachment.id));
      }
    } catch (error) {
      _message('Unable to delete attachment: $error', true);
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      _message('Unable to open attachment.', true);
    }
  }

  IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp']
        .any((ext) => lower.endsWith(ext))) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildAttachmentsSection() {
    final empty = _attachments.isEmpty && _pending.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Attachments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        TextButton.icon(
            onPressed: (_saving || _uploading) ? null : _pickAttachment,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.attach_file),
            label: const Text('Attach file')),
      ]),
      if (empty)
        const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child:
                Text('No attachments yet.', style: TextStyle(color: Colors.white54)))
      else
        ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView(shrinkWrap: true, children: [
              ..._attachments.map((attachment) => Card(
                    color: const Color(0xFF111B3A),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(_iconFor(attachment.originalName)),
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
              ..._pending.map((file) => Card(
                    color: const Color(0xFF111B3A),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(_iconFor(file.name)),
                      title: Text(file.name, overflow: TextOverflow.ellipsis),
                      subtitle: const Text('Uploads when you save the note'),
                      trailing: IconButton(
                          tooltip: 'Remove',
                          onPressed: () => setState(() => _pending.remove(file)),
                          icon: const Icon(Icons.close)),
                    ),
                  )),
            ])),
    ]);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _message('A note title is required', true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.note == null) {
        final created = await _api.createTaskNote(widget.taskId,
            title: _title.text.trim(), content: _content.text);
        var failed = 0;
        for (final file in _pending) {
          try {
            await _api.uploadAttachment(
                taskId: widget.taskId,
                noteId: created.id,
                bytes: file.bytes!,
                filename: file.name);
          } catch (_) {
            failed++;
          }
        }
        if (failed > 0) {
          _message(
              '$failed attachment(s) could not be uploaded. Open the note to retry.',
              true);
        }
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
                    const SizedBox(height: 12),
                    _buildAttachmentsSection(),
                  ]),
                ))),
      );
}
