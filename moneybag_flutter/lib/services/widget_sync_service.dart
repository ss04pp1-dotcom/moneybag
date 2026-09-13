import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../data/database.dart' show Budget;
import '../state/app_state.dart';

/// v2.1 — Home screen widget (Android).
///
/// Pushes a tiny snapshot (today's spend + this month's spend, localized
/// labels) into the home_widget SharedPreferences so the native
/// [MbWidgetProvider] can render it. Every state mutation funnels through
/// [MbAppState._refresh], so the widget never goes stale.
///
/// All calls are wrapped in try/catch — the widget is a bonus surface and
/// must NEVER break the app (iOS has no widget extension configured, so
/// calls are Android-only and silently no-op elsewhere).
abstract final class MbWidgetSyncService {
  static const String _prefsTodayLabel = 'todayLabel';
  static const String _prefsTodayValue = 'todayValue';
  static const String _prefsMonthLabel = 'monthLabel';
  static const String _prefsMonthValue = 'monthValue';
  static const String _prefsBudgetHas = 'budgetHas';
  static const String _prefsBudgetLabel = 'budgetLabel';
  static const String _prefsBudgetValue = 'budgetValue';
  static const String _prefsBudgetPct = 'budgetPct';

  /// Writes the current snapshot. Safe to call from anywhere, any time.
  static Future<void> push(MbAppState state) async {
    if (!Platform.isAndroid) return;
    try {
      final now = DateTime.now();
      final loc = L.stringsFor(state.language);
      final all = state.txView;

      // Today's expenses (date-stored transactions carry 12:00, so a pure
      // day comparison is exact).
      var today = 0;
      for (final t in all) {
        if (t.isExpense &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day) {
          today += t.amountMinor;
        }
      }
      final month = MbCalc.totals(MbCalc.forMonth(all, now.year, now.month)).expense;

      // v2.2.1: overall monthly budget → progress bar on the widget.
      // Mirrors the budget screen's math (rollover-aware effective limit).
      Budget? overall;
      for (final b in state.budgets) {
        if (b.categoryId == null) {
          overall = b;
          break;
        }
      }
      if (overall != null) {
        final st = MbCalc.budgetStatus(all, now.year, now.month,
            limitMinor: overall.amountMinor, rollover: overall.rollover);
        await HomeWidget.saveWidgetData<bool>(_prefsBudgetHas, true);
        await HomeWidget.saveWidgetData<String>(
            _prefsBudgetLabel, loc.widgetBudget);
        await HomeWidget.saveWidgetData<String>(
            _prefsBudgetValue,
            '${MbFormat.money(st.spentMinor, bengaliDigits: state.bengaliDigits)}'
            ' / '
            '${MbFormat.money(st.effectiveLimit, bengaliDigits: state.bengaliDigits)}');
        await HomeWidget.saveWidgetData<int>(
            _prefsBudgetPct, st.usedPct.clamp(0, 100).round());
      } else {
        await HomeWidget.saveWidgetData<bool>(_prefsBudgetHas, false);
      }

      await HomeWidget.saveWidgetData<String>(
          _prefsTodayLabel, loc.widgetToday);
      await HomeWidget.saveWidgetData<String>(
          _prefsTodayValue,
          MbFormat.money(today, bengaliDigits: state.bengaliDigits));
      await HomeWidget.saveWidgetData<String>(
          _prefsMonthLabel, loc.widgetMonth);
      await HomeWidget.saveWidgetData<String>(
          _prefsMonthValue,
          MbFormat.money(month, bengaliDigits: state.bengaliDigits));

      await HomeWidget.updateWidget(androidName: 'MbWidgetProvider');
    } catch (_) {
      // The widget is decorative — never let it break a data write.
    }
  }
}
