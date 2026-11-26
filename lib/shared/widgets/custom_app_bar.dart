import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import 'brand_avatar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    required this.userName,
    required this.roleLabel,
    required this.dateTime,
    required this.actions,
    this.leading,
  });

  final String title;
  final String userName;
  final String roleLabel;
  final DateTime dateTime;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final datePattern = compact
        ? 'd MMM yyyy • HH:mm'
        : 'EEEE, d MMMM yyyy • HH:mm';
    final dateLabel = DateFormat(datePattern, 'id_ID').format(dateTime);
    return AppBar(
      toolbarHeight: preferredSize.height,
      leading: leading,
      titleSpacing: leading == null ? 16 : 0,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 13,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (compact)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: userName,
              child: const BrandAvatar(radius: 16),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Row(
                children: [
                  const BrandAvatar(radius: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roleLabel.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.forestDark,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        ...actions,
        const SizedBox(width: 8),
      ],
    );
  }
}
