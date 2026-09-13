import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/insights.dart';
import '../core/palette.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

enum _AnPeriod { thisMonth, lastMonth, thisYear }

/// Analytics — spending by category, weekly bars, 6-month trend,
/// income vs expense and the full insights stack.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _AnPeriod _period = _AnPeriod.thisMonth;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final all = state.txView;

    late List<MbTx> txs;
    late int year;
    late int month;
    switch (_period) {
      case _AnPeriod.thisMonth:
        year = now.year;
        month = now.month;
        txs = MbCalc.forMonth(all, year, month);
        break;
      case _AnPeriod.lastMonth:
        final (py, pm) = MbCalc.previousMonth(now.year, now.month);
        year = py;
        month = pm;
        txs = MbCalc.forMonth(all, py, pm);
        break;
      case _AnPeriod.thisYear:
        year = now.year;
        month = now.month;
        txs = MbCalc.forYear(all, now.year);
        break;
    }

    final totals = MbCalc.totals(txs);
    final shares = MbCalc.expenseShares(txs);
    final hasData = txs.any((t) => t.isExpense);

    // Weekly bars — only meaningful for month scopes.
    final weekly = _period == _AnPeriod.thisYear
        ? <MbBar>[]
        : MbCalc.weeklyBars(MbCalc.forMonth(
            all, _period == _AnPeriod.lastMonth ? year : now.year,
            _period == _AnPeriod.lastMonth ? month : now.month));

    // Monthly trend — last 6 months.
    final months = MbCalc.monthlyBars(all, now.year, now.month, 6);

    final insights = MbInsights.generate(
      MbInsightInput(
        monthTxs: MbCalc.forMonth(all, year, month),
        prevMonthTxs: MbCalc.forMonth(all,
            MbCalc.previousMonth(year, month).$1,
            MbCalc.previousMonth(year, month).$2),
        allTxs: all,
        year: year,
        month: month,
        now: now,
        categoryName: (id) => state.categoryName(id),
        budgets: state.budgetLines(),
        declaredIncomeMinor: state.monthlyIncomeMinor,
        moneyOf: state.money,
      ),
      L,
      max: 8,
    );

    return Scaffold(
      appBar: AppBar(title: Text(L.analyticsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Period tabs
          SegmentedButton<_AnPeriod>(
            segments: [
              ButtonSegment(value: _AnPeriod.thisMonth, label: Text(L.anThisMonth)),
              ButtonSegment(value: _AnPeriod.lastMonth, label: Text(L.anLastMonth)),
              ButtonSegment(value: _AnPeriod.thisYear, label: Text(L.anThisYear)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 18),

          // Income vs expense summary
          MbFadeSlideIn(
            index: 1,
            child: MbCard(
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.south_west_rounded,
                    color: scheme.secondary,
                    label: L.income,
                    value: state.money(totals.income),
                  ),
                ),
                Container(
                    width: 1, height: 42, color: scheme.outlineVariant),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.north_east_rounded,
                    color: scheme.error,
                    label: L.expense,
                    value: state.money(totals.expense),
                  ),
                ),
                Container(
                    width: 1, height: 42, color: scheme.outlineVariant),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.savings_rounded,
                    color: scheme.primary,
                    label: L.dashNetSavings,
                    value: state.money(totals.net, sign: true),
                  ),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),

          // Donut
          MbSectionHeader(title: L.anSpendingByCategory),
          if (!hasData)
            MbFadeSlideIn(
              index: 2,
              child: MbCard(
                child: MbEmptyState(
                  emoji: '🍩',
                  title: L.anNoData,
                  body: L.anNoDataHint,
                ),
              ),
            )
          else
            MbFadeSlideIn(
              index: 2,
              child: MbCard(
                child: Column(
                  children: [
                    MbDonut(
                    size: 200,
                    strokeWidth: 22,
                    centerValue: state.moneyCompact(totals.expense),
                    centerLabel: L.expense,
                    segments: [
                      for (final s in shares)
                        MbDonutSegment(
                          fraction: s.value,
                          color: Color(state.catById[s.key]?.color ??
                              MbPalette.other),
                          label: state.categoryName(s.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...[
                    for (final s in shares)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(state.catById[s.key]?.color ??
                                    MbPalette.other),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.categoryName(s.key),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              state.pct(s.value * 100),
                              style: TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              state.money(MbCalc.byCategory(txs)[s.key]
                                      ?.expenseMinor ??
                                  0),
                              style: const TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            ),
          const SizedBox(height: 16),

          // Weekly bars
          if (weekly.isNotEmpty) ...[
            MbSectionHeader(title: L.anWeeklySpend),
            MbFadeSlideIn(
              index: 3,
              child: MbCard(
                child: MbBarChart(
                  height: 150,
                values: [for (final b in weekly) b.expenseMinor / 100],
                labels: [
                  for (var i = 0; i < weekly.length; i++)
                    _period == _AnPeriod.thisMonth
                        ? '${i + 1}'
                        : '${i + 1}',
                ],
                  valueFormatter: (i) =>
                      state.moneyCompact(weekly[i].expenseMinor),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Monthly trend
          MbSectionHeader(title: L.anMonthlyTrend),
          MbFadeSlideIn(
            index: 4,
            child: MbCard(
              child: MbMonthBars(
                height: 180,
              formatValue: (v) => state.moneyCompact(v),
              months: [
                for (final m in months)
                  (
                    label: MbFormat.monthLabel(
                        m.start.year, m.start.month,
                        bangla: state.bangla),
                    income: m.incomeMinor,
                    expense: m.expenseMinor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend for trend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(scheme.secondary, L.income),
              const SizedBox(width: 18),
              _legendDot(scheme.error, L.expense),
            ],
          ),
          const SizedBox(height: 16),

          // Insights
          MbSectionHeader(title: L.anInsights),
          ...[
            for (var k = 0; k < insights.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MbFadeSlideIn(
                  index: 5 + k,
                  child: MbInsightCard(insight: insights[k]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
