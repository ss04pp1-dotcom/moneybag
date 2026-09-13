import 'calc.dart';
import 'l10n.dart';

/// Rule-based insights engine (TRD: Insights Engine).
///
/// Produces at most [max] prioritized insight cards from a month snapshot.
/// Pure function — fully unit-tested.

enum MbInsightTone { positive, neutral, warning, danger }

class MbInsight {
  final String icon;
  final String title;
  final String body;
  final MbInsightTone tone;

  const MbInsight({
    required this.icon,
    required this.title,
    required this.body,
    this.tone = MbInsightTone.neutral,
  });
}

/// Everything the engine needs about one month.
class MbInsightInput {
  final List<MbTx> monthTxs;
  final List<MbTx> prevMonthTxs;
  final List<MbTx> allTxs; // full history (for budget rollover etc.)
  final int year;
  final int month;
  final DateTime now;

  /// categoryName(categoryId) → display name (or fallback).
  final String Function(String categoryId) categoryName;

  /// Budget lines: (categoryId?, limitMinor, rollover).
  final List<MbBudgetLine> budgets;

  /// Monthly income declared in profile (poisha), used for savings rate when
  /// no income transactions exist. Null when unset.
  final int? declaredIncomeMinor;

  /// Localized money formatter (e.g. MbFormat.money with Bengali digits).
  /// When provided, insight bodies render amounts exactly like the rest of
  /// the app; otherwise a plain `৳2500` fallback is used.
  final String Function(int minor)? moneyOf;

  const MbInsightInput({
    required this.monthTxs,
    required this.prevMonthTxs,
    required this.allTxs,
    required this.year,
    required this.month,
    required this.now,
    required this.categoryName,
    this.budgets = const [],
    this.declaredIncomeMinor,
    this.moneyOf,
  });
}

class MbBudgetLine {
  final String? categoryId;
  final int limitMinor;
  final bool rollover;

  const MbBudgetLine({
    this.categoryId,
    required this.limitMinor,
    this.rollover = false,
  });
}

abstract final class MbInsights {
  static const int maxCards = 4;

  static List<MbInsight> generate(MbInsightInput input, MbStrings L,
      {int max = maxCards}) {
    final out = <MbInsight>[];
    final monthTxs = input.monthTxs;
    final t = MbCalc.totals(monthTxs);
    String money(int minor) =>
        input.moneyOf?.call(minor) ?? _moneyOf(minor);

    // Empty state → single greeting card.
    if (monthTxs.isEmpty) {
      return [
        MbInsight(
          icon: '👋',
          title: L.insGreetingT,
          body: L.insGreetingB,
          tone: MbInsightTone.positive,
        ),
      ];
    }

    // ── Rule: budget warnings (danger > warning, category > overall) ──
    final budgetCards = <MbInsight>[];
    final budgetWarn = <MbInsight>[];
    MbBudgetLine? overallLine;
    for (final b in input.budgets) {
      if (b.categoryId == null) overallLine = b;
      final st = MbCalc.budgetStatus(
        input.allTxs,
        input.year,
        input.month,
        categoryId: b.categoryId,
        limitMinor: b.limitMinor,
        rollover: b.rollover,
      );
      final name = b.categoryId == null
          ? ''
          : input.categoryName(b.categoryId!);
      if (st.state == MbBudgetState.over) {
        budgetCards.add(MbInsight(
          icon: '🚨',
          title: L.insBudgetOverT,
          body: name.isEmpty ? L.insBudgetOverB('') : L.insBudgetOverB(name),
          tone: MbInsightTone.danger,
        ));
      } else if (st.state == MbBudgetState.warning) {
        budgetWarn.add(MbInsight(
          icon: '⚠️',
          title: L.insBudgetWarnT,
          body: name.isEmpty ? L.insBudgetWarnB('') : L.insBudgetWarnB(name),
          tone: MbInsightTone.warning,
        ));
      }
    }
    out.addAll(budgetCards);
    out.addAll(budgetWarn);

    // ── v2.1 Rule: budget pace (projection vs overall budget) ──
    // Current month only: "at this rate the month would end at X".
    final isCurrentMonth =
        input.now.year == input.year && input.now.month == input.month;
    if (isCurrentMonth && overallLine != null && monthTxs.isNotEmpty) {
      final proj = MbCalc.projectedMonthEnd(
          monthTxs, input.year, input.month, input.now);
      final limit = overallLine.limitMinor +
          (overallLine.rollover
              ? MbCalc.rolloverFor(input.allTxs, input.year, input.month,
                  limitMinor: overallLine.limitMinor)
              : 0);
      if (limit > 0 && proj > 0) {
        if (proj > limit) {
          out.add(MbInsight(
            icon: '⏱️',
            title: L.insBurnRateOverT,
            body: L.insBurnRateOverB(money(proj), money(limit)),
            tone: MbInsightTone.danger,
          ));
        } else {
          out.add(MbInsight(
            icon: '🧭',
            title: L.insBurnRateT,
            body: L.insBurnRateB(money(proj), money(limit)),
            tone: MbInsightTone.neutral,
          ));
        }
      }
    }

    // ── v2.1 Rule: weekend (Fri–Sat) spending pattern ──
    if (isCurrentMonth) {
      final wk = MbCalc.weekendDeltaPct(
          monthTxs, input.year, input.month, input.now);
      if (wk.isFinite && wk >= 25) {
        out.add(MbInsight(
          icon: '🗓️',
          title: L.insWeekendT,
          body: L.insWeekendB(wk),
          tone: MbInsightTone.warning,
        ));
      }
    }

    // ── v2.2.2 Rule: category spike vs its own trailing 3-month average ──
    // Catches "খাবার-এ এই মাসে গত ৩ মাসের গড়ের চেয়ে ৭০% বেশি" — a single
    // category quietly ballooning even when the overall MoM delta looks fine.
    if (isCurrentMonth) {
      final spike =
          MbCalc.topCategorySpike(input.allTxs, input.year, input.month);
      if (spike != null) {
        out.add(MbInsight(
          icon: '⚡',
          title: L.insSpikeT,
          body: L.insSpikeB(input.categoryName(spike.$1), spike.$2),
          tone: MbInsightTone.warning,
        ));
      }
    }

    // ── Rule: top spending category ──
    final shares = MbCalc.expenseShares(monthTxs);
    if (shares.isNotEmpty) {
      final name = input.categoryName(shares.first.key);
      out.add(MbInsight(
        icon: '📊',
        title: L.insTopCategoryT,
        body: L.insTopCategoryB(
          name,
          money(
              MbCalc.byCategory(monthTxs)[shares.first.key]?.expenseMinor ?? 0),
        ),
        tone: MbInsightTone.neutral,
      ));
    }

    // ── Rule: month-over-month ──
    final mom = MbCalc.momDeltaPct(input.allTxs, input.year, input.month);
    final prevExpense = MbCalc.totals(input.prevMonthTxs).expense;
    if (prevExpense > 0 && mom.isFinite) {
      if (mom > 0) {
        out.add(MbInsight(
          icon: '📈',
          title: L.insMoMUpT,
          body: L.insMoMB(mom),
          tone: MbInsightTone.warning,
        ));
      } else if (mom < 0) {
        out.add(MbInsight(
          icon: '📉',
          title: L.insMoMDownT,
          body: L.insMoMDownB(mom.abs()),
          tone: MbInsightTone.positive,
        ));
      }
    }

    // ── Rule: savings rate ──
    final effIncome = t.income > 0
        ? t.income
        : (input.declaredIncomeMinor ?? 0);
    if (effIncome > 0) {
      final rate = (t.net / effIncome) * 100;
      if (rate.isFinite) {
        out.add(MbInsight(
          icon: rate >= 20 ? '🎉' : '🐖',
          title: L.insSavingsRateT,
          body: L.insSavingsRateB(rate),
          tone: rate >= 20 ? MbInsightTone.positive : MbInsightTone.neutral,
        ));
      }
    }

    // ── Rule: daily average & projection ──
    final avg = MbCalc.dailyAverage(monthTxs, input.year, input.month, input.now);
    if (avg > 0) {
      out.add(MbInsight(
        icon: '☀️',
        title: L.insDailyAvgT,
        body: L.insDailyAvgB(money(avg)),
        tone: MbInsightTone.neutral,
      ));
      final isCurrentMonth =
          input.now.year == input.year && input.now.month == input.month;
      if (isCurrentMonth) {
        final proj = MbCalc.projectedMonthEnd(
            monthTxs, input.year, input.month, input.now);
        out.add(MbInsight(
          icon: '🔮',
          title: L.insProjectedT,
          body: L.insProjectedB(money(proj)),
          tone: MbInsightTone.neutral,
        ));
      }
    }

    // ── Rule: biggest transaction ──
    final big = MbCalc.biggestExpense(monthTxs);
    if (big != null && monthTxs.length > 2) {
      final cat = big.categoryId == null ? '' : input.categoryName(big.categoryId!);
      out.add(MbInsight(
        icon: '🌊',
        title: L.insBiggestT,
        body: L.insBiggestB(money(big.amountMinor), cat),
        tone: MbInsightTone.neutral,
      ));
    }

    // ── Rule: no-spend days (only for the current month) ──
    if (isCurrentMonth) {
      final ns = MbCalc.noSpendDays(monthTxs, input.year, input.month, input.now);
      if (ns >= 2) {
        out.add(MbInsight(
          icon: '🛡️',
          title: L.insNoSpendT,
          body: L.insNoSpendB(ns),
          tone: MbInsightTone.positive,
        ));
      }
    }

    return out.take(max).toList(growable: false);
  }

  /// Fallback money formatter — used when no localized formatter is supplied
  /// via [MbInsightInput.moneyOf]. Views normally pass MbFormat.money so
  /// insight bodies match the app-wide formatting (Bengali digits, grouping).
  static String _moneyOf(int minor) {
    final taka = minor ~/ 100;
    return '৳$taka';
  }
}
