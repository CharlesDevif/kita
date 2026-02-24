typedef VoidCallback = void Function();

abstract interface class ProfileAdapter {
  String get activeProfile;
  void feedback({
    VoidCallback? visual,
    VoidCallback? vocal,
    VoidCallback? haptic,
  });
}
