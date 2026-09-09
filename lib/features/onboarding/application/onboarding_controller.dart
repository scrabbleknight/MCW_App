import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks completion of the onboarding flow and holds the in-memory answers
/// the user provides during it.
///
/// Answers are kept in a loosely-typed [Map] so the same controller can back
/// any product's onboarding without a schema change. Persist the ones you
/// care about at [markCompleted] time or as each step is answered — the map
/// is intentionally not written to disk here.
class OnboardingController extends ChangeNotifier {
  static const _completedKey = 'onboarding_completed';

  /// When true, onboarding replays on every launch regardless of the stored
  /// completion flag — handy while iterating on the flow. Now that the
  /// post-onboarding home is built, real completion state is honoured.
  static const _forceReplayOnboarding = false;

  bool _completed = false;
  bool _loaded = false;
  final Map<String, Object?> _answers = <String, Object?>{};

  bool get hasCompletedOnboarding =>
      _forceReplayOnboarding ? false : _completed;
  bool get isLoaded => _loaded;
  Map<String, Object?> get answers => Map.unmodifiable(_answers);

  T? answerFor<T>(String key) => _answers[key] as T?;

  void setAnswer(String key, Object? value) {
    _answers[key] = value;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_forceReplayOnboarding) {
        // Also wipe any stale stored flag so once we flip the override off,
        // the user starts from a clean slate rather than inheriting a value
        // written during development.
        await prefs.remove(_completedKey);
        _completed = false;
      } else {
        _completed = prefs.getBool(_completedKey) ?? false;
      }
    } catch (error) {
      debugPrint('OnboardingController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> markCompleted() async {
    _completed = true;
    notifyListeners();
    if (_forceReplayOnboarding) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKey, true);
    } catch (error) {
      debugPrint('OnboardingController: save failed — $error');
    }
  }
}
