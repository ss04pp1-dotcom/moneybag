import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/insights.dart';
import '../core/l10n.dart';
import '../core/palette.dart';
import '../services/remote_config_service.dart';
import '../state/app_state.dart';
import '../widgets/ad_banner.dart';
import '../widgets/animations.dart';
import '../widgets/announcement_card.dart';
import '../widgets/banner.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/hero_header.dart';
import 'notifications_screen.dart';
import 'shell_screen.dart' show openAnalytics, openSavings;
import 'transaction_edit_screen.dart';
import 'transactions_screen.dart';

/// Home — full-bleed HERO greeting background, the floating "আজকের হিসাব"
/// card overlapping it, then month overview, budget pulse, insights, donut
/// and recents.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  void _openAdd() {
    MbNav.push(context, const TransactionEditScreen(), fullscreenDialog: true);
  }

  void _openNotifications() {
    MbNav.push(context, const NotificationsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    final txs = state.txOfMonth(_month.year, _month.month);
    final all = state.txView;
    final totals = MbCalc.totals(txs);
    final shares = MbCalc.expenseShares(txs).take(5).toList();
    final recent = [...state.transactions]..sort((a, b) {
        int cmp = b.date.compareTo(a.date);
        if (cmp == 0) cmp = b.createdAt.compareTo(a.createdAt);
        return cmp;
      });
    final recentTop = recent.take(5).toList();
    final hasAny = state.transactions.isNotEmpty;

    // Today's live totals — power the floating "আজকের হিসাব" card.
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayT = MbCalc.totals(MbCalc.between(
        all, todayStart, todayStart.add(const Duration(days: 1))));

    final effIncome = totals.income > 0
        ? totals.income
        : (state.monthlyIncomeMinor ?? 0);
    final savingsRate = effIncome > 0
        ? (totals.net / effIncome) * 100
        : double.nan;

    // Budget banner — shows when alerts are on and the overall budget is
    // warning or over.
    final budgetLines = state.budgetLines();
    MbBudgetStatus? bannerStatus;
    if (state.budgetAlerts) {
      for (final b in budgetLines) {
        if (b.categoryId == null) {
          final st = MbCalc.budgetStatus(all, _month.year, _month.month,
              categoryId: null, limitMinor: b.limitMinor, rollover: b.rollover);
          if (st.state == MbBudgetState.warning ||
              st.state == MbBudgetState.over) {
            bannerStatus = st;
          }
          break;
        }
      }
    }

    // v2.2.2: budget-pace daily allowance for the today card —
    // (effective overall limit − spent so far) / days left in the month,
    // i.e. what the user can still spend per day to land exactly on budget.
    // Independent of the budgetAlerts toggle (that only gates notifications);
    // having an overall budget is enough for the hint to make sense.
    String? safeDailyText;
    if (isCurrentMonth) {
      for (final b in budgetLines) {
        if (b.categoryId == null) {
          final st = MbCalc.budgetStatus(all, _month.year, _month.month,
              categoryId: null,
              limitMinor: b.limitMinor,
              rollover: b.rollover);
          final daysLeft =
              MbCalc.daysInMonth(now.year, now.month) - now.day + 1;
          if (daysLeft > 0 && st.remainingMinor > 0) {
            safeDailyText = state.money(st.remainingMinor ~/ daysLeft);
          }
          break;
        }
      }
    }

    // Insights
    final insights = MbInsights.generate(
      MbInsightInput(
        monthTxs: txs,
        prevMonthTxs: MbCalc.forMonth(
            all, MbCalc.previousMonth(_month.year, _month.month).$1,
            MbCalc.previousMonth(_month.year, _month.month).$2),
        allTxs: all,
        year: _month.year,
        month: _month.month,
        now: now,
        categoryName: (id) => state.categoryName(id),
        budgets: budgetLines,
        declaredIncomeMinor: state.monthlyIncomeMinor,
        moneyOf: state.money,
      ),
      L,
      max: 3,
    );

    final greeting =
        '${MbFormat.greeting(now, bangla: state.bangla)}'
        '${state.userName.isEmpty ? '' : ', ${state.userName}'}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: ListView(
          // 120 + hero band: the pre-v2.2.3 layout visually shifted the
          // whole column up 46px (phantom gap at the scroll end), so this
          // keeps the same end-of-scroll whitespace.
          padding: const EdgeInsets.only(bottom: 166),
          children: [
            // ============================================================
            // HERO — full-width greeting BACKGROUND (not a card).
            // Avatar left · notification bell right · text on background.
            // ============================================================
            ListenableBuilder(
              listenable: MbRemoteConfigService.instance,
              builder: (context, _) => MbHeroHeader(
                greeting: greeting,
                tagline: L.tagline,
                onNotificationTap: _openNotifications,
                showNotificationDot:
                    MbRemoteConfigService.instance.activeAnnouncement != null,
              ),
            ),

            // Everything below rides UP over the hero's EXTENDED backdrop
            // band (the hero paints 74px below its own layout box — see
            // MbHeroHeader.overlapBand). v2.2.3: the old approach translated
            // the column with Transform.translate(-46), which moved the paint
            // but NOT the tap routing — taps on the card's top 46px (the
            // whole “যোগ করুন” pill) hit the hero sliver and did nothing.
            // Normal flow + extended backdrop = identical visuals, working
            // taps on every pixel of the card.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 28px of the hero band stay visible as the gap between
                  // the tagline and the card; the card then overlaps the
                  // remaining 46px of backdrop.
                  const SizedBox(height: 28),

                  // ── FLOATING "আজকের হিসাব" card (whole card tappable) ──
                    _TodaySummaryCard(
                      state: state,
                      todayIncome: todayT.income,
                      todayExpense: todayT.expense,
                      onAdd: _openAdd,
                      safeDailyText: safeDailyText,
                    ),
                    const SizedBox(height: 14),

                    // ── Admin announcement (remote) + tips carousel ──
                    ListenableBuilder(
                      listenable: MbRemoteConfigService.instance,
                      builder: (context, _) => Column(
                        children: [
                          if (MbRemoteConfigService
                                  .instance.activeAnnouncement !=
                              null) ...[
                            const MbAnnouncementCard(),
                            const SizedBox(height: 14),
                          ],
                          const MbTipsBanner(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Month selector ──
                    // Overflow-safe: the pill shrinks + ellipsizes on narrow
                    // screens / large Bengali text scale (the v2.0.2 fix,
                    // kept in the restored 1.3.x layout — no bell here, it
                    // lives in the hero header).
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: MbMonthSelector(
                              year: _month.year,
                              month: _month.month,
                              label: MbFormat.monthLabel(_month.year,
                                  _month.month,
                                  bangla: state.bangla),
                              onPrev: () => _shiftMonth(-1),
                              onNext: () =>
                                  isCurrentMonth ? null : _shiftMonth(1),
                              nextEnabled: !isCurrentMonth,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => openAnalytics(context),
                          icon: Icon(Icons.insights_rounded,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Balance card (monthly net savings) ──
                    MbFadeSlideIn(
                      index: 2,
                      child: _BalanceCard(
                        incomeText: state.money(totals.income, sign: true),
                        expenseText: state.money(-totals.expense),
                        netText: state.money(totals.net, sign: true),
                        netValue: totals.net,
                        netOf: (v) => state.money(v, sign: true),
                        savingsRateLabel: savingsRate.isFinite
                            ? '${L.dashSavingsRate}: ${state.pct(savingsRate)}'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Budget banner ──
                    if (bannerStatus != null) ...[
                      MbFadeSlideIn(
                        index: 3,
                        child: _BudgetBanner(
                          status: bannerStatus,
                          money: state.money,
                          pctLabel: state.pct(bannerStatus.usedPct),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Weekly summary ──
                    if (state.weeklySummary && hasAny)
                      _WeeklySummary(state: state, now: now),

                    // ── Insights ──
                    MbSectionHeader(
                        title: '${L.anInsights} · ${L.dashThisMonth}',
                        actionLabel: L.seeAll,
                        onAction: () => openAnalytics(context)),
                    ...[
                      for (final i in insights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MbInsightCard(insight: i),
                        ),
                    ],
                    const SizedBox(height: 8),

                    // ── Donut: top categories ──
                    if (shares.isNotEmpty) ...[
                      MbSectionHeader(title: L.dashTopCategories),
                      MbCard(
                        child: Row(
                          children: [
                            MbDonut(
                              size: 150,
                              strokeWidth: 17,
                              centerValue:
                                  state.moneyCompact(totals.expense),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  for (final s in shares)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Color(state
                                                      .catById[s.key]
                                                      ?.color ??
                                                  MbPalette.other),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              state.categoryName(s.key),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily:
                                                    'NotoSansBengali',
                                                fontSize: 13,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            state.pct(s.value * 100),
                                            style: TextStyle(
                                              fontFamily:
                                                  'NotoSansBengali',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Recent transactions ──
                    MbSectionHeader(
                      title: L.dashRecent,
                      actionLabel: L.seeAll,
                      onAction: () =>
                          MbNav.push(context, const TransactionsScreen()),
                    ),
                    if (recentTop.isEmpty)
                      MbCard(
                        child: MbEmptyState(
                          emoji: '🧾',
                          title: L.noTransactions,
                          body: L.noTransactionsHint,
                          action: FilledButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: Text(L.addFirstTransaction),
                            onPressed: () => MbNav.push(
                                context,
                                const TransactionEditScreen(),
                                fullscreenDialog: true),
                          ),
                        ),
                      )
                    else
                      MbCard(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            for (var i = 0; i < recentTop.length; i++)
                              MbFadeSlideIn(
                                index: i,
                                offsetY: 16,
                                child: MbTransactionTile(
                                  emoji: state.catById[recentTop[i]
                                          .categoryId]
                                      ?.icon ??
                                      '💸',
                                  accent: Color(state
                                          .catById[recentTop[i].categoryId]
                                          ?.color ??
                                      MbPalette.other),
                                  title: state.categoryName(
                                      recentTop[i].categoryId),
                                  subtitle: recentTop[i].note,
                                  isExpense:
                                      recentTop[i].kind == 'expense',
                                  amountText: state.money(
                                    recentTop[i].kind == 'expense'
                                        ? -recentTop[i].amountMinor
                                        : recentTop[i].amountMinor,
                                    sign: false,
                                  ),
                                  onTap: () => MbNav.push(
                                      context,
                                      TransactionEditScreen(
                                          txId: recentTop[i].id)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    // ── Savings shortcut ── real numbers from live data.
                    _SavingsShortcut(
                      onTap: () => openSavings(context),
                      monthNetText: state.money(totals.net, sign: true),
                      goalSavedText:
                          '${L.savingsInGoals}: ${state.money(state.totalSaved)}'
                          ' · ${L.goalsCountMany(state.goals.length)}',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating "আজকের হিসাব" card — sits ABOVE the hero background, slightly
/// overlapping it. Content is live (today's real income/expense/net) and
/// SMART: an AnimatedSwitcher narrates the day (saved / overspent /
/// expense-only), and an empty state invites the first record of the day.
class _TodaySummaryCard extends StatelessWidget {
  final MbAppState state;
  final int todayIncome;
  final int todayExpense;
  final VoidCallback onAdd;

  /// v2.2.2: budget-pace daily allowance — "আজ নিরাপদে খরচ করা যায় ৳X".
  /// Null when there is no overall budget (or the budget is already over,
  /// in which case the red banner above is doing the talking).
  final String? safeDailyText;

  const _TodaySummaryCard({
    required this.state,
    required this.todayIncome,
    required this.todayExpense,
    required this.onAdd,
    this.safeDailyText,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final net = todayIncome - todayExpense;
    final hasActivity = (todayIncome + todayExpense) > 0;

    final weekday =
        (state.bangla ? MbFormat.bnWeekdays : MbFormat.enWeekdays)[
            now.weekday % 7];
    final dayNum = state.bangla
        ? MbFormat.toBnDigits('${now.day}')
        : '${now.day}';
    final dateLine = MbFormat.dayLabel(now, bangla: state.bangla);

    // Smart narrative — tone-coloured line under the stats.
    final (narrative, tone) = !hasActivity
        ? (null, scheme.onSurfaceVariant)
        : (todayIncome > 0 && net >= 0)
            ? (L.todaySavedToday(state.money(net)), MbPalette.income)
            : (todayIncome > 0)
                ? (L.todayOverspent, MbPalette.warning)
                : (L.todayExpenseOnly(state.money(todayExpense)),
                    scheme.onSurfaceVariant);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - t)),
          child: child,
        ),
      ),
      // v2.2.3: the WHOLE card is the add button — users naturally tap the
      // card (top included) expecting “add today's record”. The inner pill
      // stays as the visual affordance; both trigger the same [onAdd].
      child: MbPressable(
        onTap: onAdd,
        pressedScale: 0.985,
        borderRadius: BorderRadius.circular(24),
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B2A47), Color(0xFF101A30)],
                )
              : null,
          color: dark ? null : scheme.surface,
          border: Border.all(
            color: dark
                ? Colors.white.withOpacity(0.07)
                : scheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.45 : 0.16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header: date tile · title · add pill ──
            Row(
              children: [
                // date tile (weekday + day number)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [MbPalette.cyan, MbPalette.blue],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekday,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF061224),
                        ),
                      ),
                      Text(
                        dayNum,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.todaySummaryTitle,
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLine,
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // add pill — green→cyan keeps the brand while blending
                // with the hero's blue atmosphere
                MbPressable(
                  pressedScale: 0.93,
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [MbPalette.green, MbPalette.cyan],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: MbPalette.cyan.withOpacity(0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 17, color: Color(0xFF06130C)),
                        const SizedBox(width: 3),
                        Text(
                          L.todayAdd,
                          style: const TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF06130C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── smart body: stats or empty nudge ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.22),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: hasActivity
                  ? _statsRow(context, scheme, L, key: const ValueKey('stats'))
                  : _emptyNudge(context, scheme, L, key: const ValueKey('empty')),
            ),

            // ── narrative line ──
            if (narrative != null) ...[
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                child: Row(
                  key: ValueKey(narrative),
                  children: [
                    Icon(
                      tone == MbPalette.income
                          ? Icons.emoji_events_rounded
                          : (tone == MbPalette.warning
                              ? Icons.trending_down_rounded
                              : Icons.trending_flat_rounded),
                      size: 16,
                      color: tone,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        narrative,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: tone,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── v2.2.2: budget-pace daily allowance ──
            if (safeDailyText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.savings_rounded,
                      size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      L.todaySafeToSpend(safeDailyText!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _statsRow(BuildContext context, ColorScheme scheme, MbStrings L,
      {Key? key}) {
    final net = todayIncome - todayExpense;
    return Row(
      key: key,
      children: [
        Expanded(
          child: _miniStat(
            context,
            label: L.income,
            value: todayIncome,
            formatter: (v) => state.money(v, sign: true),
            valueColor: MbPalette.income,
            icon: Icons.south_west_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            context,
            label: L.expense,
            value: todayExpense,
            formatter: (v) => state.money(v),
            valueColor: MbPalette.expense,
            icon: Icons.north_east_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            context,
            label: L.todayNet,
            value: net,
            formatter: (v) => state.money(v, sign: true),
            valueColor: MbPalette.cyan,
            icon: net >= 0
                ? Icons.savings_rounded
                : Icons.remove_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(
    BuildContext context, {
    required String label,
    required int value,
    required String Function(int) formatter,
    required Color valueColor,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: valueColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: MbCountUp(
                value: value,
                formatter: formatter,
                duration: const Duration(milliseconds: 700),
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyNudge(BuildContext context, ColorScheme scheme, MbStrings L,
      {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, color: scheme.primary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.todaySummaryNoTx,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L.todaySummaryNoTxHint,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String incomeText;
  final String expenseText;
  final String netText;
  final int? netValue;
  final String Function(int)? netOf;
  final String? savingsRateLabel;

  const _BalanceCard({
    required this.incomeText,
    required this.expenseText,
    required this.netText,
    this.netValue,
    this.netOf,
    this.savingsRateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final L = context.L;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L.dashNetSavings,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (savingsRateLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    savingsRateLabel!,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (netValue != null && netOf != null)
            MbCountUp(
              value: netValue!,
              formatter: netOf!,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                height: 1.1,
              ),
            )
          else
            Text(
              netText,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                height: 1.1,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.south_west_rounded,
                        color: scheme.secondary, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.income,
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            incomeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.north_east_rounded,
                        color: scheme.error, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.expense,
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            expenseText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetBanner extends StatelessWidget {
  final MbBudgetStatus status;
  final String Function(int) money;
  final String pctLabel;

  const _BudgetBanner({
    required this.status,
    required this.money,
    required this.pctLabel,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final over = status.state == MbBudgetState.over;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: over ? scheme.errorContainer : MbPalette.warning.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            over ? Icons.error_rounded : Icons.warning_amber_rounded,
            color: over ? scheme.error : MbPalette.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  over ? L.budgetOverBody : L.budgetNearBody,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${money(status.spentMinor)} / ${money(status.effectiveLimit)} · $pctLabel',
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  final MbAppState state;
  final DateTime now;

  const _WeeklySummary({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    // This week (last 7 days).
    final from = DateTime(now.year, now.month, now.day - 6);
    final weekTxs = MbCalc.between(state.txView, from,
        DateTime(now.year, now.month, now.day + 1));
    final t = MbCalc.totals(weekTxs);
    final days = <MbBar>[
      for (var d = 0; d < 7; d++)
        MbBar(
          start: DateTime(now.year, now.month, now.day - 6 + d),
          expenseMinor: 0,
          incomeMinor: 0,
        ),
    ];
    for (final tx in weekTxs) {
      final idx = DateTime(tx.date.year, tx.date.month, tx.date.day)
          .difference(DateTime(now.year, now.month, now.day - 6))
          .inDays;
      if (idx >= 0 && idx < 7) {
        if (tx.isExpense) {
          days[idx] = MbBar(
              start: days[idx].start,
              expenseMinor: days[idx].expenseMinor + tx.amountMinor);
        }
      }
    }
    final weekdayNames =
        state.bangla ? MbFormat.bnWeekdays : MbFormat.enWeekdays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_week_rounded,
                    color: scheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L.notifWeeklyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  state.moneyCompact(t.expense),
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MbBarChart(
              height: 90,
              values: [
                for (var i = 0; i < 7; i++)
                  days[i].expenseMinor / 100,
              ],
              labels: [
                for (var i = 0; i < 7; i++)
                  weekdayNames[
                      DateTime(now.year, now.month, now.day - 6 + i)
                          .weekday %
                      7],
              ],
              colors: [
                for (var i = 0; i < 7; i++)
                  i == 6 ? scheme.primary : scheme.primary.withOpacity(0.45),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsShortcut extends StatelessWidget {
  final VoidCallback onTap;
  final String monthNetText;
  final String goalSavedText;

  const _SavingsShortcut({
    required this.onTap,
    required this.monthNetText,
    required this.goalSavedText,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final L = context.L;
    return MbCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('🐷', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L.savingsTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  goalSavedText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                monthNetText,
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              Text(
                L.savingsMonthNet,
                style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
