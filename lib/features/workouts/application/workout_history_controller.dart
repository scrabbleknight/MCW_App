import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which surface a completed session came from — drives the placeholder
/// artwork on the history row.
enum WorkoutHistoryKind { mission, training, custom }

/// One completed workout session, persisted so the profile's Workout History
/// screen can list every session (not exercise) the user has finished.
@immutable
class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.id,
    required this.completedAt,
    required this.title,
    required this.minutes,
    required this.calories,
    required this.kind,
    this.accentIndex = 0,
  });

  final String id;
  final DateTime completedAt;
  final String title;
  final int minutes;
  final int calories;
  final WorkoutHistoryKind kind;

  /// Deterministic tint for the mission/training placeholder tiles so
  /// consecutive rows don't look identical. Unused for custom (fixed art).
  final int accentIndex;

  Map<String, dynamic> toJson() => {
        'id': id,
        'completedAt': completedAt.toIso8601String(),
        'title': title,
        'minutes': minutes,
        'calories': calories,
        'kind': kind.name,
        'accentIndex': accentIndex,
      };

  static WorkoutHistoryEntry? fromJson(Map<String, dynamic> json) {
    try {
      return WorkoutHistoryEntry(
        id: json['id'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        title: json['title'] as String,
        minutes: (json['minutes'] as num).toInt(),
        calories: (json['calories'] as num).toInt(),
        kind: WorkoutHistoryKind.values.byName(json['kind'] as String),
        accentIndex: (json['accentIndex'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Append-only log of finished sessions. Newest first when read.
class WorkoutHistoryController extends ChangeNotifier {
  static const _kKey = 'workout_history.entries.v1';

  final List<WorkoutHistoryEntry> _entries = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Newest-first list, safe to hand to a ListView.
  List<WorkoutHistoryEntry> get entries {
    final copy = List<WorkoutHistoryEntry>.from(_entries);
    copy.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return List.unmodifiable(copy);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kKey) ?? const <String>[];
      _entries.clear();
      for (final s in raw) {
        final decoded = jsonDecode(s);
        if (decoded is Map<String, dynamic>) {
          final entry = WorkoutHistoryEntry.fromJson(decoded);
          if (entry != null) _entries.add(entry);
        }
      }
    } catch (error) {
      debugPrint('WorkoutHistoryController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> record(WorkoutHistoryEntry entry) async {
    _entries.add(entry);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kKey,
      _entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
