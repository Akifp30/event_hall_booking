import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/booking_draft.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'theme.dart';

/// Entry point of the Event Hall Booking app.
/// 1. Initialise Firebase
/// 2. Register app-wide state (Provider)
/// 3. Start the app with go_router navigation
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final auth = AuthService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<BookingDraft>(create: (_) => BookingDraft()),
      ],
      child: HallBookApp(auth: auth),
    ),
  );
}

class HallBookApp extends StatefulWidget {
  final AuthService auth;
  const HallBookApp({super.key, required this.auth});

  @override
  State<HallBookApp> createState() => _HallBookAppState();
}

class _HallBookAppState extends State<HallBookApp> {
  late final GoRouter _router = createRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HallBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
