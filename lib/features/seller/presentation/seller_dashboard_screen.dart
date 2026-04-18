import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingProducts = true;
  bool _isLoadingOrders = true;
  bool _showOrdersView = false;

  PlatformFile? _selectedFile;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadOrders();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out')),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedFile = result.files.first;
    });
  }

  Future<void> _loadProducts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingProducts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load products')),
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
      final buyerIds = orders.map((order) => order['buyer_id'] as String).toSet().toList();

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

  String _publicImageUrl(String imagePath) {
    return Supabase.instance.client.storage
        .from('product-images')
        .getPublicUrl(imagePath);
  }

  Future<String> _uploadImage({
    required String userId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Image bytes not found');
    }

    final safeFileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
    final storagePath = '$userId/$safeFileName';

    await Supabase.instance.client.storage
        .from('product-images')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return storagePath;
  }

  Future<void> _addProduct() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.trim();
    final stockText = _stockController.text.trim();

    if (name.isEmpty ||
        description.isEmpty ||
        priceText.isEmpty ||
        stockText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product image')),
      );
      return;
    }

    final price = double.tryParse(priceText);
    final stock = int.tryParse(stockText);

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    if (stock == null || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid stock value')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final imagePath = await _uploadImage(
        userId: user.id,
        file: _selectedFile!,
      );

      await Supabase.instance.client.from('products').insert({
        'seller_id': user.id,
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'image_path': imagePath,
      });

      if (!mounted) return;

      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _stockController.clear();

      setState(() {
        _selectedFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully')),
      );

      await _loadProducts();
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add product')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
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

  Widget _buildStatusChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(value).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _statusColor(value).withValues(alpha: 0.35)),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _statusColor(value),
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
                child: const Text('Products'),
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

  Widget _buildAddProductCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Product',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your product listing.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product name',
                hintText: 'Enter product name',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter product description',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price',
                hintText: 'Enter product price',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock',
                hintText: 'Enter stock quantity',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedFile == null
                          ? 'No image selected'
                          : _selectedFile!.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickImage,
                    child: const Text('Choose Image'),
                  ),
                ],
              ),
            ),
            if (_selectedFile != null && _selectedFile!.bytes != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  Uint8List.fromList(_selectedFile!.bytes!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _addProduct,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsCard() {
    if (_isLoadingProducts) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              Icon(
                Icons.inventory_2_outlined,
                size: 42,
                color: AppColors.primary,
              ),
              SizedBox(height: 14),
              Text(
                'No Products Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your added products will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Products',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final product = _products[index];
                final imageUrl = _publicImageUrl(product['image_path'] as String);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          height: 90,
                          width: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 90,
                            width: 90,
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (product['name'] as String?) ?? '',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (product['description'] as String?) ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Price: ৳${product['price']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stock: ${product['stock']}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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
                _buildStatusChip('payment', paymentStatus),
                _buildStatusChip('order', orderStatus),
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

  Widget _buildOrdersCard() {
    if (_isLoadingOrders) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
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
                'Incoming buyer orders will appear here.',
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
              children: const [
                Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                ),
                SizedBox(width: 10),
                Text(
                  'Incoming Orders',
                  style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              if (_showOrdersView) {
                await _loadOrders();
              } else {
                await _loadProducts();
              }
            },
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
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionToggle(),
              const SizedBox(height: 16),
              if (_showOrdersView) _buildOrdersCard() else ...[
                _buildAddProductCard(),
                const SizedBox(height: 16),
                _buildProductsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}