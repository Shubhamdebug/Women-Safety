import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'config/theme.dart';

void main() => runApp(const SafetyApp());

class SafetyApp extends StatelessWidget {
  const SafetyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KAVACH',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: Routes.login, // workflow start -> S01 Login
        routes: appRoutes,
      );
}
