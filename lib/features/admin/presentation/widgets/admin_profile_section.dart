import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';

class AdminProfileSection extends StatefulWidget {
  const AdminProfileSection({super.key});

  @override
  State<AdminProfileSection> createState() => _AdminProfileSectionState();
}

class _AdminProfileSectionState extends State<AdminProfileSection> {
  bool _isLoading = true;
  String _fullName = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _fullName = (profile?['full_name'] as String?) ?? '';
        _email = (profile?['email'] as String?) ?? (user.email ?? '');
      });
    } catch (_) {
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Widget _profileTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isEmpty ? 'Not available' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Admin Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your administrator access and review platform activity.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _profileTile(
          label: 'Full name',
          value: _fullName,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        _profileTile(
          label: 'Email',
          value: _email,
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 14),
        _profileTile(
          label: 'Role',
          value: 'Administrator',
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }
}