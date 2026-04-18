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

      final merged = cartItems.map((item) {
        final product = productMap[item['product_id'] as String];
        return {
          ...item,
          'product': product,
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

  double _totalPrice() {
    double total = 0;

    for (final item in _cartItems) {
      final product = item['product'] as Map<String, dynamic>?;
      if (product == null) continue;

      final price = (product['price'] as num).toDouble();
      final quantity = item['quantity'] as int;
      total += price * quantity;
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

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _cartItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = _cartItems[index];
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
              final imageUrl =
                  _publicImageUrl((product['image_path'] as String?) ?? '');
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
                    'Cart Total',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '৳${_totalPrice().toStringAsFixed(2)}',
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
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(),
          ),
        ),
      ),
      bottomNavigationBar: const BuyerBottomNavBar(
        currentRoute: AppRoutes.buyerCart,
      ),
    );
  }
}