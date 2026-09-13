import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/whats_new.dart';
import '../services/ads_service.dart';
import '../services/remote_config_service.dart';
import '../core/l10n.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'savings_screen.dart';
import 'transaction_edit_screen.dart';
import 'transactions_screen.dart';

/// App shell — 5-slot bottom navigation with the center + FAB
/// (Home | Transactions | + | Budget | Profile), per the UI/UX spec.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  // Index of the active nav SLOT (0..4). The pages list below mirrors the
  // 5-slot layout 1:1 — the center slot (2) is the FAB placeholder and is
  // never selectable, but keeping it here makes slot→page mapping direct
  // and impossible to desynchronize (which previously caused a RangeError
  // blank screen on the Profile tab).
  int _index = 0;

  static const _pages = <Widget>[
    DashboardScreen(key: ValueKey('dashboard')),
    TransactionsScreen(key: ValueKey('transactions')),
    SizedBox.shrink(key: ValueKey('fab-slot')),
    BudgetScreen(key: ValueKey('budget')),
    ProfileScreen(key: ValueKey('profile')),
  ];

  // Analytics & Savings are reached from Dashboard shortcuts and kept alive
  // as pushed routes; bottom nav sticks to the 5 spec'd slots.

  @override
  void initState() {
    super.initState();
    // v2.1.1: greet existing users with the "What's New" guide exactly once
    // per version — AFTER the shell has rendered so the dialog can never be
    // swallowed by the splash→shell AnimatedSwitcher transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<MbAppState>();
      if (state.onboarded && state.introDone) {
        showWhatsNewIfNeeded(context, state);
      }
      
      _checkMaintenancePopup();
    });
  }

  void _checkMaintenancePopup() {
    final ads = context.read<MbAdsService>();
    if (ads.adsEnabled && !ads.adFreeActive) {
      _showMaintenancePopup();
    }
  }

  void _showMaintenancePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final L = ctx.L;
        final ads = ctx.read<MbAdsService>();
        return AlertDialog(
          title: Text(L.maintenancePopupTitle),
          content: Text(L.maintenancePopupBody),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // If they refuse, you can decide what to do. Usually, they can just use the app, 
                // but if maintenance mode requires ads, we could force it or just close popup.
              },
              child: Text(L.cancel), // we can use 'Dismiss' or L.cancel (if exists)
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final earned = await ads.showRewarded();
                if (mounted && !earned) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(L.rewardedFailed)),
                  );
                }
              },
              child: Text(L.rewardedWatch),
            ),
          ],
        );
      }
    );
  }

  void _openAdd() {
    MbNav.push(context, const TransactionEditScreen(), fullscreenDialog: true);
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _pages[_index],
      ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(
          scale: 0.55 + 0.45 * v,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
        child: MbPressable(
          pressedScale: 0.92,
          onTap: _openAdd,
          child: Container(
            key: const ValueKey('mb-fab'),
            width: 62,
            height: 62,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MbPalette.green, MbPalette.greenDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: MbPalette.green.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Material(
              color: Colors.transparent,
              child: Icon(Icons.add_rounded, color: Color(0xFF06130C), size: 32),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _MbNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        onAdd: _openAdd,
        items: [
          _MbNavItem(icon: Icons.home_rounded, label: L.navHome),
          _MbNavItem(
              icon: Icons.receipt_long_rounded, label: L.navTransactions),
          const _MbNavItem(icon: null, label: ''),
          _MbNavItem(icon: Icons.savings_rounded, label: L.navBudget),
          _MbNavItem(icon: Icons.person_rounded, label: L.navProfile),
        ],
      ),
    );
  }
}

/// Navigates to Analytics (reachable from dashboard insights card).
void openAnalytics(BuildContext context) {
  MbNav.push(context, const AnalyticsScreen());
}

/// Navigates to Savings/Goals.
void openSavings(BuildContext context) {
  MbNav.push(context, const SavingsScreen());
}

class _MbNavItem {
  final IconData? icon;
  final String label;
  const _MbNavItem({required this.icon, required this.label});
}

class _MbNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onAdd;
  final List<_MbNavItem> items;

  const _MbNavBar({
    required this.index,
    required this.onChanged,
    required this.onAdd,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68 + bottom,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: items[i].icon == null
                      ? const SizedBox.shrink()
                      : _navItem(context, items[i], i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, _MbNavItem item, int i) {
    final scheme = Theme.of(context).colorScheme;
    final selected = i == index;
    final color = selected ? MbPalette.green : scheme.onSurfaceVariant;
    return InkWell(
      onTap: () => onChanged(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon sits on a soft highlight pill that fades/scales in when
          // selected (restored 1.3.x detail); the icon itself springs up.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: selected ? 0.7 : 1, end: selected ? 1.12 : 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => Transform.scale(
              scale: v,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // highlight pill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? MbPalette.green.withOpacity(0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(
                    height: 26,
                    child: Icon(item.icon, color: color, size: 26),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          // FittedBox keeps the label inside the nav slot at any text scale.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
