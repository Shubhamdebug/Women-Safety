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
    // An SOS that never reached the server: open Home with the SOS status
    // screen on top, which sends it again.
    resumeSos: loggedIn && AppState.I.resumedPendingSos,
  ));
}

class SafetyApp extends StatelessWidget {
  const SafetyApp({super.key, this.initialRoute = Routes.login, this.resumeSos = false});
  final String initialRoute;
  final bool resumeSos;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KAVACH',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: initialRoute, // Login unless a saved session was restored
        onGenerateInitialRoutes: resumeSos
            ? (_) => <Route<dynamic>>[
                  MaterialPageRoute(
                      settings: const RouteSettings(name: Routes.home),
                      builder: appRoutes[Routes.home]!),
                  MaterialPageRoute(
                      settings: const RouteSettings(name: Routes.sosStatus),
                      builder: appRoutes[Routes.sosStatus]!),
                ]
            : null,
        routes: appRoutes,
      );
}
