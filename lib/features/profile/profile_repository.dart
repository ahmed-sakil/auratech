import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_service.dart';
import 'profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

class ProfileRepository {
  Future<ProfileModel?> fetchCurrentProfile(String userId) async {
    final data = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return ProfileModel.fromMap(data);
  }
}