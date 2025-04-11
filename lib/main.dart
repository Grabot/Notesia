import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'models/notes_provider.dart';
import 'models/notification_service.dart';
import 'screens/notes_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  final notificationService = NotificationService();
  notificationService.init().then((_) {
    // Initialize any notification setup needed
  });
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final NotesProvider _notesProvider = NotesProvider();

  // This will be used to handle notification actions
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Request notification permissions
    _notesProvider.notificationService.requestPermission();
    
    // Set up notification handlers
    AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelGroupKey: 'timer_channel_group',
          channelKey: NotificationService.timerChannelKey,
          channelName: 'Timer Notifications',
          channelDescription: 'Shows active timer notifications',
          defaultColor: Colors.teal,
          ledColor: Colors.teal,
          importance: NotificationImportance.High,
          playSound: false,
          enableVibration: false,
        )
      ],
      debug: true,
    );
    
    // Set up notification action listener
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
  }
  
  // This static method allows it to be called from anywhere in the app
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    if (receivedAction.channelKey == NotificationService.timerChannelKey) {
      final String buttonKey = receivedAction.buttonKeyPressed;
      
      // Get the current context using navigatorKey
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Get the provider instance
        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
        
        // Handle notification action
        if (buttonKey.isNotEmpty) {
          await notesProvider.handleNotificationAction(
            receivedAction.id!,
            buttonKey,
          );
        }
      }
    }
  }
  
  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _notesProvider,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Notesia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const NotesListScreen(),
      ),
    );
  }
}
