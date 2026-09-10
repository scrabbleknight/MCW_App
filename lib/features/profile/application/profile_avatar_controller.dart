import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-chosen avatar image. Persists the path to a copy of the picked file
/// under the app's documents directory so gallery pickers that hand back
/// tmp paths don't leave us pointing at a file the OS may sweep away.
class ProfileAvatarController extends ChangeNotifier {
  static const _kPath = 'profile.avatar_path';

  String? _path;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Local file path to the chosen image, or null if the user hasn't picked
  /// one (in which case the UI falls back to the guest avatar asset).
  String? get path => _path;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kPath);
      if (stored != null && File(stored).existsSync()) {
        _path = stored;
      }
    } catch (error) {
      debugPrint('ProfileAvatarController: load failed — $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Opens the OS gallery, copies the pick into the docs directory, and
  /// persists the new path. Returns the new path, or null if the user
  /// cancelled.
  Future<String?> pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return null;
      final docs = await getApplicationDocumentsDirectory();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final dest =
          '${docs.path}/profile_avatar_${DateTime.now().microsecondsSinceEpoch}.$ext';
      await File(file.path).copy(dest);
      _path = dest;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPath, dest);
      return dest;
    } catch (error) {
      debugPrint('ProfileAvatarController: pick failed — $error');
      return null;
    }
  }

  Future<void> clear() async {
    _path = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPath);
  }
}
