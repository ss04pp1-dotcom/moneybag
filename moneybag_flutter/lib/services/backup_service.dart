import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:math' as math;
import 'dart:typed_data' show BytesBuilder;

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';

/// Encrypted local backup service — `moneybag-backup-v1`.
///
/// File layout (binary):
/// ```
/// bytes 0..3   magic "MBBK"
/// byte  4      format version (0x01)
/// bytes 5..20  PBKDF2 salt (16)
/// bytes 21..32 AES-GCM nonce (12)
/// rest         ciphertext || GCM tag (16)
/// ```
/// Key derivation: PBKDF2-HMAC-SHA256, 120 000 iterations → 256-bit key.
/// The passphrase never leaves the device; without it the file is
/// cryptographically unrecoverable.
class MbBackupService {
  static const String formatId = 'moneybag-backup-v1';
  static const List<int> magic = [0x4D, 0x42, 0x42, 0x4B]; // 'MBBK'
  static const int formatVersion = 1;
  static const int pbkdf2Iterations = 120000;

  final MbDatabase db;

  MbBackupService(this.db);

  // ── export ───────────────────────────────────────────────────────────────

  /// v2.2.0: minimum passphrase length enforced HERE, at the choke point.
  ///
  /// The backup screen validated length ≥ 6 on its main path, but the share
  /// fallback (and any future caller) skipped it — a backup encrypted with
  /// an EMPTY passphrase could be created and handed out.
  static const int minPassphraseLength = 6;

  Future<String> createBackup({required String passphrase}) async {
    if (passphrase.trim().length < minPassphraseLength) {
      throw ArgumentError(
          'backup passphrase must be at least $minPassphraseLength characters');
    }
    final payload = await _snapshot();
    final bytes = await encryptBackup(
      jsonEncode(payload),
      passphrase,
    );
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory(p.join(dir.path, 'backups'));
    if (!await backups.exists()) {
      await backups.create(recursive: true);
    }
    final stamp = _stamp(DateTime.now());
    final file = File(p.join(backups.path, 'moneybag-$stamp.mbbak'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Encrypt [json] into the `moneybag-backup-v1` binary envelope.
  static Future<List<int>> encryptBackup(
      String json, String passphrase) async {
    final clearText = utf8.encode(json);
    final salt = newSalt();
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(clearText, secretKey: key);

    final out = BytesBuilder();
    out.add(magic);
    out.addByte(formatVersion);
    out.add(salt);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  Future<Map<String, dynamic>> _snapshot() async {
    final cats = await db.allCategories();
    final txs = await db.allTransactions();
    // v2.2.5 fix: snapshot ALL budgets (active AND deactivated). The old
    // activeBudgets()-only read silently dropped any deactivated budget
    // from every backup — restore permanently lost it.
    final budgets = await db.allBudgets();
    final goals = await db.allGoals();
    final contribs = await db.allContributions();
    return {
      'format': formatId,
      'appVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {
        'categories': [for (final c in cats) c.toJson()],
        'transactions': [for (final t in txs) t.toJson()],
        'budgets': [for (final b in budgets) b.toJson()],
        'goals': [for (final g in goals) g.toJson()],
        'contributions': [for (final c in contribs) c.toJson()],
      },
    };
  }

  static String _stamp(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  static List<int> newSalt() {
    final rng = math.Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(256));
  }

  // ── restore ──────────────────────────────────────────────────────────────

  /// Parse + decrypt a .mbbak file. Throws [MbBackupException] on any
  /// validation failure (wrong passphrase, corrupt file, bad format).
  Future<Map<String, dynamic>> readBackup({
    required String passphrase,
    required List<int> bytes,
  }) =>
      decryptBackup(passphrase: passphrase, bytes: bytes);

  /// Decrypt + validate the `moneybag-backup-v1` binary envelope.
  static Future<Map<String, dynamic>> decryptBackup({
    required String passphrase,
    required List<int> bytes,
  }) async {
    if (bytes.length < 5 + 16 + 12 + 16) {
      throw const MbBackupException(MbBackupError.corrupt);
    }
    if (bytes[0] != magic[0] ||
        bytes[1] != magic[1] ||
        bytes[2] != magic[2] ||
        bytes[3] != magic[3]) {
      throw const MbBackupException(MbBackupError.invalid);
    }
    if (bytes[4] != formatVersion) {
      throw const MbBackupException(MbBackupError.invalid);
    }
    final salt = bytes.sublist(5, 21);
    final nonce = bytes.sublist(21, 33);
    final cipherAndTag = bytes.sublist(33);
    if (cipherAndTag.length < 16) {
      throw const MbBackupException(MbBackupError.corrupt);
    }
    final cipherText = cipherAndTag.sublist(0, cipherAndTag.length - 16);
    final mac = cipherAndTag.sublist(cipherAndTag.length - 16);

    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final aes = AesGcm.with256bits();
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    List<int> clear;
    try {
      clear = await aes.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const MbBackupException(MbBackupError.wrongPassphrase);
    } catch (_) {
      throw const MbBackupException(MbBackupError.corrupt);
    }
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } catch (_) {
      throw const MbBackupException(MbBackupError.corrupt);
    }
    if (payload['format'] != formatId ||
        payload['data'] is! Map<String, dynamic>) {
      throw const MbBackupException(MbBackupError.invalid);
    }
    return payload;
  }

  /// Apply a validated backup payload to the database.
  Future<MbRestoreStats> restore(
    Map<String, dynamic> payload, {
    required bool replace,
  }) async {
    final data = payload['data'] as Map<String, dynamic>;
    final cats = _readList(data, 'categories');
    final txs = _readList(data, 'transactions');
    final buds = _readList(data, 'budgets');
    final goals = _readList(data, 'goals');
    final contribs = _readList(data, 'contributions');

    final catCompanions = [
      for (final c in cats)
        CategoriesCompanion.insert(
          id: _s(c, 'id'),
          name: _s(c, 'name'),
          kind: _s(c, 'kind'),
          icon: Value(_s(c, 'icon')),
          color: Value(_i(c, 'color')),
          isDefault: Value(_b(c, 'isDefault')),
          // v2.2.5 hardening: `?? false` made a MISSING key restore as
          // INACTIVE — every pick-a-category UI in the app would then be
          // blank ("budget e kono catagory nai"). The column's real
          // default is true; honour it when the key is absent.
          isActive: Value(_bOrTrue(c, 'isActive')),
          sortOrder: Value(_i(c, 'sortOrder')),
        )
    ];
    final txCompanions = [
      for (final t in txs)
        TransactionsCompanion.insert(
          id: _s(t, 'id'),
          kind: _s(t, 'kind'),
          amountMinor: _i(t, 'amountMinor'),
          date: _dt(t, 'date'),
          categoryId: Value(_nullableS(t, 'categoryId')),
          note: Value(_nullableS(t, 'note')),
          createdAt: Value(_dt(t, 'createdAt')),
          updatedAt: Value(_dt(t, 'updatedAt')),
        )
    ];
    final budCompanions = [
      for (final b in buds)
        BudgetsCompanion.insert(
          id: _s(b, 'id'),
          amountMinor: _i(b, 'amountMinor'),
          categoryId: Value(_nullableS(b, 'categoryId')),
          rollover: Value(_b(b, 'rollover')),
          // v2.2.5 hardening: same class of bug — a missing 'active' key
          // restored budgets as invisible (active=false).
          active: Value(_bOrTrue(b, 'active')),
          createdAt: Value(_dt(b, 'createdAt')),
        )
    ];
    final goalCompanions = [
      for (final g in goals)
        GoalsCompanion.insert(
          id: _s(g, 'id'),
          name: _s(g, 'name'),
          targetMinor: _i(g, 'targetMinor'),
          icon: Value(_s(g, 'icon')),
          targetDate: Value(_nullableDt(g, 'targetDate')),
          completed: Value(_b(g, 'completed')),
          createdAt: Value(_dt(g, 'createdAt')),
        )
    ];
    final contribCompanions = [
      for (final c in contribs)
        ContributionsCompanion.insert(
          id: _s(c, 'id'),
          goalId: _s(c, 'goalId'),
          amountMinor: _i(c, 'amountMinor'),
          date: _dt(c, 'date'),
          note: Value(_nullableS(c, 'note')),
          createdAt: Value(_dt(c, 'createdAt')),
        )
    ];

    // v2.2.5 honesty fix: the payload length overstates what actually
    // landed — restoreRows uses insertOrIgnore, which silently skips rows
    // whose ids already exist. Count the tables for real instead:
    //   • replace → report what the database now holds;
    //   • merge   → report how many NEW rows actually landed (after−before).
    final before = replace ? null : await db.countsAll();
    await db.restoreRows(
      cats: catCompanions,
      txs: txCompanions,
      buds: budCompanions,
      goalRows: goalCompanions,
      contribs: contribCompanions,
      replace: replace,
    );
    final after = await db.countsAll();

    if (replace) {
      return MbRestoreStats(
        categories: after.categories,
        transactions: after.transactions,
        budgets: after.budgets,
        goals: after.goals,
        contributions: after.contributions,
        replaced: true,
      );
    }
    final b = before!;
    int delta(int x, int y) => math.max(0, x - y);
    return MbRestoreStats(
      categories: delta(after.categories, b.categories),
      transactions: delta(after.transactions, b.transactions),
      budgets: delta(after.budgets, b.budgets),
      goals: delta(after.goals, b.goals),
      contributions: delta(after.contributions, b.contributions),
      replaced: false,
    );
  }

  /// Merge-restore: keeps existing rows, adds backup rows (same ids skip).
  Future<MbRestoreStats> merge(Map<String, dynamic> payload) =>
      restore(payload, replace: false);

  /// Replace-restore: wipes current data first.
  Future<MbRestoreStats> replaceAll(Map<String, dynamic> payload) =>
      restore(payload, replace: true);
}

enum MbBackupError { wrongPassphrase, invalid, corrupt }

class MbBackupException implements Exception {
  final MbBackupError error;
  const MbBackupException(this.error);

  @override
  String toString() => 'MbBackupException: $error';
}

class MbRestoreStats {
  final int categories;
  final int transactions;
  final int budgets;
  final int goals;
  final int contributions;
  final bool replaced;

  const MbRestoreStats({
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.goals,
    required this.contributions,
    required this.replaced,
  });
}

// ── JSON row helpers (defensive reads) ─────────────────────────────────────

List<Map<String, dynamic>> _readList(Map<String, dynamic> map, String key) {
  final v = map[key];
  if (v is List) {
    return [
      for (final e in v)
        if (e is Map) e.cast<String, dynamic>(),
    ];
  }
  return const [];
}

String _s(Map<String, dynamic> m, String k) => m[k]?.toString() ?? '';
String? _nullableS(Map<String, dynamic> m, String k) => m[k]?.toString();
int _i(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? 0;
  return 0;
}
bool _b(Map<String, dynamic> m, String k) => m[k] == true || m[k] == 'true' || m[k] == 1;

/// v2.2.5: booleans whose COLUMN default is true (categories.isActive,
/// budgets.active) — a missing key in an older/hand-made backup must not
/// resurrect them as false (blank pickers / invisible budgets).
bool _bOrTrue(Map<String, dynamic> m, String k) {
  final v = m[k];
  return v == null ? true : (v == true || v == 'true' || v == 1);
}
DateTime _dt(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.fromMillisecondsSinceEpoch(0);
}
DateTime? _nullableDt(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}
