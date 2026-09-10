import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the set of workout days the user has starred (favorited via the
/// heart button on the workout-day screen). The Custom tab renders these back
/// as a "Starred" section.
class StarredWorkoutsController extends ChangeNotifier {
  static const _kKey = 'workouts.starred.ids';

  final Set<String> _starred = <String>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<String> get starred => Set.unmodifiable(_starred);

  static String keyFor({required int dayIndex, required String title}) =>
      'day-$dayIndex::$title';

  bool isStarred(String key) => _starred.contains(key);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _starred
        ..clear()
        ..addAll(prefs.getStringList(_kKey) ?? const []);
    } catch (error) {
      debugPrint('StarredWorkoutsController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> toggle(String key) async {
    if (!_starred.add(key)) {
      _starred.remove(key);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, _starred.toList());
  }
}
