import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'profile_adapter.dart';
import 'profile_adapter_impl.dart';

part 'profile_adapter_provider.g.dart';

/// Provides the active user profile.
///
/// Read by ProfileAdapter to route feedback. Updated by onboarding
/// and settings screens when the user changes profile.
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  UserProfile build() => UserProfile.standard;

  void setProfile(UserProfile profile) {
    state = profile;
  }
}

/// Provides the ProfileAdapter implementation configured for the active profile.
@riverpod
ProfileAdapter profileAdapter(Ref ref) {
  final profile = ref.watch(userProfileProvider);
  return ProfileAdapterImpl(profile: profile);
}
