import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/palette.dart';
import '../data/database.dart';
import '../state/app_state.dart';
import '../widgets/ad_banner.dart';
import '../widgets/animations.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Savings — total saved + goal piggy banks with progress rings.
class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final now = DateTime.now();

    final goals = state.goals;
    final total = state.totalSaved;
    // Real savings this month from actual transactions (income − expense).
    final monthNet = MbCalc.totals(state.txOfMonth(now.year, now.month)).net;
    return Scaffold(
      appBar: AppBar(
        title: Text(L.savingsTitle),
        actions: [
          IconButton(
            tooltip: L.goalAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openGoalSheet(context, state),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Savings hero — real numbers: total saved + this month's net +
          // amount locked in goals, all computed from live data.
          MbFadeSlideIn(
            index: 0,
            child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MbPalette.greenDark, MbPalette.green],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MbScaleIn(
                      child: Text('🐷', style: TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.savingsTotalSaved,
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              color: Color(0xCC06130C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            state.money(total),
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              color: Color(0xFF06130C),
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(
                        label: L.savingsMonthNet,
                        value: state.money(monthNet, sign: true),
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 36,
                        color: const Color(0x3306130C)),
                    Expanded(
                      child: _HeroStat(
                        label: L.savingsInGoals,
                        value: state.money(state.totalSaved),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 20),

          MbSectionHeader(title: '${L.goalsTitle} · ${goals.length}'),
          if (goals.isEmpty)
            MbCard(
              child: MbEmptyState(
                emoji: '🎯',
                title: L.goalsEmpty,
                body: L.goalsEmptyHint,
                action: FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(L.goalAdd),
                  onPressed: () => _openGoalSheet(context, state),
                ),
              ),
            )
          else
            ...[
              for (var j = 0; j < goals.length; j++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MbFadeSlideIn(
                    index: 1 + j,
                    child: _GoalCard(
                      state: state,
                      goal: goals[j],
                      saved: state.savedForGoal(goals[j].id),
                      now: now,
                      onTap: () => _openGoalDetail(context, state, goals[j]),
                    ),
                  ),
                ),
            ],

          const SizedBox(height: 16),
          // v2.2.5: home-screen-style bottom banner ad.
          const MbAdBanner(),
        ],
      ),
    );
  }

  void _openGoalSheet(BuildContext context, MbAppState state, {Goal? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(state: state, existing: existing),
    );
  }

  void _openGoalDetail(BuildContext context, MbAppState state, Goal goal) {
    MbNav.push(context, _GoalDetailScreen(goalId: goal.id));
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoSansBengali',
            color: Color(0xCC06130C),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'NotoSansBengali',
            color: Color(0xFF06130C),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final MbAppState state;
  final Goal goal;
  final int saved;
  final DateTime now;
  final VoidCallback onTap;

  const _GoalCard({
    required this.state,
    required this.goal,
    required this.saved,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final progress = MbCalc.goalProgress(goal.targetMinor, saved);
    final done = saved >= goal.targetMinor;
    String? dateInfo;
    if (goal.targetDate != null) {
      final days =
          DateTime(goal.targetDate!.year, goal.targetDate!.month, goal.targetDate!.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
      if (done) {
        dateInfo = L.goalCompletedBadge;
      } else if (days < 0) {
        dateInfo = L.goalOverdue;
      } else {
        dateInfo = '$days ${L.goalDaysLeft}';
      }
    } else if (done) {
      dateInfo = L.goalCompletedBadge;
    }

    return MbCard(
      onTap: onTap,
      child: Row(
        children: [
          MbProgressRing(
            progress: progress,
            size: 74,
            strokeWidth: 8,
            child: Text(
              goal.icon,
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15.5),
                      ),
                    ),
                    if (dateInfo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: done
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          dateInfo,
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: done
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.money(saved)} ${L.goalProgressOf} ${state.money(goal.targetMinor)}',
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                MbProgressBar(value: progress, height: 8),
                const SizedBox(height: 6),
                Text(
                  '${state.pct(progress * 100)}${done ? '' : ' · ${L.goalNeedMore} ${state.money(goal.targetMinor - saved)}'}',
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12,
                    color: done ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),

                // ── v2.1: "at this pace" ETA from the goal's own deposit rate ──
                if (!done) ...[
                  Builder(builder: (_) {
                    final months = MbCalc.monthsToGoal(
                      targetMinor: goal.targetMinor,
                      savedMinor: saved,
                      monthlyRateMinor: state.goalMonthlyRate(goal.id),
                    );
                    if (months == null ||
                        !months.isFinite ||
                        months > 600) {
                      return const SizedBox.shrink();
                    }
                    final m = months.ceil();
                    final eta =
                        DateTime(now.year, now.month + m);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded,
                              size: 13, color: scheme.primary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${L.goalEtaLabel} · ${L.goalEtaB(m, MbFormat.monthLabel(eta.year, eta.month, bangla: state.bangla))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  final MbAppState state;
  final Goal? existing;

  const _GoalSheet({required this.state, required this.existing});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String _icon = '🐷';
  DateTime? _targetDate;

  static const _icons = ['🐷', '📱', '✈️', '🏠', '🎓', '🏍️', '💍', '🎯', '💻', '🎁'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _target.text = (e.targetMinor / 100).toStringAsFixed(0);
      _icon = e.icon;
      _targetDate = e.targetDate;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final L = context.L;
    final name = _name.text.trim();
    final v = MbFormat.parseAmount(_target.text);
    if (name.isEmpty || v == null || v <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.requiredField)));
      return;
    }
    await widget.state.saveGoal(
      id: widget.existing?.id,
      name: name,
      targetMinor: (v * 100).round(),
      icon: _icon,
      targetDate: _targetDate,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? L.goalAdd : L.goalEdit,
            style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            decoration: InputDecoration(hintText: L.goalNameHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // v2.2.2: Bengali digits allowed (parseAmount normalises).
              FilteringTextInputFormatter.allow(
                  RegExp(r'^[0-9০-৯]{0,9}(\.[0-9০-৯]{0,2})?$')),
            ],
            decoration: InputDecoration(
              hintText: L.goalTargetHint,
              prefixText: '৳ ',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final i in _icons)
                GestureDetector(
                  onTap: () => setState(() => _icon = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _icon == i
                          ? MbPalette.green.withOpacity(0.18)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: _icon == i
                          ? Border.all(color: MbPalette.green, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(i, style: const TextStyle(fontSize: 21)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(
              _targetDate == null
                  ? '${L.goalTargetDate} (${L.goalTargetDateOptional})'
                  : MbFormat.dayLabel(_targetDate!, bangla: true),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(L.save),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(L.goalDelete),
                    content: Text(L.goalDeleteBody),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(L.cancel)),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: MbPalette.danger,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(L.delete),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await widget.state.deleteGoal(widget.existing!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(L.goalDelete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Goal detail — progress, contribute/withdraw, history, edit.
class _GoalDetailScreen extends StatelessWidget {
  final String goalId;

  const _GoalDetailScreen({required this.goalId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final goal = state.goals
        .where((g) => g.id == goalId)
        .firstOrNull;
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(L.appsNoData)),
      );
    }
    final saved = state.savedForGoal(goalId);
    final progress = MbCalc.goalProgress(goal.targetMinor, saved);
    final done = saved >= goal.targetMinor;
    final contribs = state.contributions
        .where((c) => c.goalId == goalId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _GoalSheet(state: state, existing: goal),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
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
              children: [
                MbProgressRing(
                  progress: progress,
                  size: 120,
                  strokeWidth: 12,
                  child: Text(goal.icon,
                      style: const TextStyle(fontSize: 44)),
                ),
                const SizedBox(height: 16),
                Text(
                  done ? L.goalTargetReached : state.money(saved),
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: done ? 18 : 26,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '${L.goalProgressOf} ${state.money(goal.targetMinor)} · ${state.pct(progress * 100)}',
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                MbProgressBar(value: progress, height: 10),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(L.goalContribute),
                  onPressed: () => _contributeSheet(context, state, goal.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          MbSectionHeader(title: L.goalHistory),
          if (contribs.isEmpty)
            MbCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  L.goalNoHistory,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            MbCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final c in contribs)
                    ListTile(
                      leading: Icon(
                        c.amountMinor >= 0
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: c.amountMinor >= 0
                            ? scheme.secondary
                            : scheme.error,
                      ),
                      title: Text(
                        state.money(c.amountMinor, sign: c.amountMinor > 0),
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: c.note == null
                          ? null
                          : Text(c.note!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        MbFormat.dayLabel(c.date, bangla: state.bangla),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      onLongPress: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(L.delete),
                            content: Text(L.txDeleteConfirmBody),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(L.cancel)),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: MbPalette.danger,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(L.delete),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await state.deleteContribution(c.id);
                        }
                      },
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          // v2.2.5: home-screen-style bottom banner ad.
          const MbAdBanner(),
        ],
      ),
    );
  }

  void _contributeSheet(BuildContext context, MbAppState state, String goalId) {
    final controller = TextEditingController();
    final noteCtl = TextEditingController();
    var deposit = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.L.goalContributeTitle,
                style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                      value: true,
                      label: Text(context.L.goalContribute),
                      icon: const Icon(Icons.add_rounded, size: 17)),
                  ButtonSegment(
                      value: false,
                      label: Text(context.L.goalWithdraw),
                      icon: const Icon(Icons.remove_rounded, size: 17)),
                ],
                selected: {deposit},
                onSelectionChanged: (s) => setSheet(() => deposit = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  // v2.2.2: Bengali digits allowed (parseAmount normalises).
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^[0-9০-৯]{0,9}(\.[0-9০-৯]{0,2})?$')),
                ],
                decoration: InputDecoration(
                  hintText: context.L.amount,
                  prefixText: '৳ ',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtl,
                decoration:
                    InputDecoration(hintText: context.L.noteHint),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  final L = context.L;
                  final v = MbFormat.parseAmount(controller.text);
                  if (v == null || v <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(L.requiredField)));
                    return;
                  }
                  final minor = (v * 100).round() * (deposit ? 1 : -1);
                  await state.contribute(goalId, minor,
                      note: noteCtl.text.trim().isEmpty
                          ? null
                          : noteCtl.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(L.goalContributionAdded)));
                    Navigator.pop(context);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(context.L.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
