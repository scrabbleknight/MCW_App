import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks partial completion of Training-tab routines. Keyed by the synthetic
/// [PlanDay.dayIndex] the training catalogue assigns (10 000+), so it never
/// collides with the 21-day mission progress in [ProgressController].
///
/// A value in [1, 99] means the user started the routine and quit before
/// finishing — the routine card swaps its stat chips for a progress bar and
/// CONTINUE button. 0 (or missing) means untouched; 100 means completed and
/// is cleared so the next open starts fresh.
class TrainingProgressController extends ChangeNotifier {
  static const _kPrefix = 'training_progress.';

  final Map<int, int> _percentByDay = <int, int>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  int percentFor(int dayIndex) => _percentByDay[dayIndex] ?? 0;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _percentByDay.clear();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_kPrefix)) continue;
        final day = int.tryParse(key.substring(_kPrefix.length));
        if (day == null) continue;
        final v = prefs.getInt(key) ?? 0;
        if (v > 0 && v < 100) _percentByDay[day] = v;
      }
    } catch (error) {
      debugPrint('TrainingProgressController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setPercent(int dayIndex, int percent) async {
    final clamped = percent.clamp(0, 100);
    if (clamped <= 0 || clamped >= 100) {
      _percentByDay.remove(dayIndex);
    } else {
      _percentByDay[dayIndex] = clamped;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefix$dayIndex';
    if (clamped <= 0 || clamped >= 100) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, clamped);
    }
  }

  Future<void> clear(int dayIndex) => setPercent(dayIndex, 0);
}
