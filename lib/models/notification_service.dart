import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'timer_utils.dart';
import 'note_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  // Channel keys
  static const String timerChannelKey = 'timer_channel';
  
  // Timer update interval in seconds
  static const int updateInterval = 1;
  
  // Map of active timer notifications with noteId as key and timer as value
  final Map<String, Timer> _activeTimerNotifications = {};
  
  // Initialize notification service
  Future<void> init() async {
    await AwesomeNotifications().initialize(
      // null icon sets default app icon as notification icon
      null, 
      [
        NotificationChannel(
          channelGroupKey: 'timer_channel_group',
          channelKey: timerChannelKey,
          channelName: 'Timer Notifications',
          channelDescription: 'Shows active timer notifications',
          defaultColor: Colors.teal,
          ledColor: Colors.teal,
          importance: NotificationImportance.High,
          playSound: false,
          enableVibration: false,
        )
      ],
    );
  }
  
  // Request notification permissions
  Future<bool> requestPermission() async {
    return await AwesomeNotifications().isNotificationAllowed()
      .then((isAllowed) {
        if (!isAllowed) {
          return AwesomeNotifications().requestPermissionToSendNotifications();
        }
        return true;
      });
  }
  
  // Start timer notification
  void startTimerNotification(NoteModel note) {
    // Cancel existing timer if there is one
    cancelTimerNotification(note.id);
    
    // Create a new periodic timer to update the notification
    _activeTimerNotifications[note.id] = Timer.periodic(
      const Duration(seconds: updateInterval),
      (_) => _updateTimerNotification(note),
    );
    
    // Show initial notification
    _createOrUpdateNotification(note);
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
    
    // Update the notification with current remaining time
    _createOrUpdateNotification(note);
  }
  
  // Create or update the timer notification
  void _createOrUpdateNotification(NoteModel note) {
    final int remaining = note.remainingTime;
    
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: note.id.hashCode, // Use hashCode as a unique ID
        channelKey: timerChannelKey,
        title: 'Timer Active: ${note.title}',
        body: 'Remaining time: ${TimerUtils.formatDuration(remaining)}',
        notificationLayout: NotificationLayout.Default,
        locked: true, // Makes notification persistent
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'PAUSE',
          label: 'Pause',
        ),
      ]
    );
  }
  
  // Show timer completed notification
  void _showTimerCompletedNotification(NoteModel note) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: note.id.hashCode,
        channelKey: timerChannelKey,
        title: 'Timer Finished',
        body: '${note.title} timer has completed!',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }
  
  // Cancel timer notification for a specific noteId
  void cancelTimerNotification(String noteId) {
    if (_activeTimerNotifications.containsKey(noteId)) {
      _activeTimerNotifications[noteId]?.cancel();
      _activeTimerNotifications.remove(noteId);
      AwesomeNotifications().cancel(noteId.hashCode);
    }
  }
  
  // Cancel all timer notifications
  void cancelAllTimerNotifications() {
    for (final timer in _activeTimerNotifications.values) {
      timer.cancel();
    }
    _activeTimerNotifications.clear();
    AwesomeNotifications().cancelNotificationsByChannelKey(timerChannelKey);
  }
  
  // Handle notification actions
  static Future<void> handleNotificationAction(ReceivedAction receivedAction) async {
    // This is just a placeholder that will be handled by the app
    // The actual handling happens in NotesProvider.handleNotificationAction
  }
}