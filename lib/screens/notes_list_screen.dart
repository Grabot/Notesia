import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_provider.dart';
import '../models/timer_utils.dart';
import '../models/note_model.dart';
import 'note_detail_screen.dart';
import 'note_edit_screen.dart';
import 'dart:async';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update UI every second to refresh timer displays
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notesia'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Consumer<NotesProvider>(
        builder: (ctx, notesProvider, child) {
          if (notesProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notesProvider.notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.note_alt_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No notes yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap the + button to create a new note',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notesProvider.notes.length,
            itemBuilder: (ctx, index) {
              final note = notesProvider.notes[index];
              return NoteListItem(note: note);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NoteEditScreen(),
            ),
          );
        },
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteListItem extends StatelessWidget {
  final NoteModel note;

  const NoteListItem({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoteDetailScreen(noteId: note.id),
            ),
          );
        },
        child: Stack(
          children: [
            // Main note content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    note.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      decoration: note.isTimerCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Timer section (if exists)
                  if (note.timerDuration > 0) 
                    _buildTimerSection(context),
                  
                  const SizedBox(height: 16),
                  
                  // Note content preview
                  Text(
                    note.content,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Date information
                  Text(
                    'Created: ${TimerUtils.formatDateTime(note.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (note.updatedAt != null) 
                    Text(
                      'Updated: ${TimerUtils.formatDateTime(note.updatedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            
            // Delete button in top right
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey.shade600,
                onPressed: () => _showDeleteDialog(context),
              ),
            ),
            
            // Play/pause button for timers
            if (note.timerDuration > 0)
              Positioned(
                bottom: 12,
                right: 12,
                child: FloatingActionButton.small(
                  heroTag: "btn-${note.id}",
                  backgroundColor: note.isTimerActive 
                      ? Colors.orange 
                      : note.isTimerCompleted 
                          ? Colors.grey 
                          : Colors.green,
                  onPressed: note.isTimerCompleted ? null : () {
                    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                    if (note.isTimerActive) {
                      notesProvider.pauseTimer(note.id);
                    } else {
                      notesProvider.startTimer(note.id);
                    }
                  },
                  child: Icon(
                    note.isTimerActive ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimerSection(BuildContext context) {
    final bool isActive = note.isTimerActive;
    final bool isCompleted = note.isTimerCompleted;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.red.withOpacity(0.1)
            : isActive
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            size: 28,
            color: isCompleted
                ? Colors.red
                : isActive
                    ? Colors.green
                    : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive 
                      ? 'Running' 
                      : isCompleted 
                          ? 'Completed' 
                          : 'Timer set',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted
                        ? Colors.red
                        : isActive
                            ? Colors.green
                            : Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? TimerUtils.formatDuration(note.remainingTime)
                      : TimerUtils.formatDurationText(note.timerDuration),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? Colors.red
                        : isActive
                            ? Colors.green
                            : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<NotesProvider>(context, listen: false).deleteNote(note.id);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${note.title} deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      Provider.of<NotesProvider>(context, listen: false).addNote(note);
                    },
                  ),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}