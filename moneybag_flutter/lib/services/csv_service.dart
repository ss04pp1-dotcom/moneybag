import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_state.dart';

/// CSV export of every transaction (TRD: Data Export).
///
/// A UTF-8 BOM is prepended so Excel opens Bengali notes correctly.
class MbCsvService {
  final MbAppState state;

  MbCsvService(this.state);

  static const String sep = ',';

  /// Escape one CSV cell (RFC 4180: quote when needed, double the quotes).
  static String esc(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains('"') || s.contains(sep) || s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Build the CSV document from the current state.
  String build() {
    final rows = <String>[
      [
        'date',
        'type',
        'category',
        'note',
        'amount',
        'currency',
      ].map(esc).join(sep),
    ];
    final txs = [...state.transactions]
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final t in txs) {
      final d = t.date.toIso8601String().substring(0, 10);
      rows.add([
        d,
        t.kind,
        state.categoryName(t.categoryId),
        t.note ?? '',
        (t.amountMinor / 100).toStringAsFixed(2),
        'BDT',
      ].map(esc).join(sep));
    }
    final body = rows.join('\r\n');
    return body;
  }

  /// Write to `<documents>/exports/moneybag-YYYYMMDD_HHMM.csv` and share.
  Future<String> exportAndShare() async {
    final csv = build();
    final dir = await getApplicationDocumentsDirectory();
    final exports = Directory(p.join(dir.path, 'exports'));
    if (!await exports.exists()) {
      await exports.create(recursive: true);
    }
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    final file = File(p.join(exports.path, 'moneybag-$stamp.csv'));
    // UTF-8 BOM so Excel renders বাংলা properly.
    await file.writeAsBytes(utf8.encode('\ufeff$csv'), flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'MoneyBag CSV export',
    );
    return file.path;
  }
}
