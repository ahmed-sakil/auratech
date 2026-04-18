import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';
import 'widgets/buyer_bottom_nav_bar.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  bool _isLoading = true;
  Set<String> _addingProductIds = {};
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load products')),
      );
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final productId = product['id'] as String;
    final stock = product['stock'] as int;

    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is out of stock')),
      );
      return;
    }

    setState(() {
      _addingProductIds = {..._addingProductIds, productId};
    });

    try {
      final existing = await Supabase.instance.client
          .from('cart_items')
          .select()
          .eq('buyer_id', user.id)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing == null) {
        await Supabase.instance.client.from('cart_items').insert({
          'buyer_id': user.id,
          'product_id': productId,
          'quantity': 1,
        });
      } else {
        final currentQuantity = existing['quantity'] as int;

        if (currentQuantity >= stock) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cart quantity already reached available stock'),
            ),
          );
          return;
        }

        await Supabase.instance.client
            .from('cart_items')
            .update({'quantity': currentQuantity + 1})
            .eq('id', existing['id']);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add to cart')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _addingProductIds = {..._addingProductIds}..remove(productId);
      });
    }
  }

  String _publicImageUrl(String imagePath) {
    return Supabase.instance.client.storage
        .from('product-images')
        .getPublicUrl(imagePath);
  }

  Widget _productCard(Map<String, dynamic> product) {
    final productId = product['id'] as String;
    final name = (product['name'] as String?) ?? '';
    final description = (product['description'] as String?) ?? '';
    final price = product['price'];
    final stock = product['stock'] as int;
    final imagePath = (product['image_path'] as String?) ?? '';
    final imageUrl = _publicImageUrl(imagePath);
    final isAdding = _addingProductIds.contains(productId);

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
                height: 96,
                width: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 96,
                  width: 96,
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
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '৳$price',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stock > 0 ? 'In stock: $stock' : 'Out of stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: stock > 0
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 150,
                    child: FilledButton(
                      onPressed: stock > 0 && !isAdding
                          ? () => _addToCart(product)
                          : null,
                      child: isAdding
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add to Cart'),
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

  Widget _body() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.storefront_outlined,
                size: 42,
                color: AppColors.primary,
              ),
              SizedBox(height: 14),
              Text(
                'No Products Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Approved seller products will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _productCard(_products[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Home'),
        actions: [
          IconButton(
            onPressed: _loadProducts,
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
      bottomNavigationBar: const BuyerBottomNavBar(
        currentRoute: AppRoutes.buyerHome,
      ),
    );
  }
}