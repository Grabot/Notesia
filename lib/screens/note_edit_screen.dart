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
    // Get initial hours, minutes, seconds for display
    final initialHours = _timerDuration ~/ 3600;
    final initialMinutes = (_timerDuration % 3600) ~/ 60;
    final initialSeconds = _timerDuration % 60;
    
    // Time input for numpad entry
    String timeInput = '';
    // Format initial value as HHMMSS (padded with zeros)
    if (_timerDuration > 0) {
      timeInput = '${initialHours.toString().padLeft(2, '0')}${initialMinutes.toString().padLeft(2, '0')}${initialSeconds.toString().padLeft(2, '0')}';
    }
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Format the current input for display
          String displayTime = '00:00:00';
          if (timeInput.isNotEmpty) {
            final paddedInput = timeInput.padLeft(6, '0');
            final hours = paddedInput.substring(0, 2);
            final minutes = paddedInput.substring(2, 4);
            final seconds = paddedInput.substring(4, 6);
            displayTime = '$hours:$minutes:$seconds';
          }

          return AlertDialog(
            title: const Text('Set Timer Duration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Time display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayTime,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Numpad
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNumpadButton('1', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '1';
                          });
                        }),
                        _buildNumpadButton('2', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '2';
                          });
                        }),
                        _buildNumpadButton('3', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '3';
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNumpadButton('4', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '4';
                          });
                        }),
                        _buildNumpadButton('5', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '5';
                          });
                        }),
                        _buildNumpadButton('6', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '6';
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNumpadButton('7', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '7';
                          });
                        }),
                        _buildNumpadButton('8', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '8';
                          });
                        }),
                        _buildNumpadButton('9', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '9';
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNumpadButton('C', () {
                          setStateDialog(() {
                            timeInput = '';
                          });
                        }, backgroundColor: Colors.red.shade100),
                        _buildNumpadButton('0', () {
                          setStateDialog(() {
                            if (timeInput.length < 6) timeInput += '0';
                          });
                        }),
                        _buildNumpadButton('⌫', () {
                          setStateDialog(() {
                            if (timeInput.isNotEmpty) {
                              timeInput = timeInput.substring(0, timeInput.length - 1);
                            }
                          });
                        }, backgroundColor: Colors.grey.shade100),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Text(
                  'Enter time as HHMMSS',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
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
                  // Convert input time to seconds
                  final paddedInput = timeInput.padLeft(6, '0');
                  final hours = int.tryParse(paddedInput.substring(0, 2)) ?? 0;
                  final minutes = int.tryParse(paddedInput.substring(2, 4)) ?? 0;
                  final seconds = int.tryParse(paddedInput.substring(4, 6)) ?? 0;
                  
                  // Check for valid time values
                  if (hours > 23 || minutes > 59 || seconds > 59) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid time format. Hours must be 0-23, minutes and seconds must be 0-59.')),
                    );
                    return;
                  }
                  
                  setState(() {
                    _timerDuration = (hours * 3600) + (minutes * 60) + seconds;
                  });
                  Navigator.of(ctx).pop();
                },
                child: const Text('Set'),
              ),
            ],
          );
        }
      ),
    );
  }
  
  Widget _buildNumpadButton(String label, VoidCallback onPressed, {Color? backgroundColor}) {
    return SizedBox(
      width: 60,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
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