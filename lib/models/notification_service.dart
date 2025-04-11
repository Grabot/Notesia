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
  
  // Timer update interval in seconds (update every second)
  static const int updateInterval = 1;
  
  // Map of active timer notifications with noteId as key and timer as value
  final Map<String, Timer> _activeTimerNotifications = {};
  
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
    
    // Create initial notification
    _createOrUpdateNotification(note);
    
    // Create a new periodic timer to update the notification
    _activeTimerNotifications[note.id] = Timer.periodic(
      const Duration(seconds: updateInterval),
      (_) => _updateTimerNotification(note),
    );
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
    
    // Update notification with new time
    _createOrUpdateNotification(note);
  }
  
  // Create or update notification
  void _createOrUpdateNotification(NoteModel note) {
    // Android-specific notification details
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      ongoing: true, // This makes it sticky
      autoCancel: false,
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    // Show notification with just the note title, removing redundant "Timer:" prefix
    _flutterLocalNotificationsPlugin.show(
      note.id.hashCode,
      note.title,  // Changed from 'Timer: ${note.title}' to just note.title
      TimerUtils.formatDuration(note.remainingTime),
      notificationDetails,
      payload: note.id,
    );
  }
  
  // Show timer completed notification
  void _showTimerCompletedNotification(NoteModel note) {
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
      _flutterLocalNotificationsPlugin.cancel(noteId.hashCode);
    }
  }
  
  // Cancel all timer notifications
  void cancelAllTimerNotifications() {
    for (final timer in _activeTimerNotifications.values) {
      timer.cancel();
    }
    _activeTimerNotifications.clear();
    _flutterLocalNotificationsPlugin.cancelAll();
  }
  
  // Handle notification actions
  static Future<void> handleNotificationAction(String payload) async {
    // This is a stub placeholder that will be handled by the app
    // The actual handling should happen in NotesProvider.handleNotificationAction
    // The payload contains the note ID
  }
}