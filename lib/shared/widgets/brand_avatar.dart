import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class BrandAvatar extends StatelessWidget {
  const BrandAvatar({super.key, this.radius = 17});

  final double radius;

  static const String assetPath = 'lib/assets/images/iconlembahwilis.jpg';

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.forest,
      backgroundImage: const AssetImage(assetPath),
    );
  }
}
