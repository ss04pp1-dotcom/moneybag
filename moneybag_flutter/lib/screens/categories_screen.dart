import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../data/database.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Category manager — expense/income tabs, add custom, edit, delete.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.categoriesTitle),
        actions: [
          IconButton(
            tooltip: L.catAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openSheet(context, state,
                kind: _tabs.index == 0 ? 'expense' : 'income'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: L.catExpenseTab),
            Tab(text: L.catIncomeTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(context, state, 'expense'),
          _list(context, state, 'income'),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, MbAppState state, String kind) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final cats = state.categories.where((c) => c.kind == kind).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Transaction counts per category.
    final counts = <String, int>{};
    for (final t in state.transactions) {
      if (t.categoryId != null) {
        counts[t.categoryId!] = (counts[t.categoryId!] ?? 0) + 1;
      }
    }

    if (cats.isEmpty) {
      return MbEmptyState(emoji: '🗂️', title: L.empty);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final c = cats[i];
        final count = counts[c.id] ?? 0;
        return MbFadeSlideIn(
          index: i,
          child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MbCard(
            onTap: () => _openSheet(context, state, existing: c),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Color(c.color).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(c.icon, style: const TextStyle(fontSize: 21)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(
                        '$count ${L.catTxUsed}',
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  void _openSheet(
    BuildContext context,
    MbAppState state, {
    Category? existing,
    String? kind,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(
        state: state,
        existing: existing,
        kind: kind ?? existing!.kind,
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final MbAppState state;
  final Category? existing;
  final String kind;

  const _CategorySheet({
    required this.state,
    required this.existing,
    required this.kind,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _name = TextEditingController();
  String _icon = '💸';
  int _color = MbPalette.other;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _icon = e.icon;
      _color = e.color;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final L = context.L;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.catNameRequired)));
      return;
    }
    await widget.state.saveCategory(
      id: widget.existing?.id,
      name: name,
      icon: _icon,
      color: _color,
      kind: widget.kind,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.catSaved)));
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final L = context.L;
    final id = widget.existing!.id;
    final state = widget.state;
    // Block first, ask after: custom + unused only.
    final cat = state.catById[id];
    final used = state.transactions.any((t) => t.categoryId == id);
    if (cat == null || cat.isDefault || used) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cat != null && cat.isDefault
            ? L.catDeleteBlock
            : (used ? L.catDeleteBlock : L.catDeleteConfirm))),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.catDeleteConfirm),
        content: Text(L.catDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.cancel)),
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
      await state.tryDeleteCategory(id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? L.catAdd : L.catEdit,
              style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              decoration: InputDecoration(hintText: L.catNameHint),
            ),
            const SizedBox(height: 16),

            Text(L.catIcon,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: GridView.count(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
                scrollDirection: Axis.horizontal,
                children: [
                  for (final i in MbPalette.pickerIcons)
                    GestureDetector(
                      onTap: () => setState(() => _icon = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: _icon == i
                              ? Border.all(color: MbPalette.green, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(i, style: const TextStyle(fontSize: 19)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(L.catColor,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in MbPalette.pickerColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: _color == c
                            ? Border.all(
                                color: scheme.onSurface, width: 3)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
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
                onPressed: _delete,
                child:
                    Text(L.delete, style: TextStyle(color: scheme.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
