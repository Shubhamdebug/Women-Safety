import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Stay logged in across restarts: skip Login if a valid saved session exists.
  final loggedIn = await AppState.I.restoreSession();
  runApp(SafetyApp(
    initialRoute: loggedIn
        ? (AppState.I.setupDone ? Routes.home : Routes.permissions)
        : Routes.login,
  ));
}

class SafetyApp extends StatelessWidget {
  const SafetyApp({super.key, this.initialRoute = Routes.login});
  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KAVACH',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: initialRoute, // Login unless a saved session was restored
        routes: appRoutes,
      );
}
