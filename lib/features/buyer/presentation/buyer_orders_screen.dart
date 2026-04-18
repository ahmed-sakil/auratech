import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import 'widgets/buyer_bottom_nav_bar.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  bool _isLoadingOrders = true;
  List<Map<String, dynamic>> _orders = [];
  int _selectedTabIndex = 0;

  static const List<String> _activeStatuses = [
    'pending',
    'processing',
    'confirmed',
    'on_the_way',
  ];

  static const List<String> _deliveredStatuses = [
    'delivered',
  ];

  static const List<String> _cancelledStatuses = [
    'cancelled',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
          'items':
              itemsByOrderId[order['id'] as String] ?? <Map<String, dynamic>>[],
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

  String _formatOrderId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8).toUpperCase();
  }

  String _formatDate(String raw) {
    final dateTime = DateTime.tryParse(raw);
    if (dateTime == null) return raw;
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _displayStatus(String value) {
    return value.replaceAll('_', ' ');
  }

  String _normalizedOrderStatus(Map<String, dynamic> order) {
    final status = ((order['order_status'] as String?) ?? 'pending').trim();
    return status.toLowerCase();
  }

  List<Map<String, dynamic>> _filteredOrders() {
    if (_selectedTabIndex == 0) {
      return _orders
          .where((order) => _activeStatuses.contains(_normalizedOrderStatus(order)))
          .toList();
    }

    if (_selectedTabIndex == 1) {
      return _orders
          .where(
            (order) => _deliveredStatuses.contains(_normalizedOrderStatus(order)),
          )
          .toList();
    }

    return _orders
        .where(
          (order) => _cancelledStatuses.contains(_normalizedOrderStatus(order)),
        )
        .toList();
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
      case 'pending':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildStatusChip(String value) {
    final normalized = value.toLowerCase();
    final color = _statusColor(normalized);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _displayStatus(value),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required int count,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.white.withValues(alpha: 0.92)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Card(
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
            trailing: _buildStatusChip(orderStatus),
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
                      'Payment Status: ${_displayStatus(paymentStatus)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order Status: ${_displayStatus(orderStatus)}',
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
      ),
    );
  }

  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(
                icon,
                size: 44,
                color: AppColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
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

    final activeOrders = _orders
        .where((order) => _activeStatuses.contains(_normalizedOrderStatus(order)))
        .toList();
    final deliveredOrders = _orders
        .where(
          (order) => _deliveredStatuses.contains(_normalizedOrderStatus(order)),
        )
        .toList();
    final cancelledOrders = _orders
        .where(
          (order) => _cancelledStatuses.contains(_normalizedOrderStatus(order)),
        )
        .toList();

    final visibleOrders = _filteredOrders();

    return ListView(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'My Orders',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total orders: ${_orders.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _buildTabButton(
                        label: 'Active',
                        index: 0,
                        count: activeOrders.length,
                      ),
                      const SizedBox(width: 10),
                      _buildTabButton(
                        label: 'Delivered',
                        index: 1,
                        count: deliveredOrders.length,
                      ),
                      const SizedBox(width: 10),
                      _buildTabButton(
                        label: 'Cancelled',
                        index: 2,
                        count: cancelledOrders.length,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_orders.isEmpty)
          _buildEmptyTabState(
            icon: Icons.receipt_long_outlined,
            title: 'No Orders Yet',
            subtitle: 'Your placed orders will appear here.',
          )
        else if (visibleOrders.isEmpty && _selectedTabIndex == 0)
          _buildEmptyTabState(
            icon: Icons.local_shipping_outlined,
            title: 'No Active Orders',
            subtitle:
                'Orders that are pending, processing, confirmed, or on the way will appear here.',
          )
        else if (visibleOrders.isEmpty && _selectedTabIndex == 1)
          _buildEmptyTabState(
            icon: Icons.inventory_2_outlined,
            title: 'No Delivered Orders',
            subtitle: 'Your completed delivered orders will appear here.',
          )
        else if (visibleOrders.isEmpty && _selectedTabIndex == 2)
          _buildEmptyTabState(
            icon: Icons.cancel_outlined,
            title: 'No Cancelled Orders',
            subtitle: 'Rejected or cancelled orders will appear here.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildOrderCard(visibleOrders[index]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildOrdersView(),
          ),
        ),
      ),
      bottomNavigationBar: const BuyerBottomNavBar(
        currentRoute: AppRoutes.buyerOrders,
      ),
    );
  }
}