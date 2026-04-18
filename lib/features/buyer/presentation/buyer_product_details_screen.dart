import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';

class BuyerProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const BuyerProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<BuyerProductDetailsScreen> createState() =>
      _BuyerProductDetailsScreenState();
}

class _BuyerProductDetailsScreenState
    extends State<BuyerProductDetailsScreen> {
  bool _isAddingToCart = false;

  Future<void> _addToCart() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final productId = widget.product['id'] as String;
    final stock = widget.product['stock'] as int;

    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is out of stock')),
      );
      return;
    }

    setState(() {
      _isAddingToCart = true;
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
        _isAddingToCart = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    final name = (product['name'] as String?) ?? '';
    final description = (product['description'] as String?) ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = (product['stock'] as int?) ?? 0;
    final category = (product['category'] as String?) ?? '';
    final subcategory = (product['subcategory'] as String?) ?? '';
    final imageUrl =
        (product['image_url'] as String?) ??
        (product['image_path'] as String?) ??
        '';
    final tags = List<String>.from(product['tags'] as List? ?? []);

    final isOutOfStock = stock <= 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Product Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: AppColors.surfaceSoft,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 44,
                            color: AppColors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          if (subcategory.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                subcategory,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? AppColors.error.withValues(alpha: 0.12)
                                  : const Color(0xFFEAF8EF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isOutOfStock ? 'Out of Stock' : 'Available',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isOutOfStock
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '৳${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Available stock: $stock',
                        style: TextStyle(
                          fontSize: 14,
                          color: isOutOfStock
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Product Description',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty
                            ? 'No description available for this product.'
                            : description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: isOutOfStock || _isAddingToCart ? null : _addToCart,
            icon: _isAddingToCart
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_shopping_cart_outlined),
            label: Text(
              isOutOfStock
                  ? 'Out of Stock'
                  : _isAddingToCart
                  ? 'Adding...'
                  : 'Add to Cart',
            ),
          ),
        ),
      ),
    );
  }
}