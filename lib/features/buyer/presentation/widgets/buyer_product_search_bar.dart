import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class BuyerProductSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onMicTap;
  final VoidCallback? onClear;

  const BuyerProductSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onMicTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search by product, category, subcategory, or tag',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (hasText)
            IconButton(
              onPressed: onClear,
              tooltip: 'Clear search',
              icon: const Icon(
                Icons.close,
                color: AppColors.textSecondary,
              ),
            ),
          IconButton(
            onPressed: onMicTap,
            tooltip: 'Voice search',
            icon: const Icon(
              Icons.mic_none_outlined,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}