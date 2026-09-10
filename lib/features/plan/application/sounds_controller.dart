import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VoiceVerbosity { brief, detailed }

/// UI-only sound settings — persisted so the toggles survive relaunch, but no
/// audio engine is wired up yet. When the real playback lands, read from this
/// controller and don't change these keys or the users' choices reset.
class SoundsController extends ChangeNotifier {
  static const _kVoiceEnabled = 'sounds.voice.enabled';
  static const _kVoiceVerbosity = 'sounds.voice.verbosity';
  static const _kVoiceVolume = 'sounds.voice.volume';

  bool _voiceEnabled = true;
  VoiceVerbosity _verbosity = VoiceVerbosity.detailed;
  double _voiceVolume = 0.6;
  bool _loaded = false;

  bool get voiceEnabled => _voiceEnabled;
  VoiceVerbosity get verbosity => _verbosity;
  double get voiceVolume => _voiceVolume;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _voiceEnabled = prefs.getBool(_kVoiceEnabled) ?? true;
      final v = prefs.getString(_kVoiceVerbosity);
      _verbosity = v == VoiceVerbosity.brief.name
          ? VoiceVerbosity.brief
          : VoiceVerbosity.detailed;
      _voiceVolume = prefs.getDouble(_kVoiceVolume) ?? 0.6;
    } catch (error) {
      debugPrint('SoundsController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setVoiceEnabled(bool value) async {
    _voiceEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceEnabled, value);
  }

  Future<void> setVerbosity(VoiceVerbosity v) async {
    _verbosity = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVoiceVerbosity, v.name);
  }

  Future<void> setVoiceVolume(double v) async {
    _voiceVolume = v.clamp(0.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVoiceVolume, _voiceVolume);
  }
}
