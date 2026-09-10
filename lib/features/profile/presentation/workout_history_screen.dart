import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/workouts/application/workout_history_controller.dart';
import 'package:provider/provider.dart';

/// Shows every completed workout session — mission days, training routines,
/// and custom workouts — with the same date/title/duration/calories tile.
class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = context.watch<WorkoutHistoryController>().entries;

    return Scaffold(
      backgroundColor: palette.abyss,
      appBar: AppBar(
        backgroundColor: palette.abyss,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Workout History',
          style: TextStyle(
            color: palette.chalk,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: palette.chalk),
      ),
      body: entries.isEmpty
          ? _EmptyState(palette: palette)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _HistoryTile(entry: entries[i]),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final WorkoutHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 88,
              height: 88,
              child: _Artwork(entry: entry),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(entry.completedAt),
                  style: TextStyle(
                    color: palette.mist,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.chalk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: palette.muted),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.minutes} Mins',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.local_fire_department_rounded,
                        size: 14, color: palette.muted),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.calories} Kcal',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.entry});

  final WorkoutHistoryEntry entry;

  static const List<List<Color>> _palettes = [
    [Color(0xFF1D5FD1), Color(0xFF6FA8DC)],
    [Color(0xFF2C3E50), Color(0xFF4A6572)],
    [Color(0xFF3A1C71), Color(0xFF5B4B8A)],
    [Color(0xFF134E5E), Color(0xFF71B280)],
    [Color(0xFF4B3F72), Color(0xFF7E6B94)],
  ];

  static const List<IconData> _icons = [
    Icons.local_fire_department_rounded,
    Icons.fitness_center_rounded,
    Icons.sports_martial_arts_rounded,
    Icons.self_improvement_rounded,
    Icons.directions_walk_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    if (entry.kind == WorkoutHistoryKind.custom) {
      return Image.asset(
        'assets/branding/custom_background.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradient(0),
      );
    }
    return _gradient(entry.accentIndex);
  }

  Widget _gradient(int accentIndex) {
    final colors = _palettes[accentIndex.abs() % _palettes.length];
    final icon = _icons[accentIndex.abs() % _icons.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -6,
            child: Icon(
              icon,
              size: 90,
              color: Colors.white.withOpacity(0.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: palette.muted),
            const SizedBox(height: 12),
            Text(
              'No workouts yet',
              style: TextStyle(
                color: palette.chalk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Finish a mission day, training routine, or custom workout and it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.mist, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = dt.toLocal();
  return '${days[local.weekday - 1]}, ${months[local.month - 1]} ${local.day}, ${local.year}';
}
