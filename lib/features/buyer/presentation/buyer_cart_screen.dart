import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import 'widgets/buyer_bottom_nav_bar.dart';

class BuyerCartScreen extends StatefulWidget {
  const BuyerCartScreen({super.key});

  @override
  State<BuyerCartScreen> createState() => _BuyerCartScreenState();
}

class _BuyerCartScreenState extends State<BuyerCartScreen> {
  bool _isLoading = true;
  Set<String> _updatingCartItemIds = {};
  Set<String> _placingSellerOrderIds = {};
  List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final cartResponse = await Supabase.instance.client
          .from('cart_items')
          .select()
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final cartItems = List<Map<String, dynamic>>.from(cartResponse);

      if (cartItems.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cartItems = [];
          _isLoading = false;
        });
        return;
      }

      final productIds = cartItems.map((e) => e['product_id'] as String).toList();

      final productResponse = await Supabase.instance.client
          .from('products')
          .select()
          .inFilter('id', productIds);

      final products = List<Map<String, dynamic>>.from(productResponse);

      final productMap = <String, Map<String, dynamic>>{};
      for (final product in products) {
        productMap[product['id'] as String] = product;
      }

      final sellerIds = products
          .map((product) => product['seller_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final sellerMap = <String, Map<String, dynamic>>{};

      if (sellerIds.isNotEmpty) {
        final sellerResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, email')
            .inFilter('id', sellerIds);

        final sellers = List<Map<String, dynamic>>.from(sellerResponse);

        for (final seller in sellers) {
          sellerMap[seller['id'] as String] = seller;
        }
      }

      final merged = cartItems.map((item) {
        final product = productMap[item['product_id'] as String];
        Map<String, dynamic>? seller;

        if (product != null) {
          final sellerId = product['seller_id'] as String?;
          if (sellerId != null) {
            seller = sellerMap[sellerId];
          }
        }

        return {
          ...item,
          'product': product,
          'seller': seller,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _cartItems = merged;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load cart items')),
      );
    }
  }

  Future<void> _removeCartItem(String cartItemId) async {
    try {
      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .eq('id', cartItemId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from cart')),
      );

      await _loadCartItems();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove item')),
      );
    }
  }

  Future<void> _increaseQuantity(Map<String, dynamic> item) async {
    final cartItemId = item['id'] as String;
    final product = item['product'] as Map<String, dynamic>?;
    if (product == null) return;

    final currentQuantity = item['quantity'] as int;
    final stock = product['stock'] as int;

    if (currentQuantity >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity cannot be greater than available stock'),
        ),
      );
      return;
    }

    setState(() {
      _updatingCartItemIds = {..._updatingCartItemIds, cartItemId};
    });

    try {
      await Supabase.instance.client
          .from('cart_items')
          .update({'quantity': currentQuantity + 1})
          .eq('id', cartItemId);

      if (!mounted) return;
      await _loadCartItems();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not increase quantity')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _updatingCartItemIds = {..._updatingCartItemIds}..remove(cartItemId);
      });
    }
  }

  Future<void> _decreaseQuantity(Map<String, dynamic> item) async {
    final cartItemId = item['id'] as String;
    final currentQuantity = item['quantity'] as int;

    setState(() {
      _updatingCartItemIds = {..._updatingCartItemIds, cartItemId};
    });

    try {
      if (currentQuantity <= 1) {
        await Supabase.instance.client
            .from('cart_items')
            .delete()
            .eq('id', cartItemId);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from cart')),
        );
      } else {
        await Supabase.instance.client
            .from('cart_items')
            .update({'quantity': currentQuantity - 1})
            .eq('id', cartItemId);
      }

      if (!mounted) return;
      await _loadCartItems();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not decrease quantity')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _updatingCartItemIds = {..._updatingCartItemIds}..remove(cartItemId);
      });
    }
  }

  String _publicImageUrl(String imagePath) {
    return Supabase.instance.client.storage
        .from('product-images')
        .getPublicUrl(imagePath);
  }

  Map<String, List<Map<String, dynamic>>> _groupedBySeller() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in _cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      final sellerId = product?['seller_id'] as String? ?? 'unknown';

      grouped.putIfAbsent(sellerId, () => []);
      grouped[sellerId]!.add(item);
    }

    return grouped;
  }

  double _sellerSubtotal(List<Map<String, dynamic>> items) {
    double total = 0;

    for (final item in items) {
      final product = item['product'] as Map<String, dynamic>?;
      if (product == null) continue;

      final price = (product['price'] as num).toDouble();
      final quantity = item['quantity'] as int;
      total += price * quantity;
    }

    return total;
  }

  double _grandTotal() {
    double total = 0;

    for (final sellerItems in _groupedBySeller().values) {
      total += _sellerSubtotal(sellerItems);
    }

    return total;
  }

  Widget _quantityControl(Map<String, dynamic> item) {
    final cartItemId = item['id'] as String;
    final quantity = item['quantity'] as int;
    final isUpdating = _updatingCartItemIds.contains(cartItemId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: isUpdating ? null : () => _decreaseQuantity(item),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: isUpdating ? null : () => _increaseQuantity(item),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<bool> _validateSellerItemsBeforeCheckout(
    String sellerId,
    List<Map<String, dynamic>> items,
  ) async {
    final productIds = items
        .map((item) => item['product_id'] as String)
        .toList();

    final liveProducts = await Supabase.instance.client
        .from('products')
        .select('id, seller_id, stock, price, name')
        .inFilter('id', productIds);

    final liveProductMap = <String, Map<String, dynamic>>{};
    for (final product in List<Map<String, dynamic>>.from(liveProducts)) {
      liveProductMap[product['id'] as String] = product;
    }

    for (final item in items) {
      final cartProductId = item['product_id'] as String;
      final liveProduct = liveProductMap[cartProductId];

      if (liveProduct == null) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A product no longer exists')),
        );
        return false;
      }

      final liveSellerId = liveProduct['seller_id'] as String?;
      if (liveSellerId != sellerId) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checkout seller mismatch detected')),
        );
        return false;
      }

      final stock = liveProduct['stock'] as int;
      final quantity = item['quantity'] as int;

      if (stock < quantity) {
        if (!mounted) return false;
        final productName = (liveProduct['name'] as String?) ?? 'product';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough stock for $productName. Please update your cart.',
            ),
          ),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _placeSellerOrder({
    required String sellerId,
    required String paymentMethod,
    required String? trxId,
    required List<Map<String, dynamic>> items,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _placingSellerOrderIds = {..._placingSellerOrderIds, sellerId};
    });

    String? createdOrderId;

    try {
      final isValid = await _validateSellerItemsBeforeCheckout(sellerId, items);
      if (!isValid) return;

      final subtotal = _sellerSubtotal(items);

      final orderInsert = await Supabase.instance.client
          .from('orders')
          .insert({
            'buyer_id': user.id,
            'seller_id': sellerId,
            'total_amount': subtotal,
            'payment_method': paymentMethod,
            'payment_status': 'pending',
            'trx_id': trxId == null || trxId.trim().isEmpty ? null : trxId.trim(),
            'order_status': 'pending',
          })
          .select('id')
          .single();

      createdOrderId = orderInsert['id'] as String;

      final orderItemsPayload = items.map((item) {
        final product = item['product'] as Map<String, dynamic>;
        final quantity = item['quantity'] as int;
        final price = (product['price'] as num).toDouble();

        return {
          'order_id': createdOrderId,
          'product_id': product['id'],
          'buyer_id': user.id,
          'seller_id': sellerId,
          'product_name': (product['name'] as String?) ?? '',
          'product_price': price,
          'quantity': quantity,
          'line_total': price * quantity,
        };
      }).toList();

      await Supabase.instance.client
          .from('order_items')
          .insert(orderItemsPayload);

      final cartItemIds = items.map((item) => item['id'] as String).toList();

      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .inFilter('id', cartItemIds);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully')),
      );

      await _loadCartItems();
    } catch (_) {
      if (createdOrderId != null) {
        try {
          await Supabase.instance.client
              .from('orders')
              .delete()
              .eq('id', createdOrderId);
        } catch (_) {}
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not place order')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _placingSellerOrderIds = {..._placingSellerOrderIds}..remove(sellerId);
      });
    }
  }

  Future<void> _openCheckoutDialog(
    String sellerId,
    String sellerTitle,
    List<Map<String, dynamic>> items,
  ) async {
    String paymentMethod = 'cod';
    final trxController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final needsTrx = paymentMethod != 'cod';
            final subtotal = _sellerSubtotal(items);

            return AlertDialog(
              title: const Text('Checkout This Seller'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sellerTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Subtotal: ৳${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        items: const [
                          DropdownMenuItem(
                            value: 'cod',
                            child: Text('Cash on Delivery'),
                          ),
                          DropdownMenuItem(
                            value: 'bkash',
                            child: Text('bKash'),
                          ),
                          DropdownMenuItem(
                            value: 'nagad',
                            child: Text('Nagad'),
                          ),
                          DropdownMenuItem(
                            value: 'rocket',
                            child: Text('Rocket'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            paymentMethod = value;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (needsTrx) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: trxController,
                          decoration: const InputDecoration(
                            labelText: 'Transaction ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter the transaction id for your mobile financial service payment.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (paymentMethod != 'cod' &&
                        trxController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction ID is required'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop();

                    await _placeSellerOrder(
                      sellerId: sellerId,
                      paymentMethod: paymentMethod,
                      trxId: paymentMethod == 'cod'
                          ? null
                          : trxController.text.trim(),
                      items: items,
                    );
                  },
                  child: const Text('Confirm Order'),
                ),
              ],
            );
          },
        );
      },
    );

    trxController.dispose();
  }

  Widget _buildCartItemCard(Map<String, dynamic> item) {
    final product = item['product'] as Map<String, dynamic>?;

    if (product == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Product not found',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => _removeCartItem(item['id'] as String),
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
      );
    }

    final quantity = item['quantity'] as int;
    final stock = product['stock'] as int;
    final imageUrl = _publicImageUrl((product['image_path'] as String?) ?? '');
    final price = (product['price'] as num).toDouble();
    final lineTotal = price * quantity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                    'Price: ৳$price',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available stock: $stock',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _quantityControl(item),
                  const SizedBox(height: 10),
                  Text(
                    'Total: ৳${lineTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _removeCartItem(item['id'] as String),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerSection(
    String sellerId,
    List<Map<String, dynamic>> items,
  ) {
    final firstSeller = items.first['seller'] as Map<String, dynamic>?;
    final sellerName = (firstSeller?['full_name'] as String?)?.trim();
    final sellerEmail = (firstSeller?['email'] as String?) ?? '';
    final title = (sellerName != null && sellerName.isNotEmpty)
        ? sellerName
        : 'Seller ${sellerId.substring(0, sellerId.length >= 8 ? 8 : sellerId.length)}';

    final subtotal = _sellerSubtotal(items);
    final isPlacing = _placingSellerOrderIds.contains(sellerId);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (sellerEmail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sellerEmail,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...items.map(_buildCartItemCard),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Seller Subtotal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '৳${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isPlacing
                          ? null
                          : () => _openCheckoutDialog(sellerId, title, items),
                      child: isPlacing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Checkout This Seller'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.shopping_cart_outlined,
                size: 42,
                color: AppColors.primary,
              ),
              SizedBox(height: 14),
              Text(
                'Your Cart Is Empty',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Products you add will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupedBySeller();
    final sellerIds = grouped.keys.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: sellerIds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final sellerId = sellerIds[index];
              final items = grouped[sellerId]!;
              return _buildSellerSection(sellerId, items);
            },
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'All Cart Total',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '৳${_grandTotal().toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          IconButton(
            onPressed: _loadCartItems,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(),
          ),
        ),
      ),
      bottomNavigationBar: BuyerBottomNavBar(
        currentRoute: AppRoutes.buyerCart,
      ),
    );
  }
}