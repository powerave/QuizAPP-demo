import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import '../features/profile/presentation/pages/profile_entry_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/quiz/presentation/pages/quiz_page.dart';
import '../features/profile/presentation/providers/profile_provider.dart';

class QuizApp extends ConsumerStatefulWidget {
  const QuizApp({super.key});

  @override
  ConsumerState<QuizApp> createState() => _QuizAppState();
}

class _QuizAppState extends ConsumerState<QuizApp> {
  late final _SessionGate sessionGate;
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    sessionGate = _SessionGate();

    ref.listenManual(profileProvider, (previous, next) {
      if (next.username.isEmpty && sessionGate.hasEntered) {
        sessionGate.leave();
      } else if (!next.isLoading &&
          next.username.isNotEmpty &&
          !sessionGate.hasEntered) {
        sessionGate.enter();
      }
    });

    router = GoRouter(
      initialLocation: '/entry',
      refreshListenable: sessionGate,
      redirect: (context, state) {
        if (!sessionGate.hasEntered && state.matchedLocation != '/entry') {
          return '/entry';
        }
        if (sessionGate.hasEntered && state.matchedLocation == '/entry') {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/entry',
          builder: (context, state) => ProfileEntryPage(
            onComplete: () {
              sessionGate.enter();
              context.go('/');
            },
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => HomePage(
                onJoinQuiz: () => context.go('/quiz'),
                onCreateQuiz: () => context.go('/quiz/create'),
                onOpenProfile: () => context.go('/profile'),
              ),
            ),
            GoRoute(
              path: '/quiz',
              builder: (context, state) =>
                  const QuizPage(initialMode: QuizLobbyMode.join),
            ),
            GoRoute(
              path: '/quiz/create',
              builder: (context, state) =>
                  const QuizPage(initialMode: QuizLobbyMode.create),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    router.dispose();
    sessionGate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QuizAPP',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2457A7),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFDCE8F7),
          onPrimaryContainer: Color(0xFF102D57),
          secondary: Color(0xFFE56A54),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFFBE0D9),
          onSecondaryContainer: Color(0xFF5A2118),
          tertiary: Color(0xFFF2B84B),
          onTertiary: Color(0xFF3D2900),
          surface: Color(0xFFFFFFFF),
          surfaceContainerHighest: Color(0xFFEAF0EE),
          onSurface: Color(0xFF172033),
          onSurfaceVariant: Color(0xFF5E6878),
          error: Color(0xFFC94C4C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFFD9E0E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFF2457A7), width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFFD9E0E5)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2457A7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFFEAF0EE),
          indicatorColor: Color(0xFFDCE8F7),
          selectedIconTheme: IconThemeData(color: Color(0xFF2457A7)),
          unselectedIconTheme: IconThemeData(color: Color(0xFF5E6878)),
          selectedLabelTextStyle: TextStyle(
            color: Color(0xFF102D57),
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: Color(0xFF5E6878),
            fontWeight: FontWeight.w600,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 70,
          backgroundColor: Color(0xFFEAF0EE),
          indicatorColor: Color(0xFFDCE8F7),
          elevation: 4,
          shadowColor: Color(0x33172033),
          surfaceTintColor: Color(0xFFEAF0EE),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: Color(0xFF5E6878)),
          ),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

class _SessionGate extends ChangeNotifier {
  bool hasEntered = false;

  void enter() {
    hasEntered = true;
    notifyListeners();
  }

  void leave() {
    hasEntered = false;
    notifyListeners();
  }
}
