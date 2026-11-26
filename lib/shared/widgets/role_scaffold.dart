import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'custom_app_bar.dart';

@immutable
class RoleNavigationDestination {
  const RoleNavigationDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

class RoleScaffold extends StatefulWidget {
  const RoleScaffold({
    super.key,
    required this.title,
    required this.userName,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.roleLabel = 'PETUGAS',
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final String userName;
  final String roleLabel;
  final List<RoleNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  State<RoleScaffold> createState() => _RoleScaffoldState();
}

class _RoleScaffoldState extends State<RoleScaffold> {
  bool _sidebarExpanded = true;
  DateTime _now = DateTime.now();
  late final Timer _clock;

  List<NavigationDestination> get _bottomDestinations => [
    for (final destination in widget.destinations)
      NavigationDestination(
        icon: Icon(destination.icon),
        selectedIcon: Icon(destination.selectedIcon ?? destination.icon),
        label: destination.label,
      ),
  ];

  List<NavigationRailDestination> get _railDestinations => [
    for (final destination in widget.destinations)
      NavigationRailDestination(
        icon: Icon(destination.icon),
        selectedIcon: Icon(destination.selectedIcon ?? destination.icon),
        label: Text(destination.label),
      ),
  ];

  String get _initial => widget.userName.trim().isEmpty
      ? '?'
      : widget.userName.trim().substring(0, 1).toUpperCase();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Widget _buildBrandMark() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'lib/assets/images/lembahwilis.jpg',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 40,
          height: 40,
          color: AppColors.forest,
          child: const Icon(Icons.forest_rounded, color: AppColors.white),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _sidebarExpanded ? 250 : 82,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 16),
            child: Row(
              mainAxisAlignment: _sidebarExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                _buildBrandMark(),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'LEMBAH WILIS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: widget.destinations.length,
              itemBuilder: (context, index) {
                final destination = widget.destinations[index];
                final selected = widget.selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Tooltip(
                    message: _sidebarExpanded ? '' : destination.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onDestinationSelected(index),
                      child: Container(
                        height: 48,
                        padding: EdgeInsets.symmetric(
                          horizontal: _sidebarExpanded ? 14 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.sage.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? const Border(
                                  left: BorderSide(
                                    color: AppColors.forest,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: _sidebarExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected
                                  ? destination.selectedIcon ?? destination.icon
                                  : destination.icon,
                              color: selected
                                  ? AppColors.forest
                                  : AppColors.muted,
                            ),
                            if (_sidebarExpanded) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  destination.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.forest
                                        : AppColors.ink,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _sidebarExpanded
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.sage.withValues(alpha: 0.18),
                        child: Text(
                          _initial,
                          style: const TextStyle(
                            color: AppColors.forest,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.roleLabel.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Tooltip(
                    message: '${widget.userName} • ${widget.roleLabel}',
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.sage.withValues(alpha: 0.18),
                      child: Text(
                        _initial,
                        style: const TextStyle(
                          color: AppColors.forest,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Expanded(
            child: NavigationRail(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: _railDestinations,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Tooltip(
              message: '${widget.userName} • ${widget.roleLabel}',
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.sage.withValues(alpha: 0.18),
                child: Text(
                  _initial,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;
        final isTablet =
            constraints.maxWidth >= 640 && constraints.maxWidth < 1100;
        final isDesktop = constraints.maxWidth >= 1100;
        final leading = isDesktop
            ? IconButton(
                tooltip: _sidebarExpanded
                    ? 'Ciutkan navigasi'
                    : 'Perluas navigasi',
                onPressed: () {
                  setState(() => _sidebarExpanded = !_sidebarExpanded);
                },
                icon: Icon(
                  _sidebarExpanded
                      ? Icons.menu_open_rounded
                      : Icons.menu_rounded,
                ),
              )
            : null;

        return Scaffold(
          appBar: CustomAppBar(
            title: widget.title,
            userName: widget.userName,
            roleLabel: widget.roleLabel,
            dateTime: _now,
            actions: widget.actions,
            leading: leading,
          ),
          body: Row(
            children: [
              if (isTablet) _buildNavigationRail(),
              if (isDesktop) _buildDesktopSidebar(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: widget.body,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isMobile
              ? Container(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: NavigationBar(
                    selectedIndex: widget.selectedIndex,
                    onDestinationSelected: widget.onDestinationSelected,
                    destinations: _bottomDestinations,
                  ),
                )
              : null,
          floatingActionButton: widget.floatingActionButton,
        );
      },
    );
  }
}
