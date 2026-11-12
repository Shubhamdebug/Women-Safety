import 'package:flutter/material.dart';
import '../screens/s01_login.dart';
import '../screens/s02_register.dart';
import '../screens/s03_home.dart';
import '../screens/s04_sos_countdown.dart';
import '../screens/s05_sos_status.dart';
import '../screens/s06_live_sharing.dart';
import '../screens/s07_contacts.dart';
import '../screens/s08_contact_form.dart';
import '../screens/s09_profile.dart';
import '../screens/s10_history.dart';
import '../screens/s11_safety_map.dart';
import '../screens/s12_report.dart';
import '../screens/s13_permissions.dart';

/// Route names follow the S-numbers in the workflow diagram.
class Routes {
  static const login = '/'; // S01
  static const register = '/register'; // S02
  static const home = '/home'; // S03
  static const sosCountdown = '/sos-countdown'; // S04
  static const sosStatus = '/sos-status'; // S05
  static const liveSharing = '/live-sharing'; // S06
  static const contacts = '/contacts'; // S07
  static const contactForm = '/contact-form'; // S08
  static const profile = '/profile'; // S09
  static const history = '/history'; // S10
  static const map = '/map'; // S11
  static const report = '/report'; // S12
  static const permissions = '/permissions'; // S13
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.login: (_) => const S01Login(),
  Routes.register: (_) => const S02Register(),
  Routes.home: (_) => const S03Home(),
  Routes.sosCountdown: (_) => const S04SosCountdown(),
  Routes.sosStatus: (_) => const S05SosStatus(),
  Routes.liveSharing: (_) => const S06LiveSharing(),
  Routes.contacts: (_) => const S07Contacts(),
  Routes.contactForm: (_) => const S08ContactForm(),
  Routes.profile: (_) => const S09Profile(),
  Routes.history: (_) => const S10History(),
  Routes.map: (_) => const S11SafetyMap(),
  Routes.report: (_) => const S12Report(),
  Routes.permissions: (_) => const S13Permissions(),
};
