class AppConfig {
  const AppConfig._();

  static const quizServerUrl = String.fromEnvironment(
    'QUIZ_SERVER_URL',
    defaultValue: 'wss://localhost/ws',
  );
}
