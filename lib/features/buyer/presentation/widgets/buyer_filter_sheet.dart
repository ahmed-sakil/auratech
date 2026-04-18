import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/product_taxonomy.dart';

class BuyerFilterSheet extends StatefulWidget {
  final String selectedCategory;
  final String? selectedSubcategory;
  final String minPrice;
  final String maxPrice;

  const BuyerFilterSheet({
    super.key,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.minPrice,
    required this.maxPrice,
  });

  @override
  State<BuyerFilterSheet> createState() => _BuyerFilterSheetState();
}

class _BuyerFilterSheetState extends State<BuyerFilterSheet> {
  late String _selectedCategory;
  String? _selectedSubcategory;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedSubcategory = widget.selectedSubcategory;
    _minPriceController = TextEditingController(text: widget.minPrice);
    _maxPriceController = TextEditingController(text: widget.maxPrice);
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  List<String> get _subcategories {
    if (_selectedCategory == 'All') return [];
    return ProductTaxonomy.subcategoriesFor(_selectedCategory);
  }

  void _apply() {
    Navigator.of(context).pop({
      'category': _selectedCategory,
      'subcategory': _selectedSubcategory,
      'minPrice': _minPriceController.text.trim(),
      'maxPrice': _maxPriceController.text.trim(),
    });
  }

  void _reset() {
    setState(() {
      _selectedCategory = 'All';
      _selectedSubcategory = null;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...ProductTaxonomy.categoryList];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedCategory = value;
                    if (_selectedCategory == 'All') {
                      _selectedSubcategory = null;
                    } else {
                      final nextSubs =
                          ProductTaxonomy.subcategoriesFor(_selectedCategory);
                      if (!nextSubs.contains(_selectedSubcategory)) {
                        _selectedSubcategory = null;
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _selectedSubcategory,
                decoration: const InputDecoration(
                  labelText: 'Subcategory',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ..._subcategories.map((subcategory) {
                    return DropdownMenuItem<String?>(
                      value: subcategory,
                      child: Text(subcategory),
                    );
                  }),
                ],
                onChanged: _selectedCategory == 'All'
                    ? null
                    : (value) {
                        setState(() {
                          _selectedSubcategory = value;
                        });
                      },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min price',
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Max price',
                        hintText: '10000',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}