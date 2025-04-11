import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'timer_utils.dart';
import 'note_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  // Flutter Local Notifications plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  // Channel IDs
  static const String timerChannelId = 'timer_channel';
  static const String timerChannelName = 'Timer Notifications';
  static const String timerChannelDesc = 'Shows active timer notifications';
  
  // Timer update interval in seconds (internal updates happen every second)
  static const int updateInterval = 1;
  
  // We'll update the progress bar more frequently but text content less often
  static const int progressUpdateInterval = 5; // Update progress every 5 seconds
  static const int fullContentUpdateInterval = 30; // Full content update every 30 seconds
  
  // Map of active timer notifications with noteId as key and timer as value
  final Map<String, Timer> _activeTimerNotifications = {};
  
  // Map to track last time the notification was visibly updated
  final Map<String, DateTime> _lastProgressUpdates = {};
  final Map<String, DateTime> _lastFullContentUpdates = {};
  
  // Global map to store progress percent for each note
  final Map<String, double> _progressPercents = {};
  
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
  }
  
  void _onNotificationTapped(NotificationResponse details) {
    // Handle notification taps here or forward to appropriate handler
    // This could be expanded to handle the note ID from the payload
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
  
  // Start timer notification
  void startTimerNotification(NoteModel note) {
    // Cancel existing timer if there is one
    cancelTimerNotification(note.id);
    
    // Calculate initial progress
    _updateProgressPercent(note);
    
    // Create initial notification with full content
    _createInitialNotification(note);
    
    // Create a new periodic timer to update the notification
    _activeTimerNotifications[note.id] = Timer.periodic(
      const Duration(seconds: updateInterval),
      (_) => _updateTimerNotification(note),
    );
  }
  
  // Calculate and store progress percent
  void _updateProgressPercent(NoteModel note) {
    final int remaining = note.remainingTime;
    final int total = note.timerDuration;
    // Calculate progress as percentage of time elapsed
    final double progressPercent = total > 0 
        ? ((total - remaining) * 100 / total).roundToDouble() 
        : 0.0;
    
    // Store the progress percent
    _progressPercents[note.id] = progressPercent;
  }
  
  // Update timer notification
  void _updateTimerNotification(NoteModel note) {
    if (!note.isTimerActive || note.isTimerCompleted) {
      // Timer is no longer active or completed, cancel the notification
      cancelTimerNotification(note.id);
      
      // If timer completed, show completion notification
      if (note.isTimerCompleted) {
        _showTimerCompletedNotification(note);
      }
      return;
    }
    
    // Always update the progress percent calculation
    _updateProgressPercent(note);
    
    final now = DateTime.now();
    final lastProgressUpdate = _lastProgressUpdates[note.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
    final lastFullUpdate = _lastFullContentUpdates[note.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
    
    final secondsSinceProgressUpdate = now.difference(lastProgressUpdate).inSeconds;
    final secondsSinceFullUpdate = now.difference(lastFullUpdate).inSeconds;
    
    // Always update more frequently when timer is about to end
    final bool isNearCompletion = note.remainingTime <= 10;
    
    // Decide what kind of update to perform
    if (secondsSinceFullUpdate >= fullContentUpdateInterval || isNearCompletion) {
      // Time for a full content update (including text)
      _updateFullNotification(note);
      _lastFullContentUpdates[note.id] = now;
      _lastProgressUpdates[note.id] = now; // Reset progress update time as well
    } else if (secondsSinceProgressUpdate >= progressUpdateInterval) {
      // Just update the progress
      _updateProgressOnly(note);
      _lastProgressUpdates[note.id] = now;
    }
  }
  
  // Create the initial notification with full content
  void _createInitialNotification(NoteModel note) {
    // Record update times
    final now = DateTime.now();
    _lastFullContentUpdates[note.id] = now;
    _lastProgressUpdates[note.id] = now;
    
    // Android-specific notification details with progress indicator
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: _progressPercents[note.id]?.toInt() ?? 0,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      ongoing: true, // This makes it sticky
      autoCancel: false,
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    // Show initial notification
    _flutterLocalNotificationsPlugin.show(
      note.id.hashCode,
      'Timer: ${note.title}',
      TimerUtils.formatDuration(note.remainingTime),
      notificationDetails,
      payload: note.id,
    );
  }
  
  // Update just the progress bar (minimal update to avoid disruption)
  void _updateProgressOnly(NoteModel note) {
    // Android-specific notification details with progress indicator
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: _progressPercents[note.id]?.toInt() ?? 0,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    // Show updated notification with only progress change
    _flutterLocalNotificationsPlugin.show(
      note.id.hashCode,
      'Timer: ${note.title}',
      TimerUtils.formatDuration(note.remainingTime),
      notificationDetails,
      payload: note.id,
    );
  }
  
  // Full notification update (updated body text and progress)
  void _updateFullNotification(NoteModel note) {
    // Android-specific notification details with progress indicator
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: _progressPercents[note.id]?.toInt() ?? 0,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    // Show fully updated notification with new body text
    _flutterLocalNotificationsPlugin.show(
      note.id.hashCode,
      'Timer: ${note.title}',
      TimerUtils.formatDuration(note.remainingTime),
      notificationDetails,
      payload: note.id,
    );
  }
  
  // Show timer completed notification
  void _showTimerCompletedNotification(NoteModel note) {
    // Clean up the tracking maps
    _lastProgressUpdates.remove(note.id);
    _lastFullContentUpdates.remove(note.id);
    _progressPercents.remove(note.id);
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    _flutterLocalNotificationsPlugin.show(
      note.id.hashCode,
      'Timer Finished',
      '${note.title} timer has completed!',
      notificationDetails,
      payload: note.id,
    );
  }
  
  // Cancel timer notification for a specific noteId
  void cancelTimerNotification(String noteId) {
    if (_activeTimerNotifications.containsKey(noteId)) {
      _activeTimerNotifications[noteId]?.cancel();
      _activeTimerNotifications.remove(noteId);
      _lastProgressUpdates.remove(noteId);
      _lastFullContentUpdates.remove(noteId);
      _progressPercents.remove(noteId);
      _flutterLocalNotificationsPlugin.cancel(noteId.hashCode);
    }
  }
  
  // Cancel all timer notifications
  void cancelAllTimerNotifications() {
    for (final timer in _activeTimerNotifications.values) {
      timer.cancel();
    }
    _activeTimerNotifications.clear();
    _lastProgressUpdates.clear();
    _lastFullContentUpdates.clear();
    _progressPercents.clear();
    _flutterLocalNotificationsPlugin.cancelAll();
  }
  
  // Handle notification actions
  static Future<void> handleNotificationAction(String payload) async {
    // This is a stub placeholder that will be handled by the app
    // The actual handling should happen in NotesProvider.handleNotificationAction
    // The payload contains the note ID
  }
}