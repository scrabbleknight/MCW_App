import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:military_calisthenics_women/app/bootstrap_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BootstrapApp());
}
