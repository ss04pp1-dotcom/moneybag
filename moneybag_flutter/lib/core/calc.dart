/// MoneyBag centralized calculation engine.
///
/// The SINGLE SOURCE OF TRUTH for every financial computation in the app
/// (per TRD: Calculation Engine). Screens, widgets, insights and exports all
/// call these pure functions — no view re-implements money math.
///
/// Amounts are integers in poisha (1/100 ৳) everywhere.
library;

/// Plain money-typed transaction used by the engine. Drift rows are mapped
/// into this shape before computation so the engine is DB-free and testable.
class MbTx {
  final String id;
  final String kind; // 'expense' | 'income'
  final int amountMinor;
  final String? categoryId;
  final String? note;
  final DateTime date;

  const MbTx({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.date,
    this.categoryId,
    this.note,
  });

  bool get isExpense => kind == 'expense';
  bool get isIncome => kind == 'income';
}

/// Per-category aggregate.
class MbCategoryTotal {
  final String categoryId;
  final int expenseMinor;
  final int incomeMinor;

  const MbCategoryTotal({
    required this.categoryId,
    this.expenseMinor = 0,
    this.incomeMinor = 0,
  });
}

/// Totals snapshot.
class MbTotals {
  final int income;
  final int expense;
  final int net; // income − expense (savings when positive)

  const MbTotals({
    required this.income,
    required this.expense,
  }) : net = income - expense;

  double get savingsRate =>
      income > 0 ? (net / income) * 100 : (expense == 0 ? 0 : double.nan);
}

/// Budget status states.
enum MbBudgetState { none, safe, warning, over }

/// Budget status for a single budget line.
class MbBudgetStatus {
  final int limitMinor;
  final int spentMinor;
  final int rolloverMinor; // unused portion of previous month (adds to limit)

  const MbBudgetStatus({
    required this.limitMinor,
    required this.spentMinor,
    this.rolloverMinor = 0,
  });

  int get effectiveLimit => limitMinor + rolloverMinor;

  int get remainingMinor => effectiveLimit - spentMinor;

  bool get isOver => spentMinor > effectiveLimit;

  double get usedPct =>
      effectiveLimit > 0 ? (spentMinor / effectiveLimit) * 100 : 0;

  MbBudgetState get state {
    if (limitMinor <= 0) return MbBudgetState.none;
    if (isOver) return MbBudgetState.over;
    if (usedPct >= 85) return MbBudgetState.warning;
    return MbBudgetState.safe;
  }
}

/// Bar for chart series.
class MbBar {
  final DateTime start;
  final int expenseMinor;
  final int incomeMinor;
  const MbBar({
    required this.start,
    this.expenseMinor = 0,
    this.incomeMinor = 0,
  });
}

abstract final class MbCalc {
  // ── filters ──────────────────────────────────────────────────────────────
  static bool inMonth(DateTime d, int year, int month) =>
      d.year == year && d.month == month;

  static List<MbTx> forMonth(List<MbTx> txs, int year, int month) => txs
      .where((t) => inMonth(t.date, year, month))
      .toList(growable: false);

  static List<MbTx> between(List<MbTx> txs, DateTime from, DateTime to) => txs
      .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
      .toList(growable: false);

  static List<MbTx> forYear(List<MbTx> txs, int year) =>
      txs.where((t) => t.date.year == year).toList(growable: false);

  // ── totals ───────────────────────────────────────────────────────────────
  static MbTotals totals(List<MbTx> txs) {
    var income = 0, expense = 0;
    for (final t in txs) {
      if (t.isIncome) {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
      }
    }
    return MbTotals(income: income, expense: expense);
  }

  // ── category breakdown ───────────────────────────────────────────────────
  static Map<String, MbCategoryTotal> byCategory(List<MbTx> txs) {
    final out = <String, MbCategoryTotal>{};
    for (final t in txs) {
      if (t.categoryId == null) continue;
      final prev = out[t.categoryId!] ??
          MbCategoryTotal(categoryId: t.categoryId!);
      out[t.categoryId!] = MbCategoryTotal(
        categoryId: t.categoryId!,
        expenseMinor: prev.expenseMinor + (t.isExpense ? t.amountMinor : 0),
        incomeMinor: prev.incomeMinor + (t.isIncome ? t.amountMinor : 0),
      );
    }
    return out;
  }

  /// Category shares (of expense), sorted desc, as 0..1 fractions.
  static List<MapEntry<String, double>> expenseShares(List<MbTx> txs) {
    final byCat = byCategory(txs);
    var total = 0;
    final entries = <MapEntry<String, int>>[];
    for (final e in byCat.entries) {
      total += e.value.expenseMinor;
      entries.add(MapEntry(e.key, e.value.expenseMinor));
    }
    if (total == 0) return const [];
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => MapEntry(e.key, e.value / total))
        .toList(growable: false);
  }

  // ── budget ───────────────────────────────────────────────────────────────
  /// Spending of [month] in one category (or all expenses when [categoryId]
  /// is null). Expenses only — budgets cap spending, not income.
  static int spentFor(
    List<MbTx> txs,
    int year,
    int month, {
    String? categoryId,
  }) {
    var sum = 0;
    for (final t in txs) {
      if (!t.isExpense) continue;
      if (!inMonth(t.date, year, month)) continue;
      if (categoryId != null && t.categoryId != categoryId) continue;
      sum += t.amountMinor;
    }
    return sum;
  }

  /// Unused amount of the PREVIOUS month for rollover budgets
  /// (max 0 when overspent).
  static int rolloverFor(
    List<MbTx> txs,
    int year,
    int month, {
    String? categoryId,
    required int limitMinor,
  }) {
    if (limitMinor <= 0) return 0;
    final (py, pm) = previousMonth(year, month);
    final spent = spentFor(txs, py, pm, categoryId: categoryId);
    final left = limitMinor - spent;
    return left > 0 ? left : 0;
  }

  static (int, int) previousMonth(int year, int month) =>
      month == 1 ? (year - 1, 12) : (year, month - 1);

  static (int, int) nextMonth(int year, int month) =>
      month == 12 ? (year + 1, 1) : (year, month + 1);

  static MbBudgetStatus budgetStatus(
    List<MbTx> txs,
    int year,
    int month, {
    String? categoryId,
    required int limitMinor,
    bool rollover = false,
  }) {
    final spent = spentFor(txs, year, month, categoryId: categoryId);
    final carry = rollover
        ? rolloverFor(txs, year, month, categoryId: categoryId, limitMinor: limitMinor)
        : 0;
    return MbBudgetStatus(
      limitMinor: limitMinor,
      spentMinor: spent,
      rolloverMinor: carry,
    );
  }

  // ── goals ────────────────────────────────────────────────────────────────
  static int goalSaved(List<int> contributionMinors) {
    var sum = 0;
    for (final c in contributionMinors) {
      sum += c;
    }
    return sum;
  }

  /// 0..1 progress (clamped).
  static double goalProgress(int targetMinor, int savedMinor) {
    if (targetMinor <= 0) return 0;
    final p = savedMinor / targetMinor;
    if (p.isNaN) return 0;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  // ── month-over-month ─────────────────────────────────────────────────────
  /// % change of expense vs previous month. NaN when previous is 0 and
  /// current > 0 (no baseline); 0 when both are 0.
  static double momDeltaPct(List<MbTx> txs, int year, int month) {
    final cur = totals(forMonth(txs, year, month)).expense;
    final (py, pm) = previousMonth(year, month);
    final prev = totals(forMonth(txs, py, pm)).expense;
    if (prev == 0) return cur == 0 ? 0 : double.nan;
    return ((cur - prev) / prev) * 100;
  }

  // ── daily metrics ────────────────────────────────────────────────────────
  static int daysInMonth(int year, int month) {
    final firstOfNext = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return firstOfNext.subtract(const Duration(days: 1)).day;
  }

  /// Days elapsed in [month] (counting today when it is the current month).
  static int daysElapsed(int year, int month, DateTime now) {
    if (now.year != year || now.month != month) {
      return daysInMonth(year, month);
    }
    return now.day;
  }

  static int dailyAverage(List<MbTx> monthTxs, int year, int month, DateTime now) {
    final expense = totals(monthTxs).expense;
    final elapsed = daysElapsed(year, month, now);
    if (elapsed <= 0) return 0;
    return expense ~/ elapsed;
  }

  static int projectedMonthEnd(
      List<MbTx> monthTxs, int year, int month, DateTime now) {
    final avg = dailyAverage(monthTxs, year, month, now);
    return avg * daysInMonth(year, month);
  }

  /// Days without any expense in the month so far.
  static int noSpendDays(List<MbTx> monthTxs, int year, int month, DateTime now) {
    final spendDays = <int>{};
    for (final t in monthTxs) {
      if (t.isExpense) spendDays.add(t.date.day);
    }
    final elapsed = daysElapsed(year, month, now);
    var count = 0;
    for (var d = 1; d <= elapsed; d++) {
      if (!spendDays.contains(d)) count++;
    }
    return count;
  }

  // ── series for charts ────────────────────────────────────────────────────
  /// Weekly bars (Mon..Sun style weeks starting at monthStart offset).
  /// v2.2.0: the bar loop used to run up to `DateTime.now()` — for the
  /// "last month" analytics scope that emitted ~4–5 trailing zero-weeks
  /// (first tx → today). It now stops at the END of the tx's month (or
  /// today, whichever comes first), so a full month renders exactly.
  static List<MbBar> weeklyBars(List<MbTx> monthTxs) {
    if (monthTxs.isEmpty) return const [];
    final first = monthTxs
        .reduce((a, b) => a.date.isBefore(b.date) ? a : b)
        .date;
    var anchor = DateTime(first.year, first.month, first.day);
    // Align to Monday.
    final dow = (anchor.weekday - 1) % 7;
    anchor = anchor.subtract(Duration(days: dow));
    // Day 0 of the next month = last day of this month.
    final monthEnd = DateTime(first.year, first.month + 1, 0);
    final now = DateTime.now();
    final last = now.isBefore(monthEnd) ? now : monthEnd;
    final bars = <MbBar>[];
    var cursor = anchor;
    while (cursor.isBefore(last.add(const Duration(days: 1)))) {
      final end = cursor.add(const Duration(days: 7));
      final inWeek = monthTxs
          .where((t) =>
              !t.date.isBefore(cursor) &&
              t.date.isBefore(end))
          .toList(growable: false);
      bars.add(MbBar(
        start: cursor,
        expenseMinor: totals(inWeek).expense,
        incomeMinor: totals(inWeek).income,
      ));
      cursor = end;
    }
    return bars;
  }

  /// Monthly bars for the last [n] months ending at (year, month).
  static List<MbBar> monthlyBars(List<MbTx> txs, int year, int month, int n) {
    final bars = <MbBar>[];
    var (y, m) = (year, month);
    for (var i = 0; i < n; i++) {
      final monthTxs = forMonth(txs, y, m);
      final t = totals(monthTxs);
      bars.insert(
          0, MbBar(start: DateTime(y, m, 1), expenseMinor: t.expense, incomeMinor: t.income));
      final (py, pm) = previousMonth(y, m);
      y = py;
      m = pm;
    }
    return bars;
  }

  /// Day-of-week spend pattern 0=Monday..6=Sunday (for habit view).
  static List<int> weekdaySpend(List<MbTx> txs) {
    final out = List<int>.filled(7, 0);
    for (final t in txs) {
      if (t.isExpense) out[(t.date.weekday - 1) % 7] += t.amountMinor;
    }
    return out;
  }

  /// Largest expense transaction in a list (null when none).
  static MbTx? biggestExpense(List<MbTx> txs) {
    MbTx? best;
    for (final t in txs) {
      if (t.isExpense && (best == null || t.amountMinor > best.amountMinor)) {
        best = t;
      }
    }
    return best;
  }

  // ── v2.1 smart analytics ─────────────────────────────────────────────────
  /// Average monthly spend over the last [n] COMPLETE months (before
  /// [now]) in one category (all expenses when [categoryId] is null).
  /// Used for the "suggested budget" hint — poisha, rounded.
  static int trailingMonthlyAvg(
    List<MbTx> txs,
    DateTime now, {
    String? categoryId,
    int n = 3,
  }) {
    if (n <= 0) return 0;
    var sum = 0;
    var (y, m) = (now.year, now.month);
    for (var i = 0; i < n; i++) {
      final (py, pm) = previousMonth(y, m);
      y = py;
      m = pm;
      sum += spentFor(txs, y, m, categoryId: categoryId);
    }
    return (sum / n).round();
  }

  /// v2.2.2: the single biggest category SPIKE — current-month spend versus
  /// that category's own trailing [n]-month average. Returns
  /// (categoryId, pct-above-average) when some category is at least
  /// [minSpikePct] percent above a baseline of at least [minBaselineMinor]
  /// (poisha); null otherwise. The baseline floor keeps brand-new or tiny
  /// categories from producing noisy "∞% up" cards.
  static (String, double)? topCategorySpike(
    List<MbTx> txs,
    int year,
    int month, {
    double minSpikePct = 50,
    int minBaselineMinor = 5000,
    int n = 3,
  }) {
    if (n <= 0) return null;
    final current = byCategory(forMonth(txs, year, month));
    String? bestCat;
    var bestPct = 0.0;
    for (final e in current.entries) {
      final cur = e.value.expenseMinor;
      if (cur <= 0) continue;
      var (y, m) = (year, month);
      var sum = 0;
      for (var i = 0; i < n; i++) {
        final (py, pm) = previousMonth(y, m);
        y = py;
        m = pm;
        sum += spentFor(txs, y, m, categoryId: e.key);
      }
      final avg = sum / n;
      if (avg < minBaselineMinor) continue;
      final pct = ((cur - avg) / avg) * 100;
      if (pct > bestPct) {
        bestPct = pct;
        bestCat = e.key;
      }
    }
    if (bestCat == null || bestPct < minSpikePct) return null;
    return (bestCat, bestPct);
  }

  /// Weekend (Bangladesh: Fri + Sat) vs weekday average DAILY spend in a
  /// month, as a % delta. Positive → weekend days are costlier.
  /// NaN when there is no weekday baseline or no days elapsed.
  static double weekendDeltaPct(
      List<MbTx> monthTxs, int year, int month, DateTime now) {
    final elapsed = daysElapsed(year, month, now);
    var weekendDays = 0, weekdayDays = 0;
    for (var d = 1; d <= elapsed; d++) {
      final wd = DateTime(year, month, d).weekday;
      final isWeekend = wd == DateTime.friday || wd == DateTime.saturday;
      if (isWeekend) {
        weekendDays++;
      } else {
        weekdayDays++;
      }
    }
    if (weekendDays == 0 || weekdayDays == 0) return double.nan;
    var weekendTotal = 0, weekdayTotal = 0;
    for (final t in monthTxs) {
      if (!t.isExpense) continue;
      final isWeekend =
          t.date.weekday == DateTime.friday || t.date.weekday == DateTime.saturday;
      if (isWeekend) {
        weekendTotal += t.amountMinor;
      } else {
        weekdayTotal += t.amountMinor;
      }
    }
    final weekdayAvg = weekdayTotal / weekdayDays;
    if (weekdayAvg == 0) return double.nan;
    final weekendAvg = weekendTotal / weekendDays;
    return ((weekendAvg - weekdayAvg) / weekdayAvg) * 100;
  }

  /// Months until a goal is reached at [monthlyRateMinor] per month.
  /// Null when the rate is not positive or the goal is already done.
  static double? monthsToGoal({
    required int targetMinor,
    required int savedMinor,
    required double monthlyRateMinor,
  }) {
    if (monthlyRateMinor <= 0 || savedMinor >= targetMinor) return null;
    return (targetMinor - savedMinor) / monthlyRateMinor;
  }
}
