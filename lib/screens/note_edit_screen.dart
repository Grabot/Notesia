import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../models/notes_provider.dart';
import '../models/timer_utils.dart';

class NoteEditScreen extends StatefulWidget {
  final String? noteId;
  const NoteEditScreen({super.key, this.noteId});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int _timerDuration = 0; // in seconds
  bool _isLoading = false;
  late NoteModel? _note;

  @override
  void initState() {
    super.initState();
    _loadNoteData();
  }

  void _loadNoteData() {
    if (widget.noteId != null) {
      setState(() {
        _isLoading = true;
      });
      
      _note = Provider.of<NotesProvider>(context, listen: false)
          .getNoteById(widget.noteId!);

      if (_note != null) {
        _titleController.text = _note!.title;
        _contentController.text = _note!.content;
        _timerDuration = _note!.timerDuration;
      }
      
      setState(() {
        _isLoading = false;
      });
    } else {
      _note = null;
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (_note == null) {
        // Create new note
        final newNote = NoteModel(
          title: _titleController.text,
          content: _contentController.text,
          timerDuration: _timerDuration,
        );
        await notesProvider.addNote(newNote);
      } else {
        // Update existing note
        final updatedNote = _note!.copyWith(
          title: _titleController.text,
          content: _contentController.text,
          timerDuration: _timerDuration,
        );
        await notesProvider.updateNote(updatedNote);
      }
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showTimerSetupDialog() async {
    int hours = _timerDuration ~/ 3600;
    int minutes = (_timerDuration % 3600) ~/ 60;
    int seconds = _timerDuration % 60;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _timePickerColumn('Hours', hours, (value) {
                  hours = value;
                }),
                _timePickerColumn('Minutes', minutes, (value) {
                  minutes = value;
                }),
                _timePickerColumn('Seconds', seconds, (value) {
                  seconds = value;
                }),
              ],
            ),
            const SizedBox(height: 20),
            if (_timerDuration > 0)
              Text(
                'Current Duration: ${TimerUtils.formatDurationText(_timerDuration)}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _timerDuration = (hours * 3600) + (minutes * 60) + seconds;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _timePickerColumn(String label, int initialValue, Function(int) onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: DropdownButtonFormField<int>(
            value: initialValue,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            items: List.generate(
              label == 'Hours' ? 24 : 60,
              (index) => DropdownMenuItem(
                value: index,
                child: Text(
                  index.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'Add Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveNote,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showTimerSetupDialog,
                          icon: const Icon(Icons.timer),
                          label: Text(_timerDuration > 0
                              ? 'Timer: ${TimerUtils.formatDurationText(_timerDuration)}'
                              : 'Set Timer'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_timerDuration > 0) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _timerDuration = 0;
                            });
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Remove timer',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Note Content'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Write your note here...',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}