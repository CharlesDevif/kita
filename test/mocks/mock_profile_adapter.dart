import 'package:kita/shared/multi_modal/profile_adapter.dart';

class MockProfileAdapter implements ProfileAdapter {
  String _activeProfile = 'blind';
  final List<String> feedbackLog = [];

  @override
  String get activeProfile => _activeProfile;

  set activeProfile(String profile) => _activeProfile = profile;

  @override
  void feedback({
    VoidCallback? visual,
    VoidCallback? vocal,
    VoidCallback? haptic,
  }) {
    if (visual != null) {
      feedbackLog.add('visual');
      visual();
    }
    if (vocal != null) {
      feedbackLog.add('vocal');
      vocal();
    }
    if (haptic != null) {
      feedbackLog.add('haptic');
      haptic();
    }
  }
}
