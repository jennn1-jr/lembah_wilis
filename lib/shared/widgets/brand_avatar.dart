import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class BrandAvatar extends StatelessWidget {
  const BrandAvatar({super.key, this.radius = 17});

  final double radius;

  static const String assetPath = 'lib/assets/images/iconlembahwilis_round.png';

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    return ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: AppColors.forest,
          alignment: Alignment.center,
          child: Icon(
            Icons.forest_rounded,
            color: AppColors.white,
            size: radius,
          ),
        ),
      ),
    );
  }
}
