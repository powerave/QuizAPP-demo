import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quizapp/app/app.dart';
import 'package:quizapp/features/profile/data/repositories/profile_repository.dart';
import 'package:quizapp/features/profile/domain/models/profile.dart';
import 'package:quizapp/features/profile/presentation/providers/profile_provider.dart';

class _TestProfileRepository extends ProfileRepository {
  Profile current = const Profile(isLoading: false);

  @override
  Profile get profile => current;

  @override
  Future<Profile> load() async => current;

  @override
  Future<Profile> authenticate({
    required String username,
    required String password,
    required String displayName,
    required bool createAccount,
  }) async {
    current = current.copyWith(
      profileId: 'test-profile',
      username: username,
      displayName: createAccount ? displayName : 'Nina',
      isLoading: false,
    );
    return current;
  }
}

void main() {
  ProviderScope testApp() {
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_TestProfileRepository()),
      ],
      child: const QuizApp(),
    );
  }

  Future<void> enterApp(WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'nina42');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'Nina');
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche le rail de navigation sur desktop', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await enterApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('affiche la barre de navigation sur mobile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await enterApp(tester);

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('impose le choix du pseudo avant l’accueil', (WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue sur QuizAPP'), findsOneWidget);
    expect(find.text('Nom d’utilisateur'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Nom d’affichage'), findsOneWidget);
    expect(find.text('Salut Alex'), findsNothing);

    await enterApp(tester);

    expect(find.text('Salut Nina'), findsOneWidget);
    expect(find.text('Rejoindre une partie'), findsOneWidget);
  });

  testWidgets('navigue vers le quiz après identification', (WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await enterApp(tester);

    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun salon disponible.'), findsOneWidget);
    expect(find.text('Créer'), findsOneWidget);
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(find.text('Créer le salon'), findsOneWidget);
  });

  testWidgets('ouvre le mode création depuis l’accueil', (WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await enterApp(tester);

    await tester.tap(find.text('Créer une partie'));
    await tester.pumpAndSettle();
    expect(find.text('Créer le salon'), findsOneWidget);
  });
}
