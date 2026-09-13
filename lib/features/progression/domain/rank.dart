/// Unified rank ladder shared by the home Squad Status card, the profile
/// achievements grid, and the end-of-session rank-up celebration. Ranks are
/// earned by [workoutThreshold] total completed workouts (mission + training
/// + custom) so activity in any tab counts.
enum Rank {
  recruit('Recruit', 'assets/branding/recruit_badge.png', 0),
  private('Private', 'assets/branding/private_badge.png', 3),
  corporal('Corporal', 'assets/branding/corporal_badge.png', 7),
  sergeant('Sergeant', 'assets/branding/sergeant_badge.png', 12),
  lieutenant('Lieutenant', 'assets/branding/lieutenant_badge.png', 18),
  captain('Captain', 'assets/branding/captain_badge.png', 25),
  general('General', 'assets/branding/general_badge.png', 35);

  const Rank(this.label, this.asset, this.workoutThreshold);

  final String label;
  final String asset;
  final int workoutThreshold;

  /// The highest rank the user has earned for a given number of completed
  /// workouts. Always returns at least [Rank.recruit].
  static Rank forWorkouts(int completedWorkouts) {
    var earned = Rank.recruit;
    for (final r in Rank.values) {
      if (completedWorkouts >= r.workoutThreshold) earned = r;
    }
    return earned;
  }

  /// The next rank up, or `null` when the user is already General.
  Rank? get next {
    final i = index + 1;
    return i >= Rank.values.length ? null : Rank.values[i];
  }

  /// One short in-character sentence that describes what this rank means —
  /// shown on the celebration modal below the divider.
  String get citation => switch (this) {
    Rank.recruit =>
      'You showed up and earned your place in the squad. Keep pushing — '
          'your next promotion is waiting.',
    Rank.private =>
      'You are in the ranks now. The work is real, the streak is yours. '
          'Keep showing up, soldier.',
    Rank.corporal =>
      'A dozen sessions closer to elite. You are proving this is a habit, '
          'not a phase.',
    Rank.sergeant =>
      'You lead by example now. The soldiers behind you are watching how '
          'you carry the load.',
    Rank.lieutenant =>
      'Discipline is starting to look like strength. Keep this line — the '
          'brass is watching.',
    Rank.captain =>
      'Very few make it this far. You have written your name into the '
          'unit\'s record.',
    Rank.general =>
      'The top of the ladder. You built this — every rep, every session. '
          'Wear it proudly.',
  };
}
