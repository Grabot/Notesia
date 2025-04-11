import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'note_model.dart';
import 'notification_service.dart';
import '../services/background_task.dart';

class NotesProvider with ChangeNotifier {
  List<NoteModel> _notes = [];
  bool _isLoading = false;
  static const String _storageKey = 'notesia_notes';
  final NotificationService _notificationService = NotificationService();

  NotesProvider() {
    // Loading will happen in init now
  }

  // Initialize provider
  Future<void> init() async {
    await loadNotes();
    _checkActiveTimers();
  }

  // Check if any active timers need to be updated
  void _checkActiveTimers() async {
    // Load active timers from background task storage
    final prefs = await SharedPreferences.getInstance();
    final timersJson = prefs.getString(ACTIVE_TIMERS_KEY);
    
    if (timersJson != null && timersJson.isNotEmpty) {
      final Map<String, dynamic> activeTimers = json.decode(timersJson);
      
      // Update local notes based on active timers
      bool hasChanges = false;
      
      for (final entry in activeTimers.entries) {
        final noteId = entry.key;
        final timer = entry.value;
        
        // Find the note in the list
        final noteIndex = _notes.indexWhere((note) => note.id == noteId);
        if (noteIndex >= 0) {
          final note = _notes[noteIndex];
          final startTime = DateTime.fromMillisecondsSinceEpoch(timer['startTime']);
          final duration = timer['duration'] as int;
          
          // Check if note should be active but isn't
          if (!note.isTimerActive) {
            _notes[noteIndex] = note.copyWith(
              isTimerActive: true,
              timerStartedAt: startTime,
              timerDuration: duration,
            );
            hasChanges = true;
          }
        }
      }
      
      // Notify listeners if there were changes
      if (hasChanges) {
        notifyListeners();
      }
    }
  }

  List<NoteModel> get notes => [..._notes];
  bool get isLoading => _isLoading;
  NotificationService get notificationService => _notificationService;
  
  // Get all active timers
  List<NoteModel> get activeTimers => 
      _notes.where((note) => note.isTimerActive && !note.isTimerCompleted).toList();

  // Get note by id
  NoteModel? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // Get note by notification id (hashCode)
  NoteModel? getNoteByNotificationId(int notificationId) {
    try {
      return _notes.firstWhere((note) => note.id.hashCode == notificationId);
    } catch (e) {
      return null;
    }
  }

  // Add a new note
  Future<void> addNote(NoteModel note) async {
    _notes.add(note);
    notifyListeners();
    await _saveNotesToStorage();
  }

  // Update an existing note
  Future<void> updateNote(NoteModel updatedNote) async {
    final index = _notes.indexWhere((note) => note.id == updatedNote.id);
    if (index >= 0) {
      _notes[index] = updatedNote;
      
      // Update notification if timer is active
      if (updatedNote.isTimerActive && !updatedNote.isTimerCompleted) {
        _notificationService.startTimerNotification(updatedNote);
      } else {
        _notificationService.cancelTimerNotification(updatedNote.id);
      }
      
      notifyListeners();
      await _saveNotesToStorage();
    }
  }

  // Delete a note
  Future<void> deleteNote(String id) async {
    // Cancel any active notification for this note
    _notificationService.cancelTimerNotification(id);
    
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
    await _saveNotesToStorage();
  }

  // Start a timer for a note
  Future<void> startTimer(String noteId) async {
    final note = getNoteById(noteId);
    if (note != null) {
      note.startTimer();
      
      // Start notification for this timer
      _notificationService.startTimerNotification(note);
      
      notifyListeners();
      await _saveNotesToStorage();
    }
  }

  // Pause a timer for a note
  Future<void> pauseTimer(String noteId) async {
    final note = getNoteById(noteId);
    if (note != null) {
      note.pauseTimer();
      
      // Cancel the notification
      _notificationService.cancelTimerNotification(noteId);
      
      notifyListeners();
      await _saveNotesToStorage();
    }
  }

  // Reset a timer for a note
  Future<void> resetTimer(String noteId) async {
    final note = getNoteById(noteId);
    if (note != null) {
      note.resetTimer();
      
      // Cancel the notification
      _notificationService.cancelTimerNotification(noteId);
      
      notifyListeners();
      await _saveNotesToStorage();
    }
  }

  // Set duration for a note's timer
  Future<void> setTimerDuration(String noteId, int seconds) async {
    final note = getNoteById(noteId);
    if (note != null) {
      note.setTimerDuration(seconds);
      
      // Cancel any existing notification
      _notificationService.cancelTimerNotification(noteId);
      
      notifyListeners();
      await _saveNotesToStorage();
    }
  }

  // Handle notification actions
  Future<void> handleNotificationAction(String noteId) async {
    final note = getNoteById(noteId);
    if (note != null) {
      // Update timer state if needed (in case it completed in the background)
      if (note.isTimerCompleted) {
        note.resetTimer();
        notifyListeners();
        await _saveNotesToStorage();
      }
      
      // For now just open the note or update notification
      // More specific actions like pause/resume can be added with buttons in notification layout
      if (note.isTimerActive && !note.isTimerCompleted) {
        // This will trigger a refresh of the notification
        _notificationService.updateTimerNotification(note);
      }
    }
  }

  // Load notes from shared preferences
  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString(_storageKey);
      
      if (notesJson != null) {
        final notesData = json.decode(notesJson) as List<dynamic>;
        _notes = notesData.map((item) => NoteModel.fromJson(item)).toList();
        
        // Start notifications for any active timers
        for (final note in activeTimers) {
          _notificationService.startTimerNotification(note);
        }
      }
    } catch (e) {
      print('Error loading notes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save notes to shared preferences
  Future<void> _saveNotesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = json.encode(_notes.map((note) => note.toJson()).toList());
      await prefs.setString(_storageKey, notesJson);
    } catch (e) {
      print('Error saving notes: $e');
    }
  }
}