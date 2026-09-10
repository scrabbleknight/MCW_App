import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeightEntry {
  const WeightEntry({required this.date, required this.kg});

  final DateTime date;
  final double kg;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'kg': kg,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        date: DateTime.parse(json['date'] as String),
        kg: (json['kg'] as num).toDouble(),
      );
}

/// Persists the user's weight entries and their height (for BMI). All in
/// SharedPreferences — keep it simple until we need something server-backed.
class BodyProgressController extends ChangeNotifier {
  static const _kEntries = 'body.weight_entries';
  static const _kHeightCm = 'body.height_cm';
  static const _kGoalKg = 'body.goal_kg';

  final List<WeightEntry> _entries = [];
  double? _heightCm;
  double? _goalKg;

  List<WeightEntry> get entries {
    final sorted = [..._entries]..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  double? get heightCm => _heightCm;
  double? get goalKg => _goalKg;

  WeightEntry? get latest => entries.isEmpty ? null : entries.first;
  WeightEntry? get earliest => entries.isEmpty ? null : entries.last;

  double? get bmi {
    final w = latest?.kg;
    final h = _heightCm;
    if (w == null || h == null || h <= 0) return null;
    final m = h / 100.0;
    return w / (m * m);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kEntries) ?? const [];
      _entries
        ..clear()
        ..addAll(raw
            .map((s) => WeightEntry.fromJson(
                json.decode(s) as Map<String, dynamic>))
            .toList());
      _heightCm = prefs.getDouble(_kHeightCm);
      _goalKg = prefs.getDouble(_kGoalKg);
    } catch (error) {
      debugPrint('BodyProgressController: load failed — $error');
    } finally {
      notifyListeners();
    }
  }

  Future<void> addEntry(WeightEntry entry) async {
    _entries.add(entry);
    notifyListeners();
    await _persistEntries();
  }

  Future<void> removeEntry(WeightEntry entry) async {
    _entries.removeWhere(
        (e) => e.date == entry.date && e.kg == entry.kg);
    notifyListeners();
    await _persistEntries();
  }

  Future<void> setHeight(double cm) async {
    _heightCm = cm;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kHeightCm, cm);
  }

  Future<void> setGoal(double kg) async {
    _goalKg = kg;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kGoalKg, kg);
  }

  /// Backfill any missing fields from the onboarding answers so the profile
  /// screen shows the numbers the user just typed in even before they've
  /// logged their first "Add weight" entry. Only fills a field that is
  /// currently empty — never overwrites a value the user has already set.
  Future<void> seedIfEmpty({
    double? weightKg,
    double? heightCm,
    double? goalKg,
  }) async {
    var changed = false;
    if (_entries.isEmpty && weightKg != null && weightKg > 0) {
      _entries.add(WeightEntry(date: DateTime.now(), kg: weightKg));
      changed = true;
    }
    if (_heightCm == null && heightCm != null && heightCm > 0) {
      _heightCm = heightCm;
      changed = true;
    }
    if (_goalKg == null && goalKg != null && goalKg > 0) {
      _goalKg = goalKg;
      changed = true;
    }
    if (!changed) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_heightCm != null) await prefs.setDouble(_kHeightCm, _heightCm!);
    if (_goalKg != null) await prefs.setDouble(_kGoalKg, _goalKg!);
    await _persistEntries();
  }

  Future<void> _persistEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kEntries,
      _entries.map((e) => json.encode(e.toJson())).toList(),
    );
  }
}
