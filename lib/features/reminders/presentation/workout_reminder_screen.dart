import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';
import 'package:military_calisthenics_women/features/reminders/application/reminder_controller.dart';
import 'package:provider/provider.dart';

class WorkoutReminderScreen extends StatelessWidget {
  const WorkoutReminderScreen({super.key});

  static const _dayOrder = <int>[
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
  ];

  static const _dayLabel = <int, String>{
    DateTime.monday: 'M',
    DateTime.tuesday: 'T',
    DateTime.wednesday: 'W',
    DateTime.thursday: 'T',
    DateTime.friday: 'F',
    DateTime.saturday: 'S',
    DateTime.sunday: 'S',
  };

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<ReminderController>();

    return Scaffold(
      backgroundColor: context.palette.abyss,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('⏰', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Text(
                    'Workout Reminder',
                    style: TextStyle(
                      color: context.palette.chalk,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Setting a workout reminder will keep you focused '
                'and help you achieve your fitness goals faster.',
                style: TextStyle(
                  color: context.palette.chalk.withOpacity(0.9),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reminder',
                      style: TextStyle(
                        color: context.palette.chalk,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: reminder.enabled,
                    activeColor: context.palette.arctic,
                    onChanged: reminder.setEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: reminder.enabled ? 1 : 0.35,
                  child: IgnorePointer(
                    ignoring: !reminder.enabled,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            color: context.palette.chalk,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: DateTime(
                          2020,
                          1,
                          1,
                          reminder.time.hour,
                          reminder.time.minute,
                        ),
                        use24hFormat: false,
                        onDateTimeChanged: (dt) => reminder.setTime(
                          TimeOfDay(hour: dt.hour, minute: dt.minute),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                'Select Days',
                style: TextStyle(
                  color: context.palette.chalk,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final d in _dayOrder)
                    _DayPill(
                      label: _dayLabel[d]!,
                      selected: reminder.days.contains(d),
                      onTap: reminder.enabled ? () => reminder.toggleDay(d) : null,
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.palette.arctic : context.palette.surfaceHigh;
    final fg = selected ? Colors.white : context.palette.chalk;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
