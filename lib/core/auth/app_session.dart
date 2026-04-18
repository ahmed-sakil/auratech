import '../../features/profile/profile_model.dart';

class AppSession {
  final bool isLoading;
  final ProfileModel? profile;

  const AppSession({
    required this.isLoading,
    required this.profile,
  });

  const AppSession.loading()
      : isLoading = true,
        profile = null;

  const AppSession.unauthenticated()
      : isLoading = false,
        profile = null;

  const AppSession.authenticated(ProfileModel userProfile)
      : isLoading = false,
        profile = userProfile;

  bool get isAuthenticated => profile != null;
}
