import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/notes_provider.dart';
import 'models/notification_service.dart';
import 'screens/notes_list_screen.dart';
import 'screens/note_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  final notificationService = NotificationService();
  notificationService.init().then((_) {
    // Request notification permissions after initialization
    notificationService.requestPermission();
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
