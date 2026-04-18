import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class BuyerProductGridCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const BuyerProductGridCard({
    super.key,
    required this.product,
    required this.imageUrl,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final name = (product['name'] as String?) ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = (product['stock'] as int?) ?? 0;
    final category = (product['category'] as String?) ?? '';
    final subcategory = (product['subcategory'] as String?) ?? '';
    final description = (product['description'] as String?) ?? '';
    final tags = List<String>.from(product['tags'] as List? ?? []);

    final isOutOfStock = stock <= 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
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
              Expanded(
                flex: 8,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
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
                                size: 34,
                                color: AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? AppColors.error.withValues(alpha: 0.92)
                              : AppColors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isOutOfStock ? 'Out of Stock' : 'In Stock',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOutOfStock
                                ? AppColors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.favorite_border,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$category • $subcategory',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty ? 'No description available' : description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags.take(2).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '৳${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 40,
                            child: FilledButton(
                              onPressed: isOutOfStock ? null : onAddToCart,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: Icon(
                                isOutOfStock
                                    ? Icons.block_outlined
                                    : Icons.add_shopping_cart_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stock: $stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOutOfStock
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}