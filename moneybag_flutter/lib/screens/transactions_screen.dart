import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/palette.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import 'transaction_edit_screen.dart';

/// Transactions list — search, type/category filters, grouped by day.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _TxFilter { all, expense, income }

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  _TxFilter _filter = _TxFilter.all;
  String? _category;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    var txs = state.transactions.toList();

    // Filter
    if (_filter == _TxFilter.expense) {
      txs = txs.where((t) => t.kind == 'expense').toList();
    } else if (_filter == _TxFilter.income) {
      txs = txs.where((t) => t.kind == 'income').toList();
    }
    if (_category != null) {
      txs = txs.where((t) => t.categoryId == _category).toList();
    }
    // Search
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      txs = txs.where((t) {
        final note = (t.note ?? '').toLowerCase();
        final cat = state.categoryName(t.categoryId).toLowerCase();
        return note.contains(q) || cat.contains(q);
      }).toList();
    }
    txs.sort((a, b) {
      var cmp = b.date.compareTo(a.date);
      if (cmp == 0) cmp = b.createdAt.compareTo(a.createdAt);
      return cmp;
    });

    // Group by day.
    final groups = <_DayGroup>[];
    for (final t in txs) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      if (groups.isEmpty || groups.last.day != key) {
        groups.add(_DayGroup(day: key));
      }
      groups.last.items.add(t);
      groups.last.sumExpense += t.kind == 'expense' ? t.amountMinor : 0;
      groups.last.sumIncome += t.kind == 'income' ? t.amountMinor : 0;
    }

    final expenseCats = state.activeCategoriesOfKind('expense');
    final incomeCats = state.activeCategoriesOfKind('income');

    return Scaffold(
      appBar: AppBar(
        title: Text(L.txTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => MbNav.push(context,
                const TransactionEditScreen(),
                fullscreenDialog: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: L.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [
                _chip(
                  context,
                  label: L.txFiltersAll,
                  selected: _filter == _TxFilter.all && _category == null,
                  onTap: () => setState(() {
                    _filter = _TxFilter.all;
                    _category = null;
                  }),
                ),
                const SizedBox(width: 8),
                _chip(
                  context,
                  label: L.txFiltersExpense,
                  selected: _filter == _TxFilter.expense,
                  onTap: () => setState(() => _filter = _TxFilter.expense),
                ),
                const SizedBox(width: 8),
                _chip(
                  context,
                  label: L.txFiltersIncome,
                  selected: _filter == _TxFilter.income,
                  onTap: () => setState(() => _filter = _TxFilter.income),
                ),
                const SizedBox(width: 8),
                for (final c in [...expenseCats, ...incomeCats])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _chip(
                      context,
                      label: '${c.icon} ${c.name}',
                      selected: _category == c.id,
                      onTap: () => setState(() {
                        _category = _category == c.id ? null : c.id;
                        _filter = _TxFilter.all;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? MbEmptyState(
                    emoji: '🔍',
                    title: L.txEmptyFiltered,
                    body: L.noTransactionsHint,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final g = groups[i];
                      return MbFadeSlideIn(
                        index: i,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 10, bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    MbFormat.dayGroupLabel(
                                      g.day,
                                      DateTime(now.year, now.month, now.day),
                                      bangla: state.bangla,
                                    ),
                                    style: TextStyle(
                                      fontFamily: 'NotoSansBengali',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${g.sumExpense > 0 ? state.money(-g.sumExpense) : ''}'
                                  '${g.sumExpense > 0 && g.sumIncome > 0 ? '  ·  ' : ''}'
                                  '${g.sumIncome > 0 ? state.money(g.sumIncome, sign: true) : ''}',
                                  style: TextStyle(
                                    fontFamily: 'NotoSansBengali',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MbCard(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                for (final t in g.items)
                                  MbTransactionTile(
                                    emoji: state.catById[t.categoryId]?.icon ??
                                        '💸',
                                    accent: Color(state
                                            .catById[t.categoryId]?.color ??
                                        MbPalette.other),
                                    title: state.categoryName(t.categoryId),
                                    subtitle: t.note,
                                    isExpense: t.kind == 'expense',
                                    amountText: state.money(
                                      t.kind == 'expense'
                                          ? -t.amountMinor
                                          : t.amountMinor,
                                    ),
                                    onTap: () => MbNav.push(context,
                                        TransactionEditScreen(txId: t.id)),
                                    onLongPress: () =>
                                        _confirmDelete(context, state, t.id),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, MbAppState state, String id) {
    final L = context.L;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.txDeleteConfirm),
        content: Text(L.txDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MbPalette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await state.deleteTransaction(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(L.txDeleted)));
              }
            },
            child: Text(L.delete),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MbPalette.green : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? MbPalette.green : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFF06130C)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DayGroup {
  final DateTime day;
  final List<dynamic> items = [];
  int sumExpense = 0;
  int sumIncome = 0;

  _DayGroup({required this.day});
}
