/// One exercise the plan-generator can slot into a workout. Purely data — no
/// UI or video-playback code lives here. When demo videos land, wire them up
/// via [videoAsset] and [thumbnailAsset]; the algorithm never reads them.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.position,
    required this.primary,
    required this.movements,
    required this.difficulty,
    required this.unit,
    required this.baseAmount,
    required this.cues,
    this.secondary = const {},
    this.highImpact = false,
    this.needsBand = false,
    this.muxPlaybackId,
    String? videoAsset,
    String? thumbnailAsset,
  }) : _videoAsset = videoAsset,
       _thumbnailAsset = thumbnailAsset;

  final String id;
  final String name;

  /// Body position the movement starts / spends most of its time in.
  /// Drives the "No Kneeling / No Prone / All Standing" preference filters.
  final ExercisePosition position;

  /// Main mover the exercise trains. One entry per exercise so the plan
  /// generator can balance a day's volume across muscle groups.
  final ExerciseMuscle primary;

  /// Anything the exercise trains in addition to [primary].
  final Set<ExerciseMuscle> secondary;

  /// Movement patterns the exercise expresses. Used by the generator to
  /// avoid stacking three squats in a row, and by "No Squat / No Jumping"
  /// to prune the pool.
  final Set<ExerciseMovement> movements;

  final ExerciseDifficulty difficulty;

  /// Whether [baseAmount] is measured in reps or seconds.
  final ExerciseUnit unit;

  /// Volume at "intermediate" fitness level. Beginner scales this down,
  /// advanced scales it up (see plan_generator.dart).
  final int baseAmount;

  /// Involves jumping / real ground-off-both-feet impact. Filtered by the
  /// "No Jumping" preference.
  final bool highImpact;

  /// Requires a resistance band to run properly. Currently used as a hint;
  /// the generator only picks these when nothing else fits.
  final bool needsBand;

  /// One-line coaching cue. Kept short so it fits on the workout card.
  final String cues;

  /// Optional Mux playback id. When present, the standard stream and
  /// thumbnail URLs are derived so callers cannot accidentally mismatch them.
  final String? muxPlaybackId;
  final String? _videoAsset;
  final String? _thumbnailAsset;

  String? get videoAsset =>
      _videoAsset ??
      (muxPlaybackId == null
          ? null
          : 'https://stream.mux.com/$muxPlaybackId.m3u8');

  String? get thumbnailAsset =>
      _thumbnailAsset ??
      (muxPlaybackId == null
          ? null
          : 'https://image.mux.com/$muxPlaybackId/thumbnail.jpg');
}

enum ExercisePosition {
  standing,
  squatStance,
  lungeStance,
  kneeling,
  bearStance,
  prone,
  supine,
  sideLying,
  sitting,
}

enum ExerciseMovement {
  push,
  pull,
  squat,
  hinge,
  lunge,
  plank,
  twist,
  jump,
  kick,
  hold,
  mobility,
  cardio,
}

enum ExerciseMuscle {
  chest,
  upperBack,
  shoulders,
  arms,
  coreAnterior,
  obliques,
  lowerBack,
  glutes,
  quads,
  hamstrings,
  innerThighs,
  calves,
  fullBody,
  hipMobility,
  spineMobility,
}

enum ExerciseDifficulty { beginner, intermediate, advanced }

enum ExerciseUnit { reps, seconds }
