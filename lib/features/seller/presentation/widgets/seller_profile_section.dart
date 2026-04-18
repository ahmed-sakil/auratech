import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

class SellerProfileSection extends StatefulWidget {
  const SellerProfileSection({super.key});

  @override
  State<SellerProfileSection> createState() => _SellerProfileSectionState();
}

class _SellerProfileSectionState extends State<SellerProfileSection> {
  bool _isLoadingProfile = true;
  bool _isLoadingStats = true;

  Map<String, dynamic>? _profile;
  int _productCount = 0;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  int _deliveredOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _profile = response;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load seller profile')),
      );
    }
  }

  Future<void> _loadStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final productsResponse = await Supabase.instance.client
          .from('products')
          .select('id')
          .eq('seller_id', user.id);

      final ordersResponse = await Supabase.instance.client
          .from('orders')
          .select('id, order_status')
          .eq('seller_id', user.id);

      final products = List<Map<String, dynamic>>.from(productsResponse);
      final orders = List<Map<String, dynamic>>.from(ordersResponse);

      final pending = orders.where((order) {
        final status = (order['order_status'] as String?) ?? 'pending';
        return status != 'delivered' && status != 'cancelled';
      }).length;

      final delivered = orders.where((order) {
        final status = (order['order_status'] as String?) ?? 'pending';
        return status == 'delivered';
      }).length;

      if (!mounted) return;

      setState(() {
        _productCount = products.length;
        _totalOrders = orders.length;
        _pendingOrders = pending;
        _deliveredOrders = delivered;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingStats = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load seller stats')),
      );
    }
  }

  Future<void> _refresh() async {
    await _loadProfile();
    await _loadStats();
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
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
    if (_isLoadingProfile || _isLoadingStats) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_profile == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    size: 42,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Profile Not Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We could not load your seller profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final fullName = (_profile!['full_name'] as String?) ?? '';
    final email = (_profile!['email'] as String?) ?? '';
    final role = (_profile!['role'] as String?) ?? '';
    final status = (_profile!['status'] as String?) ?? '';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    child: Icon(Icons.storefront_outlined, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    fullName.isEmpty ? 'Seller' : fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _statCard(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                value: _productCount.toString(),
              ),
              _statCard(
                icon: Icons.receipt_long_outlined,
                label: 'Total Orders',
                value: _totalOrders.toString(),
              ),
              _statCard(
                icon: Icons.pending_actions_outlined,
                label: 'Pending Orders',
                value: _pendingOrders.toString(),
              ),
              _statCard(
                icon: Icons.local_shipping_outlined,
                label: 'Delivered',
                value: _deliveredOrders.toString(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoTile(
            icon: Icons.store_outlined,
            label: 'Seller Name',
            value: fullName.isEmpty ? 'Not provided' : fullName,
          ),
          const SizedBox(height: 12),
          _infoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: email,
          ),
          const SizedBox(height: 12),
          _infoTile(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: role,
          ),
          const SizedBox(height: 12),
          _infoTile(
            icon: Icons.verified_user_outlined,
            label: 'Status',
            value: status,
          ),
        ],
      ),
    );
  }
}