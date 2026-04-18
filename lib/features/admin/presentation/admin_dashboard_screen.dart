import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _pendingSellersFuture;

  @override
  void initState() {
    super.initState();
    _pendingSellersFuture = _fetchPendingSellers();
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out')),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPendingSellers() async {
    final pendingProfiles = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('role', 'seller')
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    final profiles = List<Map<String, dynamic>>.from(pendingProfiles);

    if (profiles.isEmpty) {
      return [];
    }

    final userIds = profiles.map((e) => e['id'] as String).toList();

    final detailsResponse = await Supabase.instance.client
        .from('seller_details')
        .select()
        .inFilter('user_id', userIds);

    final detailsList = List<Map<String, dynamic>>.from(detailsResponse);

    final detailsByUserId = <String, Map<String, dynamic>>{};
    for (final item in detailsList) {
      detailsByUserId[item['user_id'] as String] = item;
    }

    return profiles.map((profile) {
      final userId = profile['id'] as String;
      final details = detailsByUserId[userId];

      return {
        ...profile,
        'seller_details': details,
      };
    }).toList();
  }

  Future<void> _refreshPendingSellers() async {
    final data = await _fetchPendingSellers();
    if (!mounted) return;

    setState(() {
      _pendingSellersFuture = Future.value(data);
    });
  }

  Future<void> _approveSeller(String userId) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'status': 'active'})
          .eq('id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller approved successfully')),
      );

      await _refreshPendingSellers();
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not approve seller')),
      );
    }
  }

  Widget _infoTile(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sellerCard(Map<String, dynamic> seller) {
    final details = seller['seller_details'] as Map<String, dynamic>?;

    final fullName = (seller['full_name'] as String?) ?? '';
    final email = (seller['email'] as String?) ?? '';
    final businessName = (details?['business_name'] as String?) ?? '';
    final phone = (details?['phone'] as String?) ?? '';
    final address = (details?['address'] as String?) ?? '';
    final description = (details?['description'] as String?) ?? '';
    final hasDetails = details != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Unnamed Seller' : fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Pending approval',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (hasDetails) ...[
              _infoTile('Business name', businessName),
              const SizedBox(height: 12),
              _infoTile('Phone', phone),
              const SizedBox(height: 12),
              _infoTile('Address', address),
              const SizedBox(height: 12),
              _infoTile(
                'Description',
                description.isEmpty ? 'Not provided' : description,
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'This seller has not submitted seller details yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasDetails ? () => _approveSeller(seller['id'] as String) : null,
                child: const Text('Approve Seller'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _refreshPendingSellers(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _pendingSellersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 42,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Could not load pending sellers',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final sellers = snapshot.data ?? [];

                if (sellers.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 42,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'No Pending Sellers',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All seller onboarding requests are currently cleared.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: sellers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _sellerCard(sellers[index]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}