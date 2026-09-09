import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/core/theme/tactical_theme.dart';
import 'package:military_calisthenics_women/core/theme/theme_controller.dart';

class StartupShellApp extends StatefulWidget {
  const StartupShellApp({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.isLoading = true,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? details;
  final bool isLoading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<StartupShellApp> createState() => _StartupShellAppState();
}

class _StartupShellAppState extends State<StartupShellApp> {
  late final Future<ThemeMode> _themeModeFuture;

  @override
  void initState() {
    super.initState();
    _themeModeFuture = ThemeController.loadStoredThemeMode();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThemeMode>(
      future: _themeModeFuture,
      initialData: ThemeMode.system,
      builder: (context, snapshot) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: TacticalTheme.dark(),
          darkTheme: TacticalTheme.dark(),
          themeMode: ThemeMode.dark,
          home: StartupScaffold(
            title: widget.title,
            message: widget.message,
            details: widget.details,
            isLoading: widget.isLoading,
            actionLabel: widget.actionLabel,
            onAction: widget.onAction,
          ),
        );
      },
    );
  }
}

class StartupScaffold extends StatelessWidget {
  const StartupScaffold({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.isLoading = true,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? details;
  final bool isLoading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: TacticalPalette.abyss,
        body: const SafeArea(
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: TacticalPalette.arctic,
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: TacticalPalette.abyss,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: TacticalPalette.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        details!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
