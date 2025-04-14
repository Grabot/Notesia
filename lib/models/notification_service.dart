import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/background_service.dart';
import 'timer_utils.dart';
import 'note_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  // Flutter Local Notifications plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
      
  // Background service
  late final FlutterBackgroundService _backgroundService;
  
  // Channel IDs
  static const String timerChannelId = 'notesia_timer_channel';
  static const String timerChannelName = 'Timer Notifications';
  static const String timerChannelDesc = 'Shows active timer notifications';
  
  // Map to track active notes with timers
  final Map<String, NoteModel> _activeNotes = {};
  
  // Initialize notification service
  Future<void> init() async {
    // Initialize settings for different platforms
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          timerChannelId,
          timerChannelName,
          description: timerChannelDesc,
          importance: Importance.low,
        ),
      );
    }
    
    // Initialize background service
    await initBackgroundService();
    _backgroundService = FlutterBackgroundService();
  }
  
  void _onNotificationTapped(NotificationResponse details) {
    // Handle notification taps here or forward to appropriate handler
    final payload = details.payload;
    if (payload != null) {
      // Forward to handler
      handleNotificationAction(payload);
    }
  }
  
  // Request notification permissions
  Future<bool> requestPermission() async {
    // For iOS
    final bool? iosResult = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        
    // For Android 13 and above
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    final bool? androidResult = await androidImplementation?.requestNotificationsPermission();
    
    return (iosResult ?? false) || (androidResult ?? false);
  }
  
  // Start timer notification with background service
  void startTimerNotification(NoteModel note) async {
    if (!note.isTimerActive || note.timerStartedAt == null) {
      // Timer is not active, nothing to do
      return;
    }
    
    // Cancel existing timer if there is one
    cancelTimerNotification(note.id);
    
    // Save reference to active note
    _activeNotes[note.id] = note;
    
    // Show initial notification immediately
    await _showTimerRunningNotification(note.id, note.title, note.remainingTime);
    
    // Start the background service
    await _backgroundService.startService();
    
    // Start timer in background service
    _backgroundService.invoke('startTimer', {
      'noteId': note.id,
      'title': note.title,
      'timerDuration': note.timerDuration,
      'startTime': note.timerStartedAt!.millisecondsSinceEpoch,
    });
    
    // Also update UI every second while app is in foreground
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_activeNotes.containsKey(note.id)) {
        timer.cancel();
        return;
      }
      
      if (_activeNotes[note.id]!.isTimerCompleted) {
        cancelTimerNotification(note.id);
        timer.cancel();
        return;
      }
      
      updateTimerNotification(_activeNotes[note.id]!);
    });
  }
  
  // Update timer notification manually (for immediate UI updates)
  void updateTimerNotification(NoteModel note) async {
    if (note.isTimerActive && !note.isTimerCompleted) {
      await _showTimerRunningNotification(note.id, note.title, note.remainingTime);
    }
  }
  
  // Show running timer notification
  Future<void> _showTimerRunningNotification(String id, String title, int remainingSeconds) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDesc,
      importance: Importance.high,  // Increased importance so it's visible
      priority: Priority.high,      // Increased priority so it's visible
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public, // Make it visible on lock screen
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    
    await _flutterLocalNotificationsPlugin.show(
      id.hashCode,
      "Timer: $title",  // Add "Timer:" prefix to make it clear what the notification is
      TimerUtils.formatDuration(remainingSeconds),
      notificationDetails,
      payload: id,
    );
  }
  
  // Cancel timer notification
  void cancelTimerNotification(String noteId) async {
    // Remove from active notes
    _activeNotes.remove(noteId);
    
    // Stop timer in background service
    _backgroundService.invoke('stopTimer', {
      'noteId': noteId,
    });
    
    // Cancel immediate notification
    await _flutterLocalNotificationsPlugin.cancel(noteId.hashCode);
  }
  
  // Cancel all timer notifications
  void cancelAllTimerNotifications() async {
    _activeNotes.clear();
    
    // Stop all timers in background service
    _backgroundService.invoke('stopAllTimers');
    
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
  
  // Sync with active timers from background service
  Future<void> syncWithBackgroundService() async {
    _backgroundService.invoke('checkActiveTimers');
    
    // Listen for response
    _backgroundService.on('updateActiveTimers').listen((event) {
      if (event != null && event['timers'] != null) {
        final timers = event['timers'] as Map<String, dynamic>;
        // Update local timers as needed
      }
    });
  }
  
  // Handle notification actions
  static Future<void> handleNotificationAction(String payload) async {
    // This is a stub placeholder that will be handled by the app
    // The actual handling should happen in NotesProvider.handleNotificationAction
    // The payload contains the note ID
  }
}