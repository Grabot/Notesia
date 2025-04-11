import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/timer_utils.dart';

// Task names
const String UPDATE_TIMER_TASK = 'updateTimerTask';
const String ACTIVE_TIMERS_KEY = 'notesia_active_timers';
const String NOTIFICATION_CHANNEL_ID = 'notesia_timer_channel';
const String NOTIFICATION_CHANNEL_NAME = 'Timer Notifications';

// Register periodic task for timer updates
Future<void> registerTimerTasks() async {
  // Register periodic task to update timer notifications
  await Workmanager().registerPeriodicTask(
    'notesiaTimerUpdate',
    UPDATE_TIMER_TASK,
    frequency: const Duration(seconds: 900),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(seconds: 900),
  );
}

// Cancel background tasks
Future<void> cancelBackgroundTasks() async {
  await Workmanager().cancelAll();
}

// Background task handler - must be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == UPDATE_TIMER_TASK) {
        await _updateTimerNotifications();
      } else {
        print('Unknown task: $taskName');
        return Future.value(false);
      }
      return Future.value(true);
    } catch (e) {
      print('Error executing background task: $e');
      return Future.value(false);
    }
  });
}

// Update timer notifications in the background
Future<void> _updateTimerNotifications() async {
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  
  // Initialize notification plugin for this isolate
  await _initializeNotifications(notifications);
  
  // Load active timers
  final activeTimers = await _loadActiveTimers();
  if (activeTimers.isEmpty) {
    return; // No active timers
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  final List<String> completedTimers = [];
  final Map<String, dynamic> updatedTimers = {};

  // Process each timer
  activeTimers.forEach((id, timer) {
    final startTime = timer['startTime'];
    final duration = timer['duration'];
    final title = timer['title'];
    
    // Calculate remaining time
    final elapsedMillis = now - startTime;
    final elapsedSeconds = elapsedMillis ~/ 1000;
    final remainingSeconds = duration - elapsedSeconds;

    // Debug
    print('Updating notification for $title: $remainingSeconds seconds remaining');
    
    if (remainingSeconds <= 0) {
      // Timer completed
      completedTimers.add(id);
      _showTimerCompletedNotification(notifications, id, title);
    } else {
      // Timer still running
      _showTimerRunningNotification(notifications, id, title, remainingSeconds);
      
      // Keep this timer in the updated list
      updatedTimers[id] = timer;
    }
  });
  
  // Save updated timers (without completed ones)
  await _saveActiveTimers(updatedTimers);
}

// Initialize notifications plugin
Future<void> _initializeNotifications(FlutterLocalNotificationsPlugin notifications) async {
  const AndroidInitializationSettings androidSettings = 
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iOSSettings,
  );
  
  await notifications.initialize(initSettings);
  
  // Create notification channels
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NOTIFICATION_CHANNEL_ID,
        NOTIFICATION_CHANNEL_NAME,
        description: 'Shows active timer notifications',
        importance: Importance.high,
      ),
    );
  }
}

// Show a running timer notification
void _showTimerRunningNotification(
  FlutterLocalNotificationsPlugin notifications,
  String id,
  String title,
  int remainingSeconds
) {
  final String formattedTime = TimerUtils.formatDuration(remainingSeconds);
  
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    NOTIFICATION_CHANNEL_ID,
    NOTIFICATION_CHANNEL_NAME,
    channelDescription: 'Shows active timer notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: false,
    enableVibration: false,
    onlyAlertOnce: true,
    ongoing: true,
    autoCancel: false,
    visibility: NotificationVisibility.public,
  );
  
  final NotificationDetails details = NotificationDetails(android: androidDetails);
  
  notifications.show(
    id.hashCode,
    title,
    formattedTime, // The timer value
    details,
    payload: id,
  );
}

// Show timer completed notification
void _showTimerCompletedNotification(
  FlutterLocalNotificationsPlugin notifications,
  String id,
  String title
) {
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    NOTIFICATION_CHANNEL_ID,
    NOTIFICATION_CHANNEL_NAME,
    channelDescription: 'Shows active timer notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    autoCancel: true,
    visibility: NotificationVisibility.public,
  );
  
  final NotificationDetails details = NotificationDetails(android: androidDetails);
  
  notifications.show(
    id.hashCode,
    'Timer Finished',
    '$title timer has completed!',
    details,
    payload: id,
  );
}

// Load active timers from shared preferences
Future<Map<String, dynamic>> _loadActiveTimers() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final timersJson = prefs.getString(ACTIVE_TIMERS_KEY);
    
    if (timersJson != null && timersJson.isNotEmpty) {
      return Map<String, dynamic>.from(json.decode(timersJson));
    }
  } catch (e) {
    print('Error loading active timers: $e');
  }
  
  return {};
}

// Save active timers to shared preferences
Future<void> _saveActiveTimers(Map<String, dynamic> timers) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ACTIVE_TIMERS_KEY, json.encode(timers));
  } catch (e) {
    print('Error saving active timers: $e');
  }
}

// Add a timer to the active timers list
Future<void> addActiveTimer(String id, String title, int duration) async {
  final prefs = await SharedPreferences.getInstance();
  final timersJson = prefs.getString(ACTIVE_TIMERS_KEY);
  
  final Map<String, dynamic> timers = timersJson != null && timersJson.isNotEmpty
      ? Map<String, dynamic>.from(json.decode(timersJson))
      : {};
  
  timers[id] = {
    'id': id,
    'title': title,
    'duration': duration,
    'startTime': DateTime.now().millisecondsSinceEpoch,
  };
  
  await prefs.setString(ACTIVE_TIMERS_KEY, json.encode(timers));
  
  // Register timer tasks if this is our first timer
  if (timers.length == 1) {
    await registerTimerTasks();
  }
}

// Remove a timer from the active timers list
Future<void> removeActiveTimer(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final timersJson = prefs.getString(ACTIVE_TIMERS_KEY);
  
  if (timersJson != null && timersJson.isNotEmpty) {
    final Map<String, dynamic> timers = Map<String, dynamic>.from(json.decode(timersJson));
    
    // Remove the timer
    timers.remove(id);
    
    // Save updated timers
    await prefs.setString(ACTIVE_TIMERS_KEY, json.encode(timers));
    
    // If no timers left, cancel background tasks
    if (timers.isEmpty) {
      await cancelBackgroundTasks();
    }
  }
  
  // Cancel the notification
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  await _initializeNotifications(notifications);
  await notifications.cancel(id.hashCode);
}

// Remove all active timers
Future<void> removeAllActiveTimers() async {
  // Clear the stored timers
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(ACTIVE_TIMERS_KEY, json.encode({}));
  
  // Cancel background tasks
  await cancelBackgroundTasks();
  
  // Cancel all notifications
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  await _initializeNotifications(notifications);
  await notifications.cancelAll();
}