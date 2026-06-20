import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/patient/bloc/patient_bloc.dart';
import 'features/doctor/bloc/doctor_bloc.dart';
import 'features/lab/bloc/lab_bloc.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler only runs on mobile
  if (!kIsWeb) await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (no-op on web — use compile-time config instead)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env not available on web — values fall back to empty strings
  }

  // Lock to portrait on mobile only
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // System UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'https://rucxpxxqujwgriknnxbh.supabase.co',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] != null &&
            dotenv.env['SUPABASE_ANON_KEY']!.isNotEmpty &&
            dotenv.env['SUPABASE_ANON_KEY'] != 'YOUR_ANON_KEY_HERE'
        ? dotenv.env['SUPABASE_ANON_KEY']!
        : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ1Y3hweHhxdWp3Z3Jpa25ueGJoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTk1NDUwMCwiZXhwIjoyMDk3NTMwNTAwfQ.mqw7jbYxBQJTIm5LWAGIInhhhIAoqk-q35xY_wQDuF0',
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Initialize Firebase — gracefully skip on web if no config is present
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      // Initialize Notification Service (FCM + local)
      await NotificationService.instance.initialize();
    } catch (e) {
      // Firebase not configured (e.g. no google-services.json)
      // App still works — Supabase Realtime handles real-time notifications
      debugPrint('⚠️ Firebase init skipped: $e');
    }
  } else {
    // Initialize Notification Service for web (will gracefully skip FCM/local inits)
    await NotificationService.instance.initialize();
  }

  runApp(const CareCryptApp());
}

class CareCryptApp extends StatelessWidget {
  const CareCryptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<PatientBloc>(create: (_) => PatientBloc()),
        BlocProvider<DoctorBloc>(create: (_) => DoctorBloc()),
        BlocProvider<LabBloc>(create: (_) => LabBloc()),
        BlocProvider<PharmacyBloc>(create: (_) => PharmacyBloc()),
        BlocProvider<NurseBloc>(create: (_) => NurseBloc()),
      ],
      child: MaterialApp.router(
        title: 'CareCrypt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
