import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/product_taxonomy.dart';
import '../../../core/router/app_routes.dart';
import 'widgets/buyer_bottom_nav_bar.dart';
import 'widgets/buyer_category_filter_bar.dart';
import 'widgets/buyer_filter_sheet.dart';
import 'widgets/buyer_product_grid_card.dart';
import 'widgets/buyer_product_search_bar.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  bool _isLoading = true;
  Set<String> _addingProductIds = {};
  List<Map<String, dynamic>> _products = [];
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String? _selectedSubcategory;
  String _minPrice = '';
  String _maxPrice = '';

  List<String> get _categoryOptions => [
        'All',
        ...ProductTaxonomy.categoryList,
      ];

  int get _activeFilterCount {
    var count = 0;

    if (_selectedCategory != 'All') count++;
    if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
      count++;
    }
    if (_minPrice.trim().isNotEmpty) count++;
    if (_maxPrice.trim().isNotEmpty) count++;

    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BuyerFilterSheet(
        selectedCategory: _selectedCategory,
        selectedSubcategory: _selectedSubcategory,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedCategory = (result['category'] as String?) ?? 'All';
      _selectedSubcategory = result['subcategory'] as String?;
      _minPrice = (result['minPrice'] as String?) ?? '';
      _maxPrice = (result['maxPrice'] as String?) ?? '';
    });
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

  bool _matchesSearch(Map<String, dynamic> product, String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return true;
    }

    final name = ((product['name'] as String?) ?? '').toLowerCase();
    final description = ((product['description'] as String?) ?? '').toLowerCase();
    final category = ((product['category'] as String?) ?? '').toLowerCase();
    final subcategory =
        ((product['subcategory'] as String?) ?? '').toLowerCase();

    final dynamic rawTags = product['tags'];
    final tags = rawTags is List
        ? rawTags.map((tag) => tag.toString().toLowerCase()).toList()
        : <String>[];

    if (name.contains(normalizedQuery)) return true;
    if (description.contains(normalizedQuery)) return true;
    if (category.contains(normalizedQuery)) return true;
    if (subcategory.contains(normalizedQuery)) return true;

    for (final tag in tags) {
      if (tag.contains(normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  bool _matchesCategory(Map<String, dynamic> product) {
    if (_selectedCategory == 'All') {
      return true;
    }

    final category = ((product['category'] as String?) ?? '').trim();
    return category == _selectedCategory;
  }

  bool _matchesSubcategory(Map<String, dynamic> product) {
    if (_selectedSubcategory == null || _selectedSubcategory!.isEmpty) {
      return true;
    }

    final subcategory = ((product['subcategory'] as String?) ?? '').trim();
    return subcategory == _selectedSubcategory;
  }

  bool _matchesPriceRange(Map<String, dynamic> product) {
    final rawPrice = product['price'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice.toString()) ?? 0;

    final min = double.tryParse(_minPrice.trim());
    final max = double.tryParse(_maxPrice.trim());

    if (min != null && price < min) return false;
    if (max != null && price > max) return false;

    return true;
  }

  List<Map<String, dynamic>> _filteredProducts() {
    final query = _searchController.text;

    return _products.where((product) {
      final matchesText = _matchesSearch(product, query);
      final matchesCategory = _matchesCategory(product);
      final matchesSubcategory = _matchesSubcategory(product);
      final matchesPrice = _matchesPriceRange(product);

      return matchesText &&
          matchesCategory &&
          matchesSubcategory &&
          matchesPrice;
    }).toList();
  }

  void _openProductDetails(Map<String, dynamic> product) {
    final imagePath = (product['image_path'] as String?) ?? '';
    final imageUrl = _publicImageUrl(imagePath);

    context.push(
      AppRoutes.buyerProductDetails,
      extra: {
        ...product,
        'image_url': imageUrl,
      },
    );
  }

  Widget _buildFilterButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openFilterSheet,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.tune,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        if (_activeFilterCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _activeFilterCount.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> filteredProducts) {
    return GridView.builder(
      itemCount: filteredProducts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.60,
      ),
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final productId = product['id'] as String;
        final imagePath = (product['image_path'] as String?) ?? '';
        final imageUrl = _publicImageUrl(imagePath);

        return BuyerProductGridCard(
          product: product,
          imageUrl: imageUrl,
          onTap: () => _openProductDetails(product),
          onAddToCart: _addingProductIds.contains(productId)
              ? () {}
              : () => _addToCart(product),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

    final filteredProducts = _filteredProducts();
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: BuyerProductSearchBar(
                controller: _searchController,
                onChanged: (_) {
                  setState(() {});
                },
                onMicTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voice search coming soon'),
                    ),
                  );
                },
                onClear: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            _buildFilterButton(),
          ],
        ),
        const SizedBox(height: 14),
        BuyerCategoryFilterBar(
          categories: _categoryOptions,
          selectedCategory: _selectedCategory,
          onSelected: (category) {
            setState(() {
              _selectedCategory = category;
              if (category == 'All') {
                _selectedSubcategory = null;
              } else {
                final subs = ProductTaxonomy.subcategoriesFor(category);
                if (!subs.contains(_selectedSubcategory)) {
                  _selectedSubcategory = null;
                }
              }
            });
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _products.isEmpty
              ? _buildEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No Products Available',
                  subtitle: 'Approved seller products will appear here.',
                )
              : filteredProducts.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No Matching Products',
                      subtitle: hasSearch || _activeFilterCount > 0
                          ? 'No product matched your current search or filters.'
                          : 'Try a different search.',
                    )
                  : _buildProductGrid(filteredProducts),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _body(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BuyerBottomNavBar(
        currentRoute: AppRoutes.buyerHome,
      ),
    );
  }
}