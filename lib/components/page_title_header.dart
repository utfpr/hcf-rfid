import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Header with page title and a short decorative line underneath.
/// Same style used across Home, Scan, History, Settings, About.
class PageTitleHeader extends StatelessWidget {
  const PageTitleHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
  });

  final String title;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBackButton)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Icon(
                Icons.chevron_left,
                color: AppColors.textHeading,
                size: 28,
              ),
            ),
          ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textHeading,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
