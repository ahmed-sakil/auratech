import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/profile_repository.dart';
import 'app_session.dart';

final appSessionProvider =
    AsyncNotifierProvider<AppSessionNotifier, AppSession>(
      AppSessionNotifier.new,
    );

class AppSessionNotifier extends AsyncNotifier<AppSession> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  Future<AppSession> build() async {
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      state = const AsyncLoading();

      final session = event.session;
      if (session == null || session.user == null) {
        state = const AsyncData(AppSession.unauthenticated());
        return;
      }

      final profile = await ref
          .read(profileRepositoryProvider)
          .fetchCurrentProfile(session.user.id);

      if (profile == null) {
        state = const AsyncData(AppSession.unauthenticated());
        return;
      }

      state = AsyncData(AppSession.authenticated(profile));
    });

    final currentSession = Supabase.instance.client.auth.currentSession;
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentSession == null || currentUser == null) {
      return const AppSession.unauthenticated();
    }

    final profile = await ref
        .read(profileRepositoryProvider)
        .fetchCurrentProfile(currentUser.id);

    if (profile == null) {
      return const AppSession.unauthenticated();
    }

    return AppSession.authenticated(profile);
  }
}