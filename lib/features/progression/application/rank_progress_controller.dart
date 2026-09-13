import 'package:flutter/foundation.dart';
import 'package:military_calisthenics_women/features/progression/domain/rank.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which rank the user has been shown the "Rank Unlocked" celebration
/// for. The rank itself is derived from workout count elsewhere; this
/// controller just remembers the highest rank that has been acknowledged so
/// the modal fires exactly once per promotion.
class RankProgressController extends ChangeNotifier {
  static const _kAcknowledgedIndex = 'rank_progress.acknowledged_index';

  int _acknowledgedIndex = 0;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Rank get acknowledgedRank =>
      Rank.values[_acknowledgedIndex.clamp(0, Rank.values.length - 1)];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _acknowledgedIndex =
          prefs.getInt(_kAcknowledgedIndex) ?? Rank.recruit.index;
    } catch (error) {
      debugPrint('RankProgressController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Returns the freshly-unlocked rank if [completedWorkouts] pushes the user
  /// above the currently-acknowledged tier, otherwise `null`. Recruit is the
  /// starting rank and never fires a celebration.
  Rank? pendingUnlock(int completedWorkouts) {
    final current = Rank.forWorkouts(completedWorkouts);
    if (current.index <= _acknowledgedIndex) return null;
    if (current == Rank.recruit) return null;
    return current;
  }

  Future<void> acknowledge(Rank rank) async {
    if (rank.index <= _acknowledgedIndex) return;
    _acknowledgedIndex = rank.index;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kAcknowledgedIndex, _acknowledgedIndex);
    } catch (error) {
      debugPrint('RankProgressController: persist failed — $error');
    }
  }
}
