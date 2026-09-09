import 'package:flutter/material.dart';

class OnboardingOption<T> {
  const OnboardingOption({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}
