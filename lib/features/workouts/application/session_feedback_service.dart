import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// The single mood chip the user picked in the end-of-session sheet.
enum SessionMood { rough, okay, great }

extension SessionMoodX on SessionMood {
  String get storageKey => switch (this) {
    SessionMood.rough => 'rough',
    SessionMood.okay => 'okay',
    SessionMood.great => 'great',
  };
}

/// Tag chips the user can toggle on to describe how the session went.
enum SessionTag { sweaty, motivated, easyWin, niceMusic, clearCues, other }

extension SessionTagX on SessionTag {
  String get storageKey => switch (this) {
    SessionTag.sweaty => 'sweaty',
    SessionTag.motivated => 'motivated',
    SessionTag.easyWin => 'easy_win',
    SessionTag.niceMusic => 'nice_music',
    SessionTag.clearCues => 'clear_cues',
    SessionTag.other => 'other',
  };

  String get displayLabel => switch (this) {
    SessionTag.sweaty => 'Sweaty',
    SessionTag.motivated => 'Motivated',
    SessionTag.easyWin => 'Easy Win',
    SessionTag.niceMusic => 'Nice Music',
    SessionTag.clearCues => 'Clear Cues',
    SessionTag.other => 'Other',
  };
}

/// Records a positive end-of-session reflection to Firestore. Mirrors
/// [QuitFeedbackService] shape so the founder can eyeball both drop-off and
/// completion sentiment side-by-side under
/// `session_feedback/<userId>/entries/<autoId>`.
class SessionFeedbackService {
  SessionFeedbackService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> record({
    required SessionMood mood,
    required List<SessionTag> tags,
    required int dayIndex,
    required String dayTitle,
    required int minutes,
    required int calories,
    String? note,
  }) async {
    final trimmed = (note ?? '').trim();
    final userId = _auth.currentUser?.uid ?? 'anonymous';
    try {
      await _firestore
          .collection('session_feedback')
          .doc(userId)
          .collection('entries')
          .add({
            'mood': mood.storageKey,
            'tags': tags.map((t) => t.storageKey).toList(),
            'note': trimmed.isEmpty ? null : trimmed,
            'day_index': dayIndex,
            'day_title': dayTitle,
            'minutes': minutes,
            'calories': calories,
            'created_at': FieldValue.serverTimestamp(),
            'client_created_at': DateTime.now().toUtc().toIso8601String(),
          });
    } catch (error) {
      debugPrint('SessionFeedbackService: write failed — $error');
    }
  }
}
