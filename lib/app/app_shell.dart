import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = path == '/profile' ? 2 : path.startsWith('/quiz') ? 1 : 0;
    void navigateTo(int index) {
      if (index == 0) context.go('/');
      if (index == 1) context.go('/quiz');
      if (index == 2) context.go('/profile');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final destinations = const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Quiz',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ];

        return Scaffold(
          body: SafeArea(
            child: isMobile
                ? child
                : Row(
                    children: [
                      NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: navigateTo,
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text('Accueil'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.bolt_outlined),
                            selectedIcon: Icon(Icons.bolt),
                            label: Text('Quiz'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person),
                            label: Text('Profil'),
                          ),
                        ],
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                      Expanded(child: child),
                    ],
                  ),
          ),
          bottomNavigationBar: isMobile
              ? NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: navigateTo,
                  destinations: destinations,
                )
              : null,
        );
      },
    );
  }
}
