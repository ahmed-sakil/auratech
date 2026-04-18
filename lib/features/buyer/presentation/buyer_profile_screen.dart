import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import 'widgets/buyer_bottom_nav_bar.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  bool _isLoadingProfile = true;
  bool _isLoadingOrders = true;
  bool _showOrdersView = false;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadOrders();
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
        const SnackBar(content: Text('Could not load profile')),
      );
    }
  }

  Future<void> _loadOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final ordersResponse = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final orders = List<Map<String, dynamic>>.from(ordersResponse);

      if (orders.isEmpty) {
        if (!mounted) return;

        setState(() {
          _orders = [];
          _isLoadingOrders = false;
        });
        return;
      }

      final orderIds = orders.map((order) => order['id'] as String).toList();
      final sellerIds = orders
          .map((order) => order['seller_id'] as String)
          .toSet()
          .toList();

      final orderItemsResponse = await Supabase.instance.client
          .from('order_items')
          .select()
          .inFilter('order_id', orderIds);

      final orderItems = List<Map<String, dynamic>>.from(orderItemsResponse);

      final sellerMap = <String, Map<String, dynamic>>{};
      if (sellerIds.isNotEmpty) {
        final sellersResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, email')
            .inFilter('id', sellerIds);

        for (final seller in List<Map<String, dynamic>>.from(sellersResponse)) {
          sellerMap[seller['id'] as String] = seller;
        }
      }

      final itemsByOrderId = <String, List<Map<String, dynamic>>>{};
      for (final item in orderItems) {
        final orderId = item['order_id'] as String;
        itemsByOrderId.putIfAbsent(orderId, () => []);
        itemsByOrderId[orderId]!.add(item);
      }

      final mergedOrders = orders.map((order) {
        final sellerId = order['seller_id'] as String;

        return {
          ...order,
          'seller_profile': sellerMap[sellerId],
          'items': itemsByOrderId[order['id'] as String] ?? <Map<String, dynamic>>[],
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _orders = mergedOrders;
        _isLoadingOrders = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingOrders = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load orders')),
      );
    }
  }

  Future<void> _refreshCurrentView() async {
    if (_showOrdersView) {
      await _loadOrders();
    } else {
      await _loadProfile();
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out')),
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

  String _formatOrderId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8).toUpperCase();
  }

  String _formatDate(String raw) {
    final dateTime = DateTime.tryParse(raw);
    if (dateTime == null) return raw;
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'verified':
      case 'delivered':
      case 'active':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
      case 'banned':
        return Colors.red;
      case 'processing':
      case 'on_the_way':
      case 'confirmed':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildStatusChip(String value) {
    final color = _statusColor(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSectionToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    _showOrdersView = false;
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _showOrdersView ? AppColors.surface : AppColors.primary,
                ),
                child: const Text('Profile'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    _showOrdersView = true;
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _showOrdersView ? AppColors.primary : AppColors.surface,
                ),
                child: const Text('Orders'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                'We could not load your profile information.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final fullName = (_profile!['full_name'] as String?) ?? '';
    final email = (_profile!['email'] as String?) ?? '';
    final role = (_profile!['role'] as String?) ?? '';
    final status = (_profile!['status'] as String?) ?? '';

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 34,
                  child: Icon(Icons.person, size: 34),
                ),
                const SizedBox(height: 14),
                Text(
                  fullName.isEmpty ? 'Buyer' : fullName,
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
        _infoTile(
          icon: Icons.person_outline,
          label: 'Full Name',
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
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] as String;
    final createdAt = (order['created_at'] as String?) ?? '';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = (order['payment_method'] as String?) ?? '';
    final paymentStatus = (order['payment_status'] as String?) ?? 'pending';
    final trxId = (order['trx_id'] as String?) ?? '';
    final orderStatus = (order['order_status'] as String?) ?? 'pending';
    final items =
        List<Map<String, dynamic>>.from(order['items'] as List<dynamic>? ?? []);
    final seller = order['seller_profile'] as Map<String, dynamic>?;

    final sellerName = (seller?['full_name'] as String?)?.trim();
    final sellerEmail = (seller?['email'] as String?) ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            'Order #${_formatOrderId(orderId)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Placed: ${_formatDate(createdAt)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          children: [
            const SizedBox(height: 8),
            Container(
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
                  const Text(
                    'Seller Information',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Name: ${(sellerName != null && sellerName.isNotEmpty) ? sellerName : 'Unknown'}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Email: ${sellerEmail.isEmpty ? 'Not available' : sellerEmail}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: ৳${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildStatusChip(paymentStatus),
                _buildStatusChip(orderStatus),
              ],
            ),
            const SizedBox(height: 14),
            Container(
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
                  const Text(
                    'Payment',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Method: $paymentMethod',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transaction ID: ${trxId.isEmpty ? 'Not provided' : trxId}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payment Status: $paymentStatus',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order Status: $orderStatus',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
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
                  const Text(
                    'Ordered Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Text(
                      'No order items found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final name = (item['product_name'] as String?) ?? '';
                        final quantity = item['quantity'] ?? 0;
                        final price =
                            (item['product_price'] as num?)?.toDouble() ?? 0;
                        final lineTotal =
                            (item['line_total'] as num?)?.toDouble() ?? 0;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: $quantity',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Unit Price: ৳${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '৳${lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersView() {
    if (_isLoadingOrders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_orders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              Icon(
                Icons.receipt_long_outlined,
                size: 42,
                color: AppColors.primary,
              ),
              SizedBox(height: 14),
              Text(
                'No Orders Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your placed orders will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'My Orders (${_orders.length})',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
        ),
      ],
    );
  }

  Widget _body() {
    return ListView(
      children: [
        _buildSectionToggle(),
        const SizedBox(height: 16),
        if (_showOrdersView) _buildOrdersView() else _buildProfileView(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showOrdersView ? 'My Orders' : 'My Profile'),
        actions: [
          IconButton(
            onPressed: _refreshCurrentView,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _body(),
          ),
        ),
      ),
      bottomNavigationBar: BuyerBottomNavBar(
        currentRoute: AppRoutes.buyerProfile,
      ),
    );
  }
}