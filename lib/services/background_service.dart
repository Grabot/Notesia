import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note_model.dart';
import '../models/timer_utils.dart';

// Key for storing active timers in SharedPreferences
const String ACTIVE_TIMERS_KEY = 'active_timers';

// Service notification channel
const String NOTIFICATION_CHANNEL_ID = 'notesia_timer_service';
const String NOTIFICATION_CHANNEL_NAME = 'Notesia Timer Service';
const String NOTIFICATION_CHANNEL_DESC = 'Service to keep timer notifications running';

// Timer notification channel
const String TIMER_CHANNEL_ID = 'notesia_timer_channel';
const String TIMER_CHANNEL_NAME = 'Timer Notifications';
const String TIMER_CHANNEL_DESC = 'Shows active timer notifications';

// Service initialization
Future<void> initBackgroundService() async {
  // Create notification channel first
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    NOTIFICATION_CHANNEL_ID,
    NOTIFICATION_CHANNEL_NAME,
    description: NOTIFICATION_CHANNEL_DESC,
    importance: Importance.low,
  );

  // Create the channel before configuring the service
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
      
  // Also create the timer notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          TIMER_CHANNEL_ID,
          TIMER_CHANNEL_NAME,
          description: TIMER_CHANNEL_DESC,
          importance: Importance.high,
        ),
      );

  final service = FlutterBackgroundService();

  // Configure Android settings
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: NOTIFICATION_CHANNEL_ID,
      initialNotificationTitle: '',  // Empty title, notification will be invisible
      initialNotificationContent: '',  // Empty content, notification will be invisible
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

// iOS background handler (required but will not be executed)
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

// Main service entry point for background execution
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Create notification channel first (this is important to do before setAsForegroundService)
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    NOTIFICATION_CHANNEL_ID,
    NOTIFICATION_CHANNEL_NAME,
    description: NOTIFICATION_CHANNEL_DESC,
    importance: Importance.min,  // Minimum importance
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(serviceChannel);
  
  // Create timer notifications channel
  const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
    TIMER_CHANNEL_ID, 
    TIMER_CHANNEL_NAME,
    description: TIMER_CHANNEL_DESC,
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(timerChannel);

  // For Android, we need to use this to keep the service running
  if (service is AndroidServiceInstance) {
    try {
      // Use an empty notification for the background service
      service.setForegroundNotificationInfo(
        title: '',  // Empty title makes notification invisible
        content: '',  // Empty content makes notification invisible
      );
      service.setAsForegroundService();
      service.setAutoStartOnBootMode(true);
    } catch (e) {
      print('Error setting foreground service: $e');
    }
  }

  // State for tracking active timers
  Map<String, ActiveTimer> activeTimers = {};
  
  // Load active timers from storage if any
  await loadActiveTimers(activeTimers);

  // Setup periodic timer to update notifications every second
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          updateTimerNotifications(flutterLocalNotificationsPlugin, activeTimers);
        }
      }
    } catch (e) {
      print('Error in timer update: $e');
    }
  });

  // Handle commands from the main app
  service.on('startTimer').listen((event) async {
    if (event != null) {
      try {
        // Add or update timer
        final noteId = event['noteId'] as String;
        final title = event['title'] as String;
        final timerDuration = event['timerDuration'] as int;
        final startTime = event['startTime'] as int; // Get the startTime from the event
        
        // Debug print to ensure we're receiving the data
        print('Background service received startTimer: $noteId, $title, $timerDuration, $startTime');

        activeTimers[noteId] = ActiveTimer(
          id: noteId,
          title: title,
          duration: timerDuration,
          startTime: startTime,
        );

        // Save active timers to storage
        await saveActiveTimers(activeTimers);
        
        // Show the notification immediately
        _showTimerRunningNotification(
          flutterLocalNotificationsPlugin, 
          activeTimers[noteId]!, 
          activeTimers[noteId]!.getRemainingTime()
        );
      } catch (e) {
        print('Error starting timer: $e');
      }
    }
  });

  service.on('stopTimer').listen((event) async {
    if (event != null) {
      final noteId = event['noteId'] as String;
      if (activeTimers.containsKey(noteId)) {
        activeTimers.remove(noteId);
        flutterLocalNotificationsPlugin.cancel(noteId.hashCode);

        // Save active timers to storage
        await saveActiveTimers(activeTimers);
      }
    }
  });

  service.on('stopAllTimers').listen((event) async {
    activeTimers.clear();
    flutterLocalNotificationsPlugin.cancelAll();

    // Save active timers to storage
    await saveActiveTimers(activeTimers);
  });

  // Listen for app check-ins to report back active timers
  service.on('checkActiveTimers').listen((event) {
    final activeTimersData = activeTimers.map(
      (key, timer) => MapEntry(
        key,
        {
          'id': timer.id,
          'title': timer.title,
          'duration': timer.duration,
          'startTime': timer.startTime,
          'remainingTime': timer.getRemainingTime(),
        },
      ),
    );

    service.invoke(
      'updateActiveTimers',
      {'timers': activeTimersData},
    );
  });
}

void updateTimerNotifications(
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  Map<String, ActiveTimer> activeTimers,
) async {
  final currentTime = DateTime.now().millisecondsSinceEpoch;
  final List<String> completedTimers = [];

  activeTimers.forEach((noteId, timer) {
    // Calculate remaining time
    final elapsedMillis = currentTime - timer.startTime;
    final elapsedSeconds = elapsedMillis ~/ 1000;
    final remainingSeconds = timer.duration - elapsedSeconds;

    if (remainingSeconds <= 0) {
      // Timer completed
      completedTimers.add(noteId);
      _showTimerCompletedNotification(flutterLocalNotificationsPlugin, timer);
    } else {
      // Timer still running
      _showTimerRunningNotification(flutterLocalNotificationsPlugin, timer, remainingSeconds);
    }
  });

  // Remove completed timers
  for (final id in completedTimers) {
    activeTimers.remove(id);
  }

  // Save active timers to storage if any were completed
  if (completedTimers.isNotEmpty) {
    await saveActiveTimers(activeTimers);
  }
}

void _showTimerRunningNotification(
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  ActiveTimer timer,
  int remainingSeconds,
) {
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    TIMER_CHANNEL_ID,
    TIMER_CHANNEL_NAME,
    channelDescription: TIMER_CHANNEL_DESC,
    importance: Importance.high,
    priority: Priority.high,
    playSound: false,
    enableVibration: false,
    onlyAlertOnce: true,
    ongoing: true,
    autoCancel: false,
    visibility: NotificationVisibility.public, // Make sure it's visible on lock screen
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  flutterLocalNotificationsPlugin.show(
    timer.id.hashCode,
    "Timer: ${timer.title}",
    TimerUtils.formatDuration(remainingSeconds),
    notificationDetails,
    payload: timer.id,
  );
}

void _showTimerCompletedNotification(
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  ActiveTimer timer,
) {
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    TIMER_CHANNEL_ID,
    TIMER_CHANNEL_NAME,
    channelDescription: TIMER_CHANNEL_DESC,
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    autoCancel: true,
    visibility: NotificationVisibility.public,
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  flutterLocalNotificationsPlugin.show(
    timer.id.hashCode,
    'Timer Finished',
    '${timer.title} timer has completed!',
    notificationDetails,
    payload: timer.id,
  );
}

// Save active timers to SharedPreferences
Future<void> saveActiveTimers(Map<String, ActiveTimer> activeTimers) async {
  final prefs = await SharedPreferences.getInstance();
  final timerData = activeTimers.map(
    (key, timer) => MapEntry(
      key,
      {
        'id': timer.id,
        'title': timer.title,
        'duration': timer.duration,
        'startTime': timer.startTime,
      },
    ),
  );
  await prefs.setString(ACTIVE_TIMERS_KEY, jsonEncode(timerData));
}

// Load active timers from SharedPreferences
Future<void> loadActiveTimers(Map<String, ActiveTimer> activeTimers) async {
  final prefs = await SharedPreferences.getInstance();
  final String? timersJson = prefs.getString(ACTIVE_TIMERS_KEY);
  
  if (timersJson != null && timersJson.isNotEmpty) {
    final Map<String, dynamic> timers = jsonDecode(timersJson);
    timers.forEach((key, value) {
      activeTimers[key] = ActiveTimer(
        id: value['id'],
        title: value['title'],
        duration: value['duration'],
        startTime: value['startTime'],
      );
    });
  }
}

// Class to represent an active timer
class ActiveTimer {
  final String id;
  final String title;
  final int duration;
  final int startTime;

  ActiveTimer({
    required this.id,
    required this.title,
    required this.duration,
    required this.startTime,
  });

  int getRemainingTime() {
    final elapsedMillis = DateTime.now().millisecondsSinceEpoch - startTime;
    final elapsedSeconds = elapsedMillis ~/ 1000;
    return duration - elapsedSeconds > 0 ? duration - elapsedSeconds : 0;
  }
}