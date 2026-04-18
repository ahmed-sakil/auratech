import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

class AdminPendingRequestsSection extends StatefulWidget {
  const AdminPendingRequestsSection({super.key});

  @override
  State<AdminPendingRequestsSection> createState() =>
      _AdminPendingRequestsSectionState();
}

class _AdminPendingRequestsSectionState
    extends State<AdminPendingRequestsSection> {
  bool _isLoading = true;
  final Set<String> _busyUserIds = {};
  List<Map<String, dynamic>> _pendingSellers = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, role, status')
          .eq('role', 'seller')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final sellerIds = profiles
          .map((item) => (item as Map<String, dynamic>)['id'] as String)
          .toList();

      List<dynamic> sellerDetails = [];

      if (sellerIds.isNotEmpty) {
        sellerDetails = await Supabase.instance.client
            .from('seller_details')
            .select()
            .inFilter('user_id', sellerIds);
      }

      final Map<String, Map<String, dynamic>> detailsByUserId = {
        for (final item in sellerDetails)
          (item as Map<String, dynamic>)['user_id'] as String: item,
      };

      final combined = profiles.map((item) {
        final profile = item as Map<String, dynamic>;
        final userId = profile['id'] as String;
        final details = detailsByUserId[userId] ?? <String, dynamic>{};

        return {
          'id': userId,
          'profile_full_name': (profile['full_name'] as String?) ?? '',
          'profile_email': (profile['email'] as String?) ?? '',
          'shop_name': (details['shop_name'] as String?) ?? '',
          'owner_name': (details['owner_name'] as String?) ?? '',
          'phone': (details['phone'] as String?) ?? '',
          'email': (details['email'] as String?) ?? '',
          'date_of_birth': (details['date_of_birth'] as String?) ?? '',
          'nid_number': (details['nid_number'] as String?) ?? '',
          'has_physical_shop': (details['has_physical_shop'] as bool?) ?? true,
          'shop_address': (details['shop_address'] as String?) ?? '',
          'home_address': (details['home_address'] as String?) ?? '',
          'business_description':
              (details['business_description'] as String?) ?? '',
          'agreed_to_terms': (details['agreed_to_terms'] as bool?) ?? false,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _pendingSellers = combined;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load pending requests')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  String _displayDate(String value) {
    if (value.isEmpty) return 'Not provided';

    final parts = value.split('-');
    if (parts.length != 3) return value;

    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  String _maskNid(String nid) {
    if (nid.isEmpty) return 'Not provided';
    if (nid.length <= 4) return nid;

    final visible = nid.substring(nid.length - 4);
    return '${'*' * (nid.length - 4)}$visible';
  }

  Future<void> _updateSellerStatus({
    required String userId,
    required String status,
    required String successMessage,
  }) async {
    setState(() {
      _busyUserIds.add(userId);
    });

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'status': status})
          .eq('id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );

      await _loadPendingRequests();
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update seller status')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _busyUserIds.remove(userId);
      });
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> item) {
    final userId = item['id'] as String;
    final isBusy = _busyUserIds.contains(userId);

    final profileFullName = (item['profile_full_name'] as String?) ?? '';
    final profileEmail = (item['profile_email'] as String?) ?? '';
    final shopName = (item['shop_name'] as String?) ?? '';
    final ownerName = ((item['owner_name'] as String?) ?? '').isNotEmpty
        ? (item['owner_name'] as String?) ?? ''
        : profileFullName;
    final email = ((item['email'] as String?) ?? '').isNotEmpty
        ? (item['email'] as String?) ?? ''
        : profileEmail;
    final phone = (item['phone'] as String?) ?? '';
    final dateOfBirth = (item['date_of_birth'] as String?) ?? '';
    final nidNumber = (item['nid_number'] as String?) ?? '';
    final hasPhysicalShop = (item['has_physical_shop'] as bool?) ?? true;
    final shopAddress = (item['shop_address'] as String?) ?? '';
    final homeAddress = (item['home_address'] as String?) ?? '';
    final businessDescription =
        (item['business_description'] as String?) ?? '';
    final agreedToTerms = (item['agreed_to_terms'] as bool?) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shopName.isEmpty ? 'Unnamed Shop' : shopName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _detailRow('Owner name', ownerName),
            _detailRow('Email', email),
            _detailRow('Phone', phone),
            _detailRow('Date of birth', _displayDate(dateOfBirth)),
            _detailRow('NID number', _maskNid(nidNumber)),
            _detailRow(
              'Physical shop',
              hasPhysicalShop ? 'Yes' : 'No physical shop',
            ),
            _detailRow(
              'Shop address',
              hasPhysicalShop
                  ? (shopAddress.isEmpty ? 'Not provided' : shopAddress)
                  : 'No physical shop',
            ),
            _detailRow('Home address', homeAddress),
            _detailRow(
              'Terms agreed',
              agreedToTerms ? 'Yes' : 'No',
            ),
            const SizedBox(height: 4),
            const Text(
              'Business description',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                businessDescription.isEmpty
                    ? 'No business description provided'
                    : businessDescription,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isBusy
                        ? null
                        : () => _updateSellerStatus(
                              userId: userId,
                              status: 'active',
                              successMessage: 'Seller approved successfully',
                            ),
                    child: isBusy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy
                        ? null
                        : () => _updateSellerStatus(
                              userId: userId,
                              status: 'rejected',
                              successMessage: 'Seller rejected successfully',
                            ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
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

    if (_pendingSellers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPendingRequests,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 42,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No Pending Requests',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'There are currently no seller applications waiting for review.',
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingRequests,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pending Seller Requests',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_pendingSellers.length} request(s) waiting for review',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ..._pendingSellers.map(_requestCard),
        ],
      ),
    );
  }
}