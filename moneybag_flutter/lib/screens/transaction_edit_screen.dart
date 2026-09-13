import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/palette.dart';
import '../data/database.dart';
import '../services/ads_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// v2.2.2: compact label + chip row used by the editor's smart quick-fill
/// suggestions (frequent amounts / recent notes).
class _QuickFillRow extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _QuickFillRow({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

/// Add / edit a transaction.
class TransactionEditScreen extends StatefulWidget {
  final String? txId;
  const TransactionEditScreen({super.key, this.txId});

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  // v2.2.5: the FREE-TEXT category box ("কিসে খরচ হলো?") — typed text
  // becomes the transaction's category; chips are only required when
  // this box is left empty. The note stays a separate optional field.
  final _whatFor = TextEditingController();
  final _noteFocus = FocusNode();
  final _scroll = ScrollController();

  String _kind = 'expense';
  String? _categoryId;
  late DateTime _date;
  bool _busy = false;
  bool _loaded = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrate();
    });
  }

  void _hydrate() {
    if (widget.txId == null || _loaded) return;
    final state = context.read<MbAppState>();
    Transaction? tx;
    for (final t in state.transactions) {
      if (t.id == widget.txId) {
        tx = t;
        break;
      }
    }
    if (tx == null) return;
    _loaded = true;
    _kind = tx.kind;
    _categoryId = tx.categoryId;
    // v2.2.5: when the tx's category is no longer an active pickable chip
    // (deleted or deactivated since), its name goes into the free-text
    // box so the edit round-trips instead of silently dropping it.
    final txCatId = tx.categoryId;
    if (txCatId != null) {
      final cats = state.activeCategoriesOfKind(tx.kind);
      if (!cats.any((c) => c.id == txCatId)) {
        _whatFor.text = state.categoryName(txCatId);
        _categoryId = null;
      }
    }
    _note.text = tx.note ?? '';
    _date = tx.date;
    _amount.text = _fmtNumber(tx.amountMinor / 100);
    if (mounted) setState(() {});
  }

  static String _fmtNumber(num v) {
    var s = v.toStringAsFixed(2);
    if (s.endsWith('.00')) s = s.substring(0, s.length - 3);
    return s;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _whatFor.dispose();
    _noteFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int? get _amountMinor {
    final v = MbFormat.parseAmount(_amount.text);
    if (v == null || v <= 0) return null;
    return (v * 100).round();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ── v2.1: receipt OCR (on-device ML Kit, fully offline) ──────────────
  Future<void> _scanReceipt({required bool fromCamera}) async {
    if (_scanning || _busy) return;
    final L = context.L;
    setState(() => _scanning = true);
    try {
      final shot = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 2400,
        imageQuality: 88,
      );
      if (shot == null) return;

      final recognizer = TextRecognizer();
      try {
        final text =
            await recognizer.processImage(InputImage.fromFilePath(shot.path));

        // Pull every money-looking number (1,250.00 / 350 / ৳120).
        final found = <double>[];
        final re = RegExp(
            r'([0-9০-৯]{1,3}(?:,[0-9০-৯]{3})+(?:\.[0-9০-৯]{1,2})?|[0-9০-৯]+(?:\.[0-9০-৯]{1,2})?)');
        for (final block in text.blocks) {
          for (final line in block.lines) {
            for (final m in re.allMatches(line.text)) {
              // v2.2.0: OCR text may contain Bengali digits — parseAmount
              // normalises them (and the comma groups) before parsing.
              final v = MbFormat.parseAmount(m.group(1)!);
              // Ignore phone-number-scale garbage; receipts stay under 1 crore.
              if (v != null && v >= 1 && v < 10000000) found.add(v);
            }
          }
        }
        final unique = <double>[];
        for (final v in found) {
          if (!unique.contains(v)) unique.add(v);
        }
        unique.sort((a, b) => b.compareTo(a));

        if (!mounted) return;
        if (unique.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(L.ocrNoAmount)));
        } else {
          await _showOcrChips(unique.take(3).toList());
        }
      } finally {
        recognizer.close();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.ocrNoAmount)));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _showOcrChips(List<double> amounts) async {
    final L = context.L;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(L.ocrFound,
                  style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final v in amounts)
                    ActionChip(
                      avatar: Text('৳',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w700)),
                      label: Text(
                        _fmtNumber(v),
                        style: const TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        setState(() => _amount.text = _fmtNumber(v));
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                L.ocrUse,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── v2.1: soft duplicate warning before saving ──────────────────────────
  Future<bool> _confirmDuplicate(int minor) async {
    final L = context.L;
    final state = context.read<MbAppState>();
    final categoryName = state.categoryName(_categoryId);
    final goOn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.dupTitle),
        content: Text(L.dupBody(state.money(minor), categoryName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.dupGoBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.dupSaveAnyway),
          ),
        ],
      ),
    );
    return goOn == true;
  }

  Future<void> _save() async {
    final L = context.L;
    final state = context.read<MbAppState>();
    final minor = _amountMinor;
    if (minor == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L.txAmountRequired)));
      return;
    }
    // v2.2.5 — the user's exact spec:
    //   • box filled  → the typed text IS the category (auto-created),
    //                   chips not needed, note still optional;
    //   • box empty   → a category chip MUST be picked;
    //   • neither     → save blocked (a bare amount with no "what for"
    //                   is exactly what the user does NOT want).
    final typed = _whatFor.text.trim();
    String? categoryId;
    setState(() => _busy = true);
    try {
      if (typed.isNotEmpty) {
        categoryId =
            await state.findOrCreateCategoryByName(typed, _kind);
      } else if (_categoryId != null) {
        categoryId = _categoryId;
      } else {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(L.txCategoryOrNote)));
        }
        return;
      }

      // v2.1: new expense that matches an entry from the same day → soft
      // "save it again?" warning (never blocks intentional double buys).
      if (widget.txId == null && _kind == 'expense') {
        final dup = state.hasSameDayExpense(
          amountMinor: minor,
          categoryId: categoryId,
          date: _date,
        );
        if (dup) {
          final goOn = await _confirmDuplicate(minor);
          if (!goOn) {
            if (mounted) setState(() => _busy = false);
            return;
          }
        }
      }

      await state.saveTransaction(
        id: widget.txId,
        kind: _kind,
        amountMinor: minor,
        categoryId: categoryId,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        date: _date,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Real budget-alert notifications — evaluated against live data right
    // after every write (fires once per threshold crossing).
    unawaited(MbNotifications.instance.evaluateBudgetAlerts(state));
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final L = context.L;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.txDeleteConfirm),
        content: Text(L.txDeleteConfirmBody),
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
    if (ok == true && mounted) {
      final state = context.read<MbAppState>();
      await state.deleteTransaction(widget.txId!);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── v2.2.2: smart quick-fill ─────────────────────────────────────────
  /// Amounts this user records often (last 90 days, same kind; narrowed to
  /// the selected category when one is picked). Count >= 2 so a one-off
  /// purchase never becomes a suggestion.
  List<int> _quickAmounts(MbAppState state) {
    if (widget.txId != null) return const [];
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final counts = <int, int>{};
    final lastAt = <int, DateTime>{};
    for (final t in state.transactions) {
      if (t.kind != _kind) continue;
      if (_categoryId != null && t.categoryId != _categoryId) continue;
      if (t.date.isBefore(cutoff)) continue;
      counts[t.amountMinor] = (counts[t.amountMinor] ?? 0) + 1;
      final prev = lastAt[t.amountMinor];
      if (prev == null || t.date.isAfter(prev)) lastAt[t.amountMinor] = t.date;
    }
    final entries = counts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        if (c != 0) return c;
        return (lastAt[b.key] ?? DateTime(2000))
            .compareTo(lastAt[a.key] ?? DateTime(2000));
      });
    return [for (final e in entries.take(3)) e.key];
  }

  /// Recent free-text entries the user typed (v2.2.5 rules):
  /// • same kind (expense suggestions only for expenses)
  /// • sources: the tx note OR a CUSTOM (non-default) category name —
  ///   both are things the user actually typed in the "what for" box
  /// • only the last 7 days (auto-"delete" after ~a week, as requested)
  /// • max 3, most recently used first, shown only while the box is empty
  List<String> _recentTexts(MbAppState state) {
    if (widget.txId != null) return const [];
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final txs = [...state.transactions]
      ..sort((a, b) {
        var cmp = b.date.compareTo(a.date);
        if (cmp == 0) cmp = b.createdAt.compareTo(a.createdAt);
        return cmp;
      });
    final out = <String>[];
    for (final t in txs) {
      if (t.kind != _kind) continue;
      if (t.date.isBefore(cutoff)) break; // sorted newest first → done
      var s = t.note?.trim() ?? '';
      if (s.isEmpty && t.categoryId != null) {
        final cat = state.catById[t.categoryId];
        if (cat != null && !cat.isDefault && cat.isActive) s = cat.name;
      }
      if (s.isEmpty || out.contains(s)) continue;
      out.add(s);
      if (out.length >= 3) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.txId != null;
    final cats =
        state.activeCategoriesOfKind(_kind == 'expense' ? 'expense' : 'income');
    final quickAmounts = _quickAmounts(state);
    final recentTexts = _recentTexts(state);
    final typedCategory = _whatFor.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? L.txEditTitle
            : (_kind == 'expense' ? L.txAddExpense : L.txAddIncome)),
        actions: [
          if (isEdit)
            IconButton(
              icon: Icon(Icons.delete_rounded, color: scheme.error),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            controller: _scroll,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type toggle
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'expense',
                          label: Text(L.expense),
                          icon: const Icon(Icons.north_east_rounded, size: 17),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text(L.income),
                          icon: const Icon(Icons.south_west_rounded, size: 17),
                        ),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (s) => setState(() {
                        _kind = s.first;
                        _categoryId = null;
                      }),
                    ),
                    const SizedBox(height: 22),

                    // ── v2.2.5: the "what was it for" box — THE category
                    // when filled (user's spec: box upore, taka niche;
                    // likhle category lagbe na, na likhle chip banchate
                    // hobe). ──
                    Text(
                      _kind == 'expense'
                          ? L.txWhatForExpenseLabel
                          : L.txWhatForIncomeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _whatFor,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: L.txWhatForHint,
                        helperText: L.txWhatForHelper,
                        counterText: '',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),

                    // ── v2.2.5: recent typed entries fill the box (not the
                    // note) — the box is what people actually type into.
                    // Max 3, last 7 days, hidden once typing starts. ──
                    if (!isEdit && _whatFor.text.isEmpty && recentTexts.isNotEmpty)
                      _QuickFillRow(
                        label: L.txRecentNotes,
                        children: [
                          for (final n in recentTexts)
                            ActionChip(
                              avatar: Icon(Icons.history_rounded,
                                  size: 14, color: scheme.onSurfaceVariant),
                              label: Text(
                                n.length > 24 ? '${n.substring(0, 22)}…' : n,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'NotoSansBengali'),
                              ),
                              onPressed: () =>
                                  setState(() => _whatFor.text = n),
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // Amount
                    Text(L.amount,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '৳',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: _kind == 'expense'
                                  ? scheme.error
                                  : scheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _amount,
                              autofocus: !isEdit,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              inputFormatters: [
                                // v2.2.2: Bengali digits (০-৯) allowed —
                                // parseAmount normalises them on save, but
                                // the old ASCII-only filter silently ate
                                // every keystroke from a Bangla keyboard.
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^[0-9০-৯]{0,9}(\.[0-9০-৯]{0,2})?$')),
                              ],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: L.txAmountHint,
                                hintStyle: TextStyle(
                                  fontFamily: 'NotoSansBengali',
                                  fontSize: 30,
                                  color: scheme.onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_amountMinor != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          state.money(_amountMinor!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // ── v2.2.2: smart quick-fill — frequent amounts ──
                    // Only for a NEW entry while the amount is still empty,
                    // so the editor stays clean once the user starts typing.
                    if (!isEdit && _amountMinor == null && quickAmounts.isNotEmpty)
                      _QuickFillRow(
                        label: L.txFrequentAmounts,
                        children: [
                          for (final a in quickAmounts)
                            ActionChip(
                              avatar: Text(
                                '৳',
                                style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                              label: Text(
                                state.money(a),
                                style: const TextStyle(
                                    fontFamily: 'NotoSansBengali',
                                    fontWeight: FontWeight.w600),
                              ),
                              onPressed: () =>
                                  setState(() => _amount.text = _fmtNumber(a / 100)),
                            ),
                        ],
                      ),

                    // ── v2.1: receipt scan (expenses only) ──
                    if (_kind == 'expense') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _scanning ? null : () => _scanReceipt(fromCamera: true),
                              icon: const Icon(Icons.document_scanner_rounded,
                                  size: 19),
                              label: Text(L.scanReceipt,
                                  style: const TextStyle(fontSize: 13.5)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _scanning ? null : () => _scanReceipt(fromCamera: false),
                              icon: const Icon(Icons.photo_library_rounded,
                                  size: 19),
                              label: Text(L.photoGallery,
                                  style: const TextStyle(fontSize: 13.5)),
                            ),
                          ),
                        ],
                      ),
                      if (_scanning)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text(L.scanningReceipt,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 22),

                    // Date
                    Text(L.date,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_rounded,
                                color: scheme.primary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              MbFormat.dayLabel(_date,
                                  bangla: state.bangla),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                            const Spacer(),
                            Text(
                              '${_date.year}',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Categories: only MANDATORY when the what-for box
                    // is empty (user's spec). A filled box already IS the
                    // category — picking a chip on top would be redundant.
                    Text(
                      typedCategory
                          ? '${L.category} · ${L.txCategoryOptional}'
                          : '${L.category} · ${_kind == 'expense' ? L.expense : L.income}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in cats)
                          _categoryChip(context, c.id, c.icon, c.name,
                              Color(c.color)),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Note — always OPTIONAL (v2.2.5): the "why/where"
                    // information lives in the category box above now;
                    // this field is for extra details only.
                    Text(L.note,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      focusNode: _noteFocus,
                      maxLines: 2,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: L.noteHint,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Save
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4),
                              )
                            : Text(L.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(
      BuildContext context, String id, String icon, String name, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _categoryId == id;
    return GestureDetector(
      onTap: () => setState(() => _categoryId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 7),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
