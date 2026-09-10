import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/auth/presentation/login_screen.dart';
import 'dart:io';

import 'package:military_calisthenics_women/features/profile/application/body_progress_controller.dart';
import 'package:military_calisthenics_women/features/profile/application/profile_avatar_controller.dart';
import 'package:military_calisthenics_women/features/profile/presentation/workout_history_screen.dart';
import 'package:military_calisthenics_women/features/workouts/application/progress_controller.dart';
import 'package:military_calisthenics_women/features/workouts/application/workout_history_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return _ProfileBody(user: user);
      },
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.user});

  final User? user;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  String? _promptedForUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePromptForName();
  }

  @override
  void didUpdateWidget(covariant _ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePromptForName();
  }

  void _maybePromptForName() {
    final u = widget.user;
    if (u == null) return;
    final name = u.displayName?.trim() ?? '';
    if (name.isNotEmpty) return;
    if (_promptedForUid == u.uid) return;
    _promptedForUid = u.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showRenameDialog(context, u);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final palette = context.palette;
    final progress = context.watch<ProgressController>();
    final rank = rankFor(progress.stars, progress.completedDays.length);
    final loggedIn = user != null;
    final displayName = user?.displayName?.trim();
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : 'Soldier';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                _AvatarBadge(rank: rank, loggedIn: loggedIn),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: loggedIn
                            ? () => _showRenameDialog(context, user)
                            : null,
                        child: Text(
                          loggedIn ? name : 'Guest soldier',
                          style: TextStyle(
                            color: palette.chalk,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loggedIn
                            ? 'Rank · ${rank.label}'
                            : 'Log in to sync your progress',
                        style: TextStyle(
                          color: palette.mist,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!loggedIn)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.arctic,
                    foregroundColor: palette.chalk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    'Log in',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _StatsRow(
            days: progress.completedDays.length,
            stars: progress.stars,
            rank: rank,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Achievement',
                  style: TextStyle(
                    color: palette.chalk,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AchievementsScreen(currentRank: rank),
                    ),
                  ),
                  child: Text(
                    'view all',
                    style: TextStyle(
                      color: palette.mist,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _AchievementStrip(currentRank: rank),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Calendar',
              style: TextStyle(
                color: palette.chalk,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _CalendarCard(
                completedDayCount: progress.completedDays.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Body Progress',
                  style: TextStyle(
                    color: palette.chalk,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WeightEntriesScreen(),
                    ),
                  ),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: palette.mist,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _BodyProgressCard(),
          ),
        ),
        if (loggedIn)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.mist,
                  side: BorderSide(color: palette.hairline),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.rank, required this.loggedIn});

  final Rank rank;
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final avatar = context.watch<ProfileAvatarController>();
    final chosen = avatar.path;
    final Widget child;
    if (chosen != null) {
      child = Image.file(
        File(chosen),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/branding/guest_avatar.png', fit: BoxFit.cover),
      );
    } else if (loggedIn) {
      child = Image.asset(rank.asset, fit: BoxFit.contain);
    } else {
      child = Image.asset(
        'assets/branding/guest_avatar.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.person_rounded, color: palette.muted, size: 36),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showAvatarSheet(context, hasCustom: chosen != null),
      child: SizedBox(
        width: 78,
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.hairline),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: child,
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: palette.arctic,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.abyss, width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: palette.chalk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRenameDialog(BuildContext context, User user) async {
  final palette = context.palette;
  final controller =
      TextEditingController(text: user.displayName?.trim() ?? '');
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "What's your name, soldier?",
          style: TextStyle(color: palette.chalk, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "We'll use this on your profile instead of your email.",
              style: TextStyle(color: palette.mist, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: palette.chalk),
              decoration: InputDecoration(
                hintText: 'First name',
                hintStyle: TextStyle(color: palette.muted),
                filled: true,
                fillColor: palette.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Not now', style: TextStyle(color: palette.mist)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.arctic,
              foregroundColor: palette.chalk,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                await user.updateDisplayName(name);
                await user.reload();
              } catch (_) {}
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> _showAvatarSheet(BuildContext context,
    {required bool hasCustom}) async {
  final palette = context.palette;
  final controller = context.read<ProfileAvatarController>();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: palette.chalk),
              title: Text(
                'Choose from gallery',
                style: TextStyle(
                    color: palette.chalk, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                controller.pickFromGallery();
              },
            ),
            if (hasCustom)
              ListTile(
                leading: Icon(Icons.delete_outline, color: palette.danger),
                title: Text(
                  'Remove photo',
                  style: TextStyle(
                      color: palette.danger, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Restore default avatar',
                  style: TextStyle(color: palette.mist, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  controller.clear();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow(
      {required this.days, required this.stars, required this.rank});

  final int days;
  final int stars;
  final Rank rank;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _StatTile(label: days == 1 ? 'Day' : 'Days', value: '$days')),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: stars == 1 ? 'Star' : 'Stars', value: '$stars')),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: 'Rank', value: rank.label)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: palette.chalk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementStrip extends StatelessWidget {
  const _AchievementStrip({required this.currentRank});

  final Rank currentRank;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Show the three ranks around the user's current one for a preview.
    final index = Rank.values.indexOf(currentRank);
    final start = (index - 1).clamp(0, Rank.values.length - 3);
    final preview =
        Rank.values.sublist(start, (start + 3).clamp(0, Rank.values.length));

    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final r in preview)
            Expanded(
              child: _BadgeThumb(
                rank: r,
                unlocked: r.index <= currentRank.index,
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeThumb extends StatelessWidget {
  const _BadgeThumb({required this.rank, required this.unlocked});

  final Rank rank;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Image.asset(rank.asset, fit: BoxFit.contain),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Achievements / badges page
// -----------------------------------------------------------------------------

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.currentRank});

  final Rank currentRank;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unlocked =
        Rank.values.where((r) => r.index <= currentRank.index).toList();
    final locked =
        Rank.values.where((r) => r.index > currentRank.index).toList();

    return Scaffold(
      backgroundColor: palette.abyss,
      appBar: AppBar(
        backgroundColor: palette.abyss,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.chalk),
        title: Text(
          'Achievement',
          style: TextStyle(
            color: palette.chalk,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _FeaturedBadge(rank: currentRank),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'unlocked',
                  style: TextStyle(
                    color: palette.chalk,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _BadgeGrid(ranks: unlocked, unlocked: true),
            if (locked.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    'locked',
                    style: TextStyle(
                      color: palette.chalk,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _BadgeGrid(ranks: locked, unlocked: false),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge({required this.rank});

  final Rank rank;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          radius: 0.9,
          center: Alignment.center,
          colors: [
            palette.arcticDeep.withOpacity(0.45),
            palette.abyss,
          ],
        ),
        border: Border.all(color: palette.hairline),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RadialGridPainter(palette.hairline)),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Image.asset(rank.asset, fit: BoxFit.contain),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.midnight,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: palette.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech_rounded,
                        color: palette.warning, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      rank.label.toUpperCase(),
                      style: TextStyle(
                        color: palette.chalk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.military_tech_rounded,
                        color: palette.warning, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadialGridPainter extends CustomPainter {
  _RadialGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final center = Offset(size.width / 2, size.height * 0.82);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, i * 40.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialGridPainter oldDelegate) => false;
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.ranks, required this.unlocked});

  final List<Rank> ranks;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _BadgeCard(rank: ranks[i], unlocked: unlocked),
          childCount: ranks.length,
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.rank, required this.unlocked});

  final Rank rank;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: [
          Expanded(
            child: Opacity(
              opacity: unlocked ? 1.0 : 0.4,
              child: Image.asset(rank.asset, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rank.label.toUpperCase(),
            style: TextStyle(
              color: unlocked ? palette.chalk : palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Rank model
// -----------------------------------------------------------------------------

enum Rank {
  recruit('Recruit', 'assets/branding/recruit_badge.png', 0),
  private('Private', 'assets/branding/private_badge.png', 3),
  corporal('Corporal', 'assets/branding/corporal_badge.png', 8),
  sergeant('Sergeant', 'assets/branding/sergeant_badge.png', 16),
  lieutenant('Lieutenant', 'assets/branding/lieutenant_badge.png', 28),
  captain('Captain', 'assets/branding/captain_badge.png', 42),
  general('General', 'assets/branding/general_badge.png', 60);

  const Rank(this.label, this.asset, this.starThreshold);

  final String label;
  final String asset;
  final int starThreshold;
}

Rank rankFor(int stars, int days) {
  final score = stars + days;
  Rank current = Rank.recruit;
  for (final r in Rank.values) {
    if (score >= r.starThreshold) current = r;
  }
  return current;
}

// -----------------------------------------------------------------------------
// Calendar card
// -----------------------------------------------------------------------------

class _CalendarCard extends StatefulWidget {
  const _CalendarCard({required this.completedDayCount});

  final int completedDayCount;

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int by) {
    setState(() => _month = DateTime(_month.year, _month.month + by));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = DateTime.now();
    final isCurrentMonth =
        today.year == _month.year && today.month == _month.month;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_month.year}, ${_monthName(_month.month)}',
                style: TextStyle(
                  color: palette.chalk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _RoundIconButton(
                  icon: Icons.chevron_left_rounded, onTap: () => _shift(-1)),
              const SizedBox(width: 8),
              _RoundIconButton(
                  icon: Icons.chevron_right_rounded, onTap: () => _shift(1)),
            ],
          ),
          const SizedBox(height: 14),
          Consumer<WorkoutHistoryController>(
            builder: (_, history, __) {
              final workoutDays = <int>{
                for (final e in history.entries)
                  if (e.completedAt.year == _month.year &&
                      e.completedAt.month == _month.month)
                    e.completedAt.day,
              };
              return _CalendarGrid(
                month: _month,
                todayHighlighted: isCurrentMonth,
                today: today,
                workoutDays: workoutDays,
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.palette.arctic,
                foregroundColor: context.palette.chalk,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WorkoutHistoryScreen(),
                  ),
                );
              },
              child: const Text(
                'Workout History',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: palette.surfaceHigh,
          shape: BoxShape.circle,
          border: Border.all(color: palette.hairline),
        ),
        child: Icon(icon, color: palette.mist, size: 18),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.todayHighlighted,
    required this.today,
    required this.workoutDays,
  });

  final DateTime month;
  final bool todayHighlighted;
  final DateTime today;

  /// Day-of-month numbers (1-31) for which a workout was completed in the
  /// month currently on screen. Days in this set render with the blue
  /// outlined marker.
  final Set<int> workoutDays;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[];
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (final l in labels) {
      cells.add(Center(
        child: Text(
          l,
          style: TextStyle(
            color: palette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final isToday = todayHighlighted && d == today.day;
      final didWorkout = workoutDays.contains(d);
      final _CellHighlight highlight;
      if (isToday) {
        highlight = _CellHighlight.filled;
      } else if (didWorkout) {
        highlight = _CellHighlight.outlined;
      } else {
        highlight = _CellHighlight.none;
      }
      cells.add(_CalendarCell(day: d, highlight: highlight));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 4,
      children: cells,
    );
  }
}

enum _CellHighlight { none, outlined, filled }

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({required this.day, required this.highlight});

  final int day;
  final _CellHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.arctic;
    final decoration = switch (highlight) {
      _CellHighlight.filled =>
        BoxDecoration(color: accent, shape: BoxShape.circle),
      _CellHighlight.outlined => BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 1.5),
        ),
      _CellHighlight.none => const BoxDecoration(),
    };
    final color = switch (highlight) {
      _CellHighlight.filled => palette.chalk,
      _CellHighlight.outlined => accent,
      _CellHighlight.none => palette.mist,
    };
    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: decoration,
        child: Text(
          '$day',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _monthName(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[m - 1];
}

// -----------------------------------------------------------------------------
// Body Progress card
// -----------------------------------------------------------------------------

class _BodyProgressCard extends StatelessWidget {
  const _BodyProgressCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = context.watch<BodyProgressController>();
    final weight = body.latest?.kg;
    final bmi = body.bmi;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight',
                        style: TextStyle(
                          color: palette.mist,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      weight == null
                          ? '— kg'
                          : '${weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1)} kg',
                      style: TextStyle(
                        color: palette.chalk,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.arctic,
                          foregroundColor: palette.chalk,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WeightEntriesScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add weight',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _BmiBlock(bmi: bmi)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: palette.hairline, height: 1),
          const SizedBox(height: 16),
          _WeightTimeline(controller: body),
        ],
      ),
    );
  }
}

class _BmiBlock extends StatelessWidget {
  const _BmiBlock({required this.bmi});

  final double? bmi;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('BMI',
                style: TextStyle(
                  color: palette.mist,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            Tooltip(
              message: 'BMI Metrics/Formula from CDC',
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 3),
              child: Icon(Icons.info_outline, size: 16, color: palette.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          bmi == null ? '—' : bmi!.toStringAsFixed(1),
          style: TextStyle(
            color: palette.chalk,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _BmiBar(bmi: bmi),
        const SizedBox(height: 6),
        Text(
          bmi == null ? '—' : _bmiLabel(bmi!),
          style: TextStyle(
            color: _bmiColor(context, bmi),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BmiBar extends StatelessWidget {
  const _BmiBar({required this.bmi});
  final double? bmi;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    double? t;
    if (bmi != null) {
      t = ((bmi! - 15) / (40 - 15)).clamp(0.0, 1.0);
    }
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 14,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: _seg(palette.arctic)),
                  const SizedBox(width: 2),
                  Expanded(child: _seg(palette.success)),
                  const SizedBox(width: 2),
                  Expanded(child: _seg(palette.warning)),
                  const SizedBox(width: 2),
                  Expanded(child: _seg(palette.danger)),
                ],
              ),
            ),
            if (t != null)
              Positioned(
                left: (w * t) - 6,
                top: -4,
                child: Icon(Icons.arrow_drop_down,
                    color: palette.chalk, size: 20),
              ),
          ],
        ),
      );
    });
  }

  Widget _seg(Color c) => Container(
        height: 4,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

String _bmiLabel(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

Color _bmiColor(BuildContext context, double? bmi) {
  final p = context.palette;
  if (bmi == null) return p.muted;
  if (bmi < 18.5) return p.arctic;
  if (bmi < 25) return p.success;
  if (bmi < 30) return p.warning;
  return p.danger;
}

class _WeightTimeline extends StatelessWidget {
  const _WeightTimeline({required this.controller});

  final BodyProgressController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final latest = controller.latest;
    final earliest = controller.earliest;
    final start = earliest?.kg;
    final current = latest?.kg;
    final goal = controller.goalKg;
    final delta =
        (start == null || current == null) ? 0.0 : (current - start);
    final deltaText = delta == 0
        ? '0.0 kg since start'
        : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg since start';

    double t = 0;
    if (start != null && current != null && goal != null && start != goal) {
      t = ((current - start) / (goal - start)).clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Timeline',
                style: TextStyle(
                  color: palette.chalk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
            Text(deltaText,
                style: TextStyle(
                  color: palette.mist,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              start == null ? '—' : '${start.toStringAsFixed(0)}kg',
              style: TextStyle(
                color: palette.chalk,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            InkWell(
              onTap: () => _showGoalSheet(context),
              child: Text(
                goal == null ? 'Set goal' : '${goal.toStringAsFixed(0)}kg',
                style: TextStyle(
                  color: palette.chalk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: palette.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            LayoutBuilder(builder: (context, c) {
              return Container(
                height: 6,
                width: c.maxWidth * t,
                decoration: BoxDecoration(
                  color: palette.arctic,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              earliest == null ? '—' : _dateShort(earliest.date),
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              latest == null ? '—' : _dateShort(latest.date),
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _dateShort(DateTime d) =>
    '${_monthName(d.month)} ${d.day}, ${d.year}';

String _dateLong(DateTime d) {
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
    'Saturday', 'Sunday',
  ];
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
}

Future<void> _showAddWeightSheet(BuildContext context) async {
  final palette = context.palette;
  final controller = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add weight',
                style: TextStyle(
                  color: palette.chalk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: palette.chalk, fontSize: 16),
              decoration: InputDecoration(
                suffixText: 'kg',
                suffixStyle: TextStyle(color: palette.mist),
                filled: true,
                fillColor: palette.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.arctic,
                foregroundColor: palette.chalk,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final kg = double.tryParse(controller.text.trim());
                if (kg == null || kg <= 0) return;
                await sheetCtx.read<BodyProgressController>().addEntry(
                      WeightEntry(date: DateTime.now(), kg: kg),
                    );
                if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              },
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showGoalSheet(BuildContext context) async {
  final palette = context.palette;
  final body = context.read<BodyProgressController>();
  final controller =
      TextEditingController(text: body.goalKg?.toStringAsFixed(0) ?? '');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Goal weight',
                style: TextStyle(
                  color: palette.chalk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: palette.chalk, fontSize: 16),
              decoration: InputDecoration(
                suffixText: 'kg',
                suffixStyle: TextStyle(color: palette.mist),
                filled: true,
                fillColor: palette.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.arctic,
                foregroundColor: palette.chalk,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final kg = double.tryParse(controller.text.trim());
                if (kg == null || kg <= 0) return;
                await body.setGoal(kg);
                if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              },
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    },
  );
}

// -----------------------------------------------------------------------------
// Weight Entries screen
// -----------------------------------------------------------------------------

class WeightEntriesScreen extends StatelessWidget {
  const WeightEntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = context.watch<BodyProgressController>();
    final entries = body.entries;
    final start = body.earliest?.kg;
    final current = body.latest?.kg;
    final change =
        (start == null || current == null) ? 0.0 : current - start;

    return Scaffold(
      backgroundColor: palette.abyss,
      appBar: AppBar(
        backgroundColor: palette.abyss,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.chalk),
        title: Text(
          'Weight Entries',
          style: TextStyle(
            color: palette.chalk,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddWeightSheet(context),
            icon: Icon(Icons.add_rounded, color: palette.chalk),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCol(
                          label: 'STARTING',
                          value:
                              start == null ? '—' : start.toStringAsFixed(0),
                        ),
                      ),
                      Expanded(
                        child: _MetricCol(
                          label: 'CURRENT',
                          value: current == null
                              ? '—'
                              : current.toStringAsFixed(0),
                        ),
                      ),
                      Expanded(
                        child: _MetricCol(
                          label: 'CHANGE',
                          value: current == null || start == null
                              ? '—'
                              : (change == 0
                                  ? '0'
                                  : '${change > 0 ? '+' : ''}${change.toStringAsFixed(0)}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (entries.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No weight entries yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => Divider(
                    color: palette.hairline,
                    height: 1,
                    indent: 20,
                    endIndent: 20),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return Dismissible(
                    key: ValueKey('${e.date.toIso8601String()}-${e.kg}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => body.removeEntry(e),
                    background: Container(
                      color: palette.danger,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child:
                          Icon(Icons.delete_outline, color: palette.chalk),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.kg.toStringAsFixed(1)}kg',
                            style: TextStyle(
                              color: palette.chalk,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dateLong(e.date),
                            style: TextStyle(
                              color: palette.mist,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCol extends StatelessWidget {
  const _MetricCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              color: palette.chalk,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            )),
      ],
    );
  }
}
