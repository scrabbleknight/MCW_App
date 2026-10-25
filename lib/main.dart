import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:military_calisthenics_women/app/bootstrap_app.dart';
import 'package:military_calisthenics_women/core/funnel/install_attribution.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Which social post brought this install (Android), for purchases.
  unawaited(InstallAttribution.instance.load());
  runApp(const BootstrapApp());
}
