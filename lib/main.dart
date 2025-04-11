import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'models/notes_provider.dart';
import 'models/notification_service.dart';
import 'screens/notes_list_screen.dart';
import 'screens/note_detail_screen.dart';
import 'services/background_task.dart';

// Initialize services before the app starts
Future<void> initializeServices() async {
  // Initialize Workmanager first (only once)
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  
  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.init();
  
  // Request notification permissions
  await notificationService.requestPermission();
}

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await initializeServices();
  
  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final NotesProvider _notesProvider = NotesProvider();
  final NotificationService _notificationService = NotificationService();

  // This will be used to handle notification actions
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize notes provider
    _notesProvider.init();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _notificationService.syncWithBackgroundService();
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
