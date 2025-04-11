import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/notes_provider.dart';
import '../models/note_model.dart';
import '../models/timer_utils.dart';
import 'note_edit_screen.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Update UI every second to refresh timer display
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  Future<void> _confirmDelete() async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await notesProvider.deleteNote(widget.noteId);
        if (mounted) {
          // Navigate back to the home screen (notes list)
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Details'),
        actions: [
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: _confirmDelete,
            tooltip: 'Delete Note',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NoteEditScreen(noteId: widget.noteId),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<NotesProvider>(
        builder: (ctx, notesProvider, child) {
          final note = notesProvider.getNoteById(widget.noteId);

          if (note == null) {
            return const Center(child: Text('Note not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Created: ${TimerUtils.formatDateTime(note.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (note.updatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Updated: ${TimerUtils.formatDateTime(note.updatedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const Divider(height: 24),
                // Timer section
                if (note.timerDuration > 0) ...[
                  _buildTimerSection(note, notesProvider),
                  const Divider(height: 24),
                ],
                // Note content
                Text(
                  note.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimerSection(NoteModel note, NotesProvider notesProvider) {
    final isCompleted = note.isTimerCompleted;
    final isActive = note.isTimerActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timer',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.red.withOpacity(0.1)
                : isActive
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isActive
                        ? 'Remaining'
                        : isCompleted
                        ? 'Completed'
                        : 'Duration',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    isActive
                        ? TimerUtils.formatDuration(note.remainingTime)
                        : TimerUtils.formatDurationText(note.timerDuration),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? Colors.red
                          : isActive
                          ? Colors.green
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Start/Pause button
                  ElevatedButton.icon(
                    onPressed: isCompleted
                        ? null
                        : () {
                      if (isActive) {
                        notesProvider.pauseTimer(note.id);
                      } else {
                        notesProvider.startTimer(note.id);
                      }
                    },
                    icon: Icon(isActive ? Icons.pause : Icons.play_arrow),
                    label: Text(isActive ? 'Pause' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  // Reset button
                  OutlinedButton.icon(
                    onPressed: () {
                      notesProvider.resetTimer(note.id);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}