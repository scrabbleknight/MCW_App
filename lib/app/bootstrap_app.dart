import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:military_calisthenics_women/app/mcw_app.dart';
import 'package:military_calisthenics_women/app/startup_shell.dart';
import 'package:military_calisthenics_women/firebase_options.dart';

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  static const _envLoadTimeout = Duration(seconds: 2);
  static const _firebaseInitTimeout = Duration(seconds: 8);

  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadEnvironment();
    // Await Firebase warm-up before the app runs — otherwise controllers
    // that touch FirebaseAuth / Firestore during their initial `load()`
    // hit "No Firebase App '[DEFAULT]' has been created". The call already
    // has an 8-second timeout so a bad network can't wedge boot.
    await _warmUpFirebase();
  }

  Future<void> _loadEnvironment() async {
    try {
      await dotenv
          .load(fileName: '.env', isOptional: true)
          .timeout(_envLoadTimeout);
    } on TimeoutException {
      debugPrint('MCW bootstrap: .env load timed out, continuing.');
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'bootstrap',
          context: ErrorDescription('while loading the app environment'),
        ),
      );
    }
  }

  Future<void> _warmUpFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(_firebaseInitTimeout);
    } on TimeoutException {
      debugPrint('MCW bootstrap: Firebase init timed out, continuing offline.');
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'bootstrap',
          context: ErrorDescription('while warming up Firebase'),
        ),
      );
    }
  }

  void _retryBootstrap() {
    setState(() {
      _bootstrapFuture = _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const StartupShellApp(
            title: 'Opening Military Calisthenics',
            message: 'Loading your plan, workouts, and progress.',
          );
        }

        if (snapshot.hasError) {
          return StartupShellApp(
            title: 'Launch failed',
            message:
                'Military Calisthenics hit a startup error before the first screen loaded.',
            details: snapshot.error.toString(),
            isLoading: false,
            actionLabel: 'Try again',
            onAction: _retryBootstrap,
          );
        }

        return const McwApp();
      },
    );
  }
}
