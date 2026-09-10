import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// The concrete reason the user chose in the quit-feedback sheet. `justLook`
/// is the silent skip — never written to Firestore.
enum QuitReason { justLook, tooHard, tooEasy, poorInstruction, other }

extension QuitReasonX on QuitReason {
  String get storageKey => switch (this) {
        QuitReason.justLook => 'just_look',
        QuitReason.tooHard => 'too_hard',
        QuitReason.tooEasy => 'too_easy',
        QuitReason.poorInstruction => 'poor_instruction',
        QuitReason.other => 'other',
      };

  String get displayLabel => switch (this) {
        QuitReason.justLook => 'Just take a look',
        QuitReason.tooHard => 'Too hard',
        QuitReason.tooEasy => 'Too easy',
        QuitReason.poorInstruction => 'Poor Instruction',
        QuitReason.other => 'Other',
      };
}

/// Records why a user quit a workout early to Firestore. Fires silently for
/// [QuitReason.justLook] since that's a UI-only "not now" — everything else
/// lands under `quit_feedback/<userId>/entries/<autoId>` so the founder can
/// eyeball drop-off reasons per user.
class QuitFeedbackService {
  QuitFeedbackService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> record({
    required QuitReason reason,
    required int dayIndex,
    required String stepLabel,
    String? note,
  }) async {
    if (reason == QuitReason.justLook) return;
    final trimmed = (note ?? '').trim();
    final userId = _auth.currentUser?.uid ?? 'anonymous';
    try {
      await _firestore
          .collection('quit_feedback')
          .doc(userId)
          .collection('entries')
          .add({
        'reason': reason.storageKey,
        'reason_label': reason.displayLabel,
        'note': trimmed.isEmpty ? null : trimmed,
        'day_index': dayIndex,
        'step_label': stepLabel,
        'created_at': FieldValue.serverTimestamp(),
        'client_created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      // Feedback recording must never block the user's exit — swallow and log.
      debugPrint('QuitFeedbackService: write failed — $error');
    }
  }
}
