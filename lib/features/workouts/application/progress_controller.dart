import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the user's day-by-day completion of the mission and the gold stars
/// they've earned along the way. One star lands per completed day for now;
/// tiered rewards (rank promotions, unlocks) read from [stars] later.
class ProgressController extends ChangeNotifier {
  static const _kCompletedDays = 'progress.completed_days';
  static const _kStars = 'progress.stars';
  static const _kPendingCelebration = 'progress.pending_celebration_day';

  final Set<int> _completedDays = <int>{};
  int _stars = 0;
  int? _pendingCelebrationDay;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<int> get completedDays => Set.unmodifiable(_completedDays);
  int get stars => _stars;

  /// Set when a day is completed and cleared once the celebration modal has
  /// been shown. Lets the home screen surface the modal even if the user
  /// force-closes the app before we can pop it.
  int? get pendingCelebrationDay => _pendingCelebrationDay;

  bool isDayCompleted(int day) => _completedDays.contains(day);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _completedDays
        ..clear()
        ..addAll(
          (prefs.getStringList(_kCompletedDays) ?? const [])
              .map(int.tryParse)
              .whereType<int>(),
        );
      _stars = prefs.getInt(_kStars) ?? 0;
      final pending = prefs.getInt(_kPendingCelebration);
      _pendingCelebrationDay = (pending == null || pending <= 0) ? null : pending;
    } catch (error) {
      debugPrint('ProgressController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> markDayCompleted(int day) async {
    final firstTime = _completedDays.add(day);
    if (firstTime) {
      _stars += 1;
    }
    _pendingCelebrationDay = day;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kCompletedDays,
      _completedDays.map((d) => d.toString()).toList(),
    );
    await prefs.setInt(_kStars, _stars);
    await prefs.setInt(_kPendingCelebration, day);
  }

  Future<void> clearPendingCelebration() async {
    if (_pendingCelebrationDay == null) return;
    _pendingCelebrationDay = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingCelebration);
  }
}
