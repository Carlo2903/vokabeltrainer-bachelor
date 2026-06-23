import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/training_service.dart';
import 'services/auth_service.dart';
import 'providers/vocabulary_provider.dart';
import 'providers/language_provider.dart';
import 'providers/session_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/backend_provider.dart';
import 'services/backend_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/app_shell.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/start_session_screen.dart';
import 'ui/screens/active_learning_screen.dart';
import 'ui/screens/voice_learning_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();
  await NotificationService().checkAndScheduleDailyReminder();
  runApp(const VokabelApp());
}

class VokabelApp extends StatelessWidget {
  const VokabelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final trainingService = TrainingService(firestoreService);
    final authService = AuthService();
    final backendService = BackendService();

    return MultiProvider(
      providers: [
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<BackendService>.value(value: backendService),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => LanguageProvider(firestoreService)),
        ChangeNotifierProvider(create: (_) => VocabularyProvider(firestoreService)),
        ChangeNotifierProvider(create: (_) => SessionProvider(trainingService)),
        ChangeNotifierProvider(
          create: (ctx) => BackendProvider(ctx.read<BackendService>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, GamificationProvider>(
          create: (context) => GamificationProvider(firestoreService, context.read<AuthProvider>()),
          update: (context, auth, previous) => previous ?? GamificationProvider(firestoreService, auth),
        ),
      ],
      child: MaterialApp(
        title: 'Vokabeltrainer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('de', 'DE'),
        supportedLocales: const [
          Locale('de', 'DE'),
          Locale('de'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _AuthGate(),
        routes: {
          '/session/start':  (context) => const StartSessionScreen(),
          '/session/active': (context) => const ActiveLearningScreen(),
          '/session/voice':  (context) => const VoiceLearningScreen(),
        },
      ),
    );
  }
}

/// Lauscht auf den Auth-State und zeigt AuthScreen oder AppShell
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncProviders();
  }

  void _syncProviders() {
    final authProvider = context.watch<AuthProvider>();
    final uid = authProvider.currentUser?.uid;

    // uid in Providers setzen, damit sie user-spezifische Daten laden
    final langProv = context.read<LanguageProvider>();
    final vocabProv = context.read<VocabularyProvider>();
    final sessionProv = context.read<SessionProvider>();
    final gamificationProv = context.read<GamificationProvider>();
    
    langProv.setUid(uid);
    vocabProv.setUid(uid);
    sessionProv.setGamificationProvider(gamificationProv);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    _syncProviders();

    // Initialer Ladescreen
    if (authProvider.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (authProvider.isLoggedIn) {
      return const AppShell();
    } else {
      return const AuthScreen();
    }
  }
}