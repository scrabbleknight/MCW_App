import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app keeps on the device: SharedPreferences (plan answers,
/// progress, history, settings) and files in the documents directory
/// (profile photo, body progress photos).
abstract final class LocalData {
  /// Erases all of it. Used after the account is deleted, so the phone keeps
  /// nothing of the old account.
  static Future<void> eraseAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (error) {
      debugPrint('LocalData: clearing preferences failed — $error');
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      for (final entry in docs.listSync()) {
        await entry.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('LocalData: clearing documents failed — $error');
    }
  }
}
