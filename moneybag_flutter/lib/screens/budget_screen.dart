import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/palette.dart';
import '../data/database.dart';
import '../screens/categories_screen.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Budgets — overall monthly cap + per-category caps with live progress.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final now = DateTime.now();
    final all = state.txView;

    // Overall budget
    Budget? overallRow;
    final catBudgets = <Budget>[];
    for (final b in state.budgets) {
      if (b.categoryId == null) {
        overallRow = b;
      } else {
        catBudgets.add(b);
      }
    }
    // Sort: by spend share desc for nicer priority.
    final shares = MbCalc.expenseShares(MbCalc.forMonth(all, _month.year, _month.month));
    catBudgets.sort((a, b) {
      final ai = shares.indexWhere((s) => s.key == a.categoryId);
      final bi = shares.indexWhere((s) => s.key == b.categoryId);
      return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
    });

    final overallStatus = overallRow == null
        ? null
        : MbCalc.budgetStatus(all, _month.year, _month.month,
            limitMinor: overallRow.amountMinor, rollover: overallRow.rollover);

    return Scaffold(
      appBar: AppBar(
        title: Text(L.budgetTitle),
        actions: [
          IconButton(
            tooltip: L.budgetSet,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openEditor(context, state),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          MbMonthSelector(
            year: _month.year,
            month: _month.month,
            label: MbFormat.monthLabel(_month.year, _month.month,
                bangla: state.bangla),
            onPrev: () =>
                setState(() => _month = DateTime(_month.year, _month.month - 1)),
            onNext: () =>
                setState(() => _month = DateTime(_month.year, _month.month + 1)),
          ),
          const SizedBox(height: 12),

          // Overall
          if (overallStatus != null && overallRow != null)
            MbFadeSlideIn(
              index: 1,
              child: _OverallBudgetCard(
                state: state,
                row: overallRow,
                status: overallStatus,
                onEdit: () => _openEditor(context, state, existing: overallRow),
              ),
            )
          else
            MbFadeSlideIn(
              index: 1,
              child: _NoBudgetCard(
                icon: Icons.donut_small_rounded,
                label: L.budgetOverallCard,
                // v2.2.1: overall-specific hint (was the same generic hint as
                // the category card — the two empty cards looked identical
                // and users read them as a duplicated/broken card).
                hint: L.budgetOverallHint,
                cta: L.budgetSet,
                onCta: () => _openEditor(context, state, overall: true),
              ),
            ),
          const SizedBox(height: 16),

          // Category budgets
          MbSectionHeader(title: L.budgetByCategory),
          if (catBudgets.isEmpty)
            MbFadeSlideIn(
              index: 2,
              child: _NoBudgetCard(
                icon: Icons.category_rounded,
                label: L.budgetByCategory,
                hint: L.budgetCategoryHint,
                cta: L.budgetAddFirst,
                onCta: () => _openEditor(context, state),
              ),
            )
          else
            ...[
              for (var j = 0; j < catBudgets.length; j++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MbFadeSlideIn(
                    index: 2 + j,
                    child: _CategoryBudgetCard(
                      state: state,
                      row: catBudgets[j],
                      status: MbCalc.budgetStatus(
                        all,
                        _month.year,
                        _month.month,
                        categoryId: catBudgets[j].categoryId,
                        limitMinor: catBudgets[j].amountMinor,
                        rollover: catBudgets[j].rollover,
                      ),
                      onEdit: () => _openEditor(context, state,
                          existing: catBudgets[j]),
                    ),
                  ),
                ),
            ],
          if (overallStatus != null || catBudgets.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${L.budgetAlertLabel} · ${L.budgetAlertHelp}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (now.year != _month.year || now.month != _month.month)
            Text(
              '${L.date}: ${MbFormat.monthLabel(_month.year, _month.month, bangla: state.bangla)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  void _openEditor(
    BuildContext context,
    MbAppState state, {
    Budget? existing,
    bool overall = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetSheet(
        state: state,
        existing: existing,
        // v2.2.5 CRITICAL FIX: was `overall || existing?.categoryId == null`
        // — when adding a NEW budget (existing == null) the right side
        // evaluated TRUE for every sheet, so "+ বাজেট যোগ করুন" (Category
        // Budget) opened as the OVERALL editor: category chips never
        // rendered and the save silently wrote an overall budget (the
        // "category budget has no categories" + "two identical budgets"
        // reports). `categoryId == null` must only apply when an EXISTING
        // overall row is being edited.
        overall: overall ||
            (existing != null && existing.categoryId == null),
      ),
    );
  }
}

class _NoBudgetCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final String cta;
  final VoidCallback onCta;

  const _NoBudgetCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.cta,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // v2.2.1: distinct icon per card so the two empty states are
              // visually distinguishable at a glance.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(hint, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(cta),
            onPressed: onCta,
          ),
        ],
      ),
    );
  }
}

class _OverallBudgetCard extends StatelessWidget {
  final MbAppState state;
  final Budget row;
  final MbBudgetStatus status;
  final VoidCallback onEdit;

  const _OverallBudgetCard({
    required this.state,
    required this.row,
    required this.status,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    return MbCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.donut_small_rounded,
                    color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L.budgetOverallCard,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (row.rollover)
                      Text(
                        L.budgetRollover,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.primary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    state.pct(status.usedPct),
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: status.state == MbBudgetState.over
                          ? MbPalette.danger
                          : (status.state == MbBudgetState.warning
                              ? MbPalette.warning
                              : scheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                state.money(status.spentMinor),
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${L.budgetOf} ${state.money(status.effectiveLimit)}',
                style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 13,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MbProgressBar(value: status.usedPct / 100),
          const SizedBox(height: 8),
          Text(
            status.isOver
                ? '${L.budgetOverShort} ${state.money(-status.remainingMinor)}'
                : '${L.budgetLeftShort} ${state.money(status.remainingMinor)}',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 12.5,
              color: status.isOver ? MbPalette.danger : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  final MbAppState state;
  final Budget row;
  final MbBudgetStatus status;
  final VoidCallback onEdit;

  const _CategoryBudgetCard({
    required this.state,
    required this.row,
    required this.status,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cat = state.catById[row.categoryId];
    final color = Color(cat?.color ?? MbPalette.other);
    return MbCard(
      onTap: onEdit,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                    child: Text(cat?.icon ?? '💸',
                        style: const TextStyle(fontSize: 19))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.categoryName(row.categoryId),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      '${state.money(status.spentMinor)} / ${state.money(status.effectiveLimit)}'
                      '${row.rollover ? '  ·  ${context.L.budgetRollover}' : ''}',
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                state.pct(status.usedPct),
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: status.state == MbBudgetState.over
                      ? MbPalette.danger
                      : (status.state == MbBudgetState.warning
                          ? MbPalette.warning
                          : scheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MbProgressBar(value: status.usedPct / 100),
        ],
      ),
    );
  }
}

class _BudgetSheet extends StatefulWidget {
  final MbAppState state;
  final Budget? existing;
  final bool overall;

  const _BudgetSheet({
    required this.state,
    required this.existing,
    required this.overall,
  });

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  final _amount = TextEditingController();
  String? _categoryId;
  bool _rollover = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amount.text = (e.amountMinor / 100).toStringAsFixed(0);
      _categoryId = e.categoryId;
      _rollover = e.rollover;
    } else if (!widget.overall) {
      // v2.2.3: pre-select the most-used expense category that has no
      // budget yet — the sheet opens one tap away from saved instead of
      // confronting the user with a bare, unselected chip wall.
      _categoryId = _suggestCategory();
    }
  }

  /// Most frequently used (last 90 days) active expense category without
  /// an existing budget; null when nothing qualifies.
  String? _suggestCategory() {
    final budgeted = widget.state.budgets
        .map((b) => b.categoryId)
        .whereType<String>()
        .toSet();
    final cats = widget.state.activeCategoriesOfKind('expense');
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final counts = <String, int>{};
    for (final t in widget.state.transactions) {
      if (t.kind != 'expense') continue;
      if (t.categoryId == null || t.date.isBefore(cutoff)) continue;
      counts[t.categoryId!] = (counts[t.categoryId!] ?? 0) + 1;
    }
    String? best;
    int bestCount = 0;
    for (final c in cats) {
      if (budgeted.contains(c.id)) continue;
      final n = counts[c.id] ?? 0;
      if (n > bestCount) {
        best = c.id;
        bestCount = n;
      }
    }
    // No history at all → first unbudgeted category so the sheet still
    // starts with a valid selection.
    return best ??
        (cats.where((c) => !budgeted.contains(c.id)).isEmpty
            ? null
            : cats.firstWhere((c) => !budgeted.contains(c.id)).id);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final L = context.L;
    final v = MbFormat.parseAmount(_amount.text);
    // v2.2.5 CRITICAL FIX: same precedence bug as _openEditor — the old
    // `widget.overall && widget.existing == null ||
    // widget.existing?.categoryId == null` was TRUE for every NEW budget
    // (existing == null → second clause true), so a category budget save
    // wrote categoryId: null (an overall budget) instead.
    final isOverall = widget.overall ||
        (widget.existing != null && widget.existing!.categoryId == null);
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.requiredField)));
      return;
    }
    // v2.2.3: a CATEGORY budget without a category used to save silently as
    // an overall budget (duplicate-looking card on the budget screen).
    if (!isOverall && _categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.txSelectCategory)));
      return;
    }
    await widget.state.saveBudget(
      id: widget.existing?.id,
      categoryId: isOverall ? null : _categoryId,
      amountMinor: (v * 100).round(),
      rollover: _rollover,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.budgetSaved)));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    // v2.2.5 CRITICAL FIX: see _save() — chips now actually render for a
    // NEW category budget (this used to always take the isOverall branch,
    // hiding the chips behind the "+ বাজেট যোগ করুন" empty report).
    final isOverall = widget.overall ||
        (widget.existing != null && widget.existing!.categoryId == null);
    final cats = widget.state.activeCategoriesOfKind('expense');

    // The sheet grows tall (chips + suggestion + keyboard), so it scrolls
    // instead of overflowing — isScrollControlled was already true.
    return SingleChildScrollView(
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
            widget.existing == null ? L.budgetSet : L.budgetEdit,
            style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),

          Text(L.budgetForLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (isOverall)
            Text(
              L.budgetOverallOption,
              style: TextStyle(color: scheme.primary,
                  fontWeight: FontWeight.w700),
            )
          else if (cats.isEmpty)
            // v2.2.3: with the self-healing seed this is near-impossible, but
            // an empty state with an escape hatch beats a silent blank wall.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    L.budgetNoCategories,
                    style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 13,
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    // v2.2.5: was a plain Navigator.pop — the button said
                    // "manage categories" but went nowhere. Now it actually
                    // opens the categories screen (sheet closes first).
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CategoriesScreen()),
                      );
                    },
                    icon: const Icon(Icons.category_rounded, size: 18),
                    label: Text(L.budgetManageCategories),
                  ),
                ],
              ),
            )
          else
            // v2.2.3: was a fixed 150px ListView — on the user's device the
            // chips were reportedly invisible/unpickable. A Wrap shows every
            // option at once, wraps on small screens and keeps all chips
            // reachable while the keyboard is up (sheet scrolls).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    avatar: Text(c.icon,
                        style: const TextStyle(fontSize: 16)),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (s) => setState(() {
                      if (s) _categoryId = c.id;
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 14),

          Text(L.budgetLimitLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // v2.2.2: Bengali digits allowed (parseAmount normalises).
              FilteringTextInputFormatter.allow(
                  RegExp(r'^[0-9০-৯]{0,9}(\.[0-9০-৯]{0,2})?$')),
            ],
            decoration: InputDecoration(
              hintText: L.budgetLimitHint,
              prefixText: '৳ ',
            ),
          ),

          // ── v2.1: smart suggestion from real history ──
          Builder(builder: (context) {
            final avg = MbCalc.trailingMonthlyAvg(
              widget.state.txView,
              DateTime.now(),
              categoryId: isOverall ? null : _categoryId,
            );
            if (avg <= 0) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  L.budgetSuggestNoData,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              );
            }
            final avgText = MbFormat.money(avg,
                bengaliDigits: widget.state.bengaliDigits);
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${L.budgetSuggestAvg}: $avgText',
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => setState(
                          () => _amount.text = (avg ~/ 100).toString()),
                      child: Text(L.budgetSuggestUse),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(L.budgetRollover, style: const TextStyle(fontSize: 14)),
            subtitle: Text(L.budgetRolloverHint,
                style: const TextStyle(fontSize: 12)),
            value: _rollover,
            onChanged: (v) => setState(() => _rollover = v),
          ),
          const SizedBox(height: 8),

          FilledButton(
            onPressed: _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(widget.existing == null ? L.budgetSet : L.save),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await widget.state.deleteBudget(widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(L.budgetDelete,
                  style: TextStyle(color: scheme.error)),
            ),
          ],
        ],
      ),
    );
  }
}
