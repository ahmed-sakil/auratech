import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

class AdminHomeSection extends StatefulWidget {
  const AdminHomeSection({super.key});

  @override
  State<AdminHomeSection> createState() => _AdminHomeSectionState();
}

class _AdminHomeSectionState extends State<AdminHomeSection> {
  bool _isLoading = true;
  int _pendingSellers = 0;
  int _activeSellers = 0;
  int _buyers = 0;
  int _admins = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('role, status');

      int pendingSellers = 0;
      int activeSellers = 0;
      int buyers = 0;
      int admins = 0;

      for (final item in profiles) {
        final row = item as Map<String, dynamic>;
        final role = (row['role'] as String?) ?? '';
        final status = (row['status'] as String?) ?? '';

        if (role == 'seller' && status == 'pending') {
          pendingSellers++;
        } else if (role == 'seller' && status == 'active') {
          activeSellers++;
        } else if (role == 'buyer') {
          buyers++;
        } else if (role == 'admin') {
          admins++;
        }
      }

      if (!mounted) return;

      setState(() {
        _pendingSellers = pendingSellers;
        _activeSellers = activeSellers;
        _buyers = buyers;
        _admins = admins;
      });
    } catch (_) {
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String description,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.insights_outlined,
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
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
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

    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome, Admin',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitor platform activity, review seller submissions, and manage account approvals from one place.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Pending seller requests: $_pendingSellers',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              _statCard(
                title: 'Pending Sellers',
                value: '$_pendingSellers',
                icon: Icons.pending_actions_outlined,
                iconColor: AppColors.primary,
                iconBackground: AppColors.primarySoft,
              ),
              _statCard(
                title: 'Active Sellers',
                value: '$_activeSellers',
                icon: Icons.storefront_outlined,
                iconColor: AppColors.success,
                iconBackground: const Color(0xFFEAF8EF),
              ),
              _statCard(
                title: 'Buyers',
                value: '$_buyers',
                icon: Icons.people_outline,
                iconColor: AppColors.warning,
                iconBackground: const Color(0xFFFFF7E8),
              ),
              _statCard(
                title: 'Admins',
                value: '$_admins',
                icon: Icons.admin_panel_settings_outlined,
                iconColor: AppColors.textPrimary,
                iconBackground: AppColors.surfaceSoft,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _infoCard(
            title: 'Approval Workflow',
            description:
                'Use the Pending Requests tab to review seller shop details, personal verification data, and onboarding consent before approving or rejecting submissions.',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 14),
          _infoCard(
            title: 'Seller Detail Coverage',
            description:
                'Pending requests now include shop name, owner name, email, phone, date of birth, NID number, shop address, home address, business description, and terms acceptance.',
            icon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }
}