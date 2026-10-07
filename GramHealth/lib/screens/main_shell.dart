import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _tabs = const [
    '/main/home',
    '/main/doctors',
    '/main/symptoms',
    '/main/records',
    '/main/profile',
  ];

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_tabs[index]);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.instance.currentLanguage,
      builder: (context, lang, _) {
        final items = [
          (Icons.home_outlined, Icons.home_rounded, context.tr('tab_home')),
          (Icons.people_outline, Icons.people_rounded, context.tr('tab_doctors')),
          (Icons.search, Icons.search, context.tr('tab_symptoms')),
          (Icons.description_outlined, Icons.description_rounded, context.tr('tab_records')),
          (Icons.person_outline, Icons.person_rounded, context.tr('tab_profile')),
        ];

        return Scaffold(
          body: widget.child,
          extendBody: true,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.leafGreenPale.withValues(alpha: 0.9),
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            icon: items[i].$1,
                            activeIcon: items[i].$2,
                            label: items[i].$3,
                            selected: i == _currentIndex,
                            onTap: () => _onTap(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.leafGreenDeep : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryAccent.withValues(alpha: 0.10),
          highlightColor: AppColors.primaryAccent.withValues(alpha: 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: _duration,
                curve: Curves.easeOutCubic,
                width: selected ? 56 : 40,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? AppColors.leafGreenPale : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    key: ValueKey(selected),
                    size: 23,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: _duration,
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  letterSpacing: 0.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
