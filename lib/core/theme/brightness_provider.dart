import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'brightness_provider.g.dart';

/// Manages the app's brightness mode (dark by default).
@riverpod
class BrightnessMode extends _$BrightnessMode {
  @override
  Brightness build() => Brightness.dark;

  void toggle() {
    state = state == Brightness.dark ? Brightness.light : Brightness.dark;
  }
}
