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
    return Dismissible(
      key: Key(note.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
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
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: ListTile(
          title: Text(
            note.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: note.isTimerCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (note.timerDuration > 0)
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: note.isTimerActive
                          ? Colors.green
                          : note.isTimerCompleted
                              ? Colors.red
                              : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      note.isTimerActive
                          ? TimerUtils.formatDuration(note.remainingTime)
                          : TimerUtils.formatDurationText(note.timerDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: note.isTimerActive
                            ? Colors.green
                            : note.isTimerCompleted
                                ? Colors.red
                                : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          trailing: note.timerDuration > 0
              ? IconButton(
                  icon: Icon(
                    note.isTimerActive ? Icons.pause : Icons.play_arrow,
                    color: note.isTimerActive ? Colors.green : Colors.blue,
                  ),
                  onPressed: () {
                    final notesProvider =
                        Provider.of<NotesProvider>(context, listen: false);
                    if (note.isTimerActive) {
                      notesProvider.pauseTimer(note.id);
                    } else {
                      notesProvider.startTimer(note.id);
                    }
                  },
                )
              : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NoteDetailScreen(noteId: note.id),
              ),
            );
          },
        ),
      ),
    );
  }
}