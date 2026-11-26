import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final String userName;
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

  Widget _buildDesktopSidebar() {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _sidebarExpanded ? 248 : 80,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Row(
              mainAxisAlignment: _sidebarExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const Icon(Icons.terrain_rounded, color: AppColors.forest),
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
                                  ? colorScheme.primary
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
                                        ? colorScheme.primary
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
          if (_sidebarExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
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

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            leading: isDesktop
                ? IconButton(
                    tooltip: _sidebarExpanded
                        ? 'Ciutkan navigasi'
                        : 'Perluas navigasi',
                    onPressed: () {
                      setState(() {
                        _sidebarExpanded = !_sidebarExpanded;
                      });
                    },
                    icon: Icon(
                      _sidebarExpanded
                          ? Icons.menu_open_rounded
                          : Icons.menu_rounded,
                    ),
                  )
                : null,
            actions: [
              if (!isMobile)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 120 : 220,
                      ),
                      child: Text(
                        widget.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ...widget.actions,
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (isTablet)
                NavigationRail(
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: widget.onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: _railDestinations,
                ),
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
              ? NavigationBar(
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: widget.onDestinationSelected,
                  destinations: _bottomDestinations,
                )
              : null,
          floatingActionButton: widget.floatingActionButton,
        );
      },
    );
  }
}
