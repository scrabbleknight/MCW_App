import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:military_calisthenics_women/features/custom_workout/application/custom_workout_builder.dart';
import 'package:military_calisthenics_women/features/plan/domain/exercise.dart';
import 'package:military_calisthenics_women/features/plan/domain/plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One user-built workout — just the filter selections, so the day itself
/// can be regenerated from the current catalogue on demand.
class CustomWorkoutSpec {
  const CustomWorkoutSpec({
    required this.id,
    required this.title,
    required this.level,
    required this.areas,
    required this.positions,
  });

  final String id;
  final String title;
  final ExerciseDifficulty level;
  final Set<FocusArea> areas;
  final Set<PositionGroup> positions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'level': level.name,
        'areas': areas.map((a) => a.name).toList(),
        'positions': positions.map((p) => p.name).toList(),
      };

  static CustomWorkoutSpec? fromJson(Map<String, dynamic> json) {
    try {
      return CustomWorkoutSpec(
        id: json['id'] as String,
        title: json['title'] as String,
        level: ExerciseDifficulty.values.byName(json['level'] as String),
        areas: {
          for (final n in (json['areas'] as List).cast<String>())
            FocusArea.values.byName(n),
        },
        positions: {
          for (final n in (json['positions'] as List).cast<String>())
            PositionGroup.values.byName(n),
        },
      );
    } catch (_) {
      return null;
    }
  }

  PlanDay? build() => buildCustomWorkoutDay(
        level: level,
        areas: areas,
        positions: positions,
      );
}

/// Persists the user's saved custom workouts and exposes them to the Custom
/// tab. Backed by SharedPreferences, mirroring [StarredWorkoutsController].
class CustomWorkoutsController extends ChangeNotifier {
  static const _kKey = 'workouts.custom.specs.v1';

  final List<CustomWorkoutSpec> _specs = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<CustomWorkoutSpec> get specs => List.unmodifiable(_specs);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kKey) ?? const <String>[];
      _specs.clear();
      for (final entry in raw) {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) {
          final spec = CustomWorkoutSpec.fromJson(decoded);
          if (spec != null) _specs.add(spec);
        }
      }
    } catch (error) {
      debugPrint('CustomWorkoutsController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> add(CustomWorkoutSpec spec) async {
    _specs.insert(0, spec);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _specs.removeWhere((s) => s.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kKey,
      _specs.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }
}
