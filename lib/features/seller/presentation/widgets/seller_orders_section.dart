import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

class SellerOrdersSection extends StatefulWidget {
  const SellerOrdersSection({super.key});

  @override
  State<SellerOrdersSection> createState() => _SellerOrdersSectionState();
}

class _SellerOrdersSectionState extends State<SellerOrdersSection> {
  bool _isLoadingOrders = true;
  List<Map<String, dynamic>> _orders = [];

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
          .eq('seller_id', user.id)
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
      final buyerIds =
          orders.map((order) => order['buyer_id'] as String).toSet().toList();

      final orderItemsResponse = await Supabase.instance.client
          .from('order_items')
          .select()
          .inFilter('order_id', orderIds);

      final orderItems = List<Map<String, dynamic>>.from(orderItemsResponse);

      final buyerMap = <String, Map<String, dynamic>>{};
      if (buyerIds.isNotEmpty) {
        final buyersResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, email')
            .inFilter('id', buyerIds);

        for (final buyer in List<Map<String, dynamic>>.from(buyersResponse)) {
          buyerMap[buyer['id'] as String] = buyer;
        }
      }

      final itemsByOrderId = <String, List<Map<String, dynamic>>>{};
      for (final item in orderItems) {
        final orderId = item['order_id'] as String;
        itemsByOrderId.putIfAbsent(orderId, () => []);
        itemsByOrderId[orderId]!.add(item);
      }

      final mergedOrders = orders.map((order) {
        final buyerId = order['buyer_id'] as String;
        return {
          ...order,
          'buyer_profile': buyerMap[buyerId],
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

  Future<void> _updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
  }) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'payment_status': paymentStatus})
          .eq('id', orderId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment status updated')),
      );

      await _loadOrders();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update payment status')),
      );
    }
  }

  Future<void> _updateOrderStatus({
    required String orderId,
    required String orderStatus,
  }) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'order_status': orderStatus})
          .eq('id', orderId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated')),
      );

      await _loadOrders();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update order status')),
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

  bool _isDeliveredGroup(Map<String, dynamic> order) {
    final orderStatus = (order['order_status'] as String?) ?? 'pending';
    return orderStatus == 'delivered' || orderStatus == 'cancelled';
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
    final buyer = order['buyer_profile'] as Map<String, dynamic>?;

    final buyerName = (buyer?['full_name'] as String?)?.trim();
    final buyerEmail = (buyer?['email'] as String?) ?? '';

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
                    'Buyer Information',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Name: ${(buyerName != null && buyerName.isNotEmpty) ? buyerName : 'Unknown'}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Email: ${buyerEmail.isEmpty ? 'Not available' : buyerEmail}',
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
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: paymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Payment Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('pending'),
                      ),
                      DropdownMenuItem(
                        value: 'verified',
                        child: Text('verified'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('rejected'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null || value == paymentStatus) return;
                      await _updatePaymentStatus(
                        orderId: orderId,
                        paymentStatus: value,
                      );
                    },
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
                    'Order Progress',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: orderStatus,
                    decoration: const InputDecoration(
                      labelText: 'Order Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('pending'),
                      ),
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('confirmed'),
                      ),
                      DropdownMenuItem(
                        value: 'processing',
                        child: Text('processing'),
                      ),
                      DropdownMenuItem(
                        value: 'on_the_way',
                        child: Text('on_the_way'),
                      ),
                      DropdownMenuItem(
                        value: 'delivered',
                        child: Text('delivered'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('cancelled'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null || value == orderStatus) return;
                      await _updateOrderStatus(
                        orderId: orderId,
                        orderStatus: value,
                      );
                    },
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

  Widget _buildOrderGroup({
    required String title,
    required List<Map<String, dynamic>> orders,
  }) {
    if (orders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.inbox_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                'No $title orders',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  '$title Orders (${orders.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...orders.map(_buildOrderCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOrders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final pendingOrders =
        _orders.where((order) => !_isDeliveredGroup(order)).toList();
    final deliveredOrders =
        _orders.where((order) => _isDeliveredGroup(order)).toList();

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderGroup(
            title: 'Pending / Active',
            orders: pendingOrders,
          ),
          const SizedBox(height: 18),
          _buildOrderGroup(
            title: 'Delivered / Closed',
            orders: deliveredOrders,
          ),
        ],
      ),
    );
  }
}