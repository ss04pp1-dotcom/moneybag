import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils.dart';
import 'defaults.dart';
import 'tables.dart';

part 'database.g.dart';

/// MoneyBag local database — single SQLite file, local-first, offline-first.
///
/// Schema v1 (initial release). Migrations follow the TRD versioned-migration
/// strategy: every schema change bumps [schemaVersion] and adds a step.
@DriftDatabase(tables: [
  Categories,
  Transactions,
  Budgets,
  Goals,
  Contributions,
])
class MbDatabase extends _$MbDatabase {
  MbDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          // v1 is the first released schema — nothing to upgrade yet.
        },
      );

  Future<void> _seedDefaults() async {
    await batch((b) {
      b.insertAll(
        categories,
        [
          for (final (i, c) in kDefaultCategories.indexed)
            CategoriesCompanion.insert(
              id: c.$1,
              name: c.$2,
              icon: Value(c.$3),
              color: Value(c.$4),
              kind: c.$5,
              isDefault: const Value(true),
              sortOrder: Value(i),
            ),
        ],
      );
    });
  }

  /// v2.2.3 self-heal: guarantees the expense categories exist.
  ///
  /// Real-device report: the budget sheet's category chips were empty (and
  /// the tx editor followed) when the categories table ended up without a
  /// single ACTIVE expense row — restored backups, manual deletes or a
  /// broken first-run seed all lead there, and every "pick a category" UI
  /// in the app silently goes blank. Re-inserts the stable-id defaults
  /// (insertOnConflictUpdate → user-edited names/icons are preserved).
  Future<void> ensureDefaultCategories() async {
    final activeExpense = await (select(categories)
          ..where((c) => c.kind.equals('expense') & c.isActive.equals(true)))
        .get();
    if (activeExpense.isNotEmpty) return;
    await batch((b) {
      for (final (i, c) in kDefaultCategories.indexed) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            id: c.$1,
            name: c.$2,
            icon: Value(c.$3),
            color: Value(c.$4),
            kind: c.$5,
            isDefault: const Value(true),
            sortOrder: Value(i),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    // v2.2.5: rows with the same stable ids can exist as INACTIVE (a
    // restore of an odd backup, a manual edit). insertOrIgnore SKIPS
    // those rows, so the re-seed above is a no-op and every picker stays
    // blank. Reactivate them explicitly — the defaults are always meant
    // to be pickable.
    final ids = [for (final c in kDefaultCategories) c.$1];
    await (update(categories)
          ..where((c) => c.id.isIn(ids) & c.isActive.equals(false)))
        .write(const CategoriesCompanion(
      isActive: Value(true),
    ));
  }

  // ── queries (thin; heavy math lives in the calc engine) ─────────────────

  Future<List<Category>> allCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  /// Categories filtered for a tx kind (expense / income).
  Future<List<Category>> categoriesOfKind(String kind,
      {bool includeInactive = false}) {
    final q = select(categories)
      ..where((c) => c.kind.equals(kind))
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    if (!includeInactive) {
      q.where((c) => c.isActive.equals(true));
    }
    return q.get();
  }

  Future<int> transactionCountForCategory(String categoryId) async {
    final count = countAll();
    final query = selectOnly(transactions)
      ..addColumns([count])
      ..where(transactions.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> upsertCategory(CategoriesCompanion entry) =>
      into(categories).insertOnConflictUpdate(entry);

  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  Future<List<Transaction>> allTransactions() =>
      (select(transactions)..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]))
          .get();

  Future<Transaction?> transactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertTransaction(TransactionsCompanion entry) =>
      into(transactions).insertOnConflictUpdate(entry);

  Future<int> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<List<Budget>> activeBudgets() =>
      (select(budgets)..where((b) => b.active.equals(true))).get();

  Future<void> upsertBudget(BudgetsCompanion entry) =>
      into(budgets).insertOnConflictUpdate(entry);

  Future<int> deleteBudget(String id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();

  Future<List<Goal>> allGoals() =>
      (select(goals)..orderBy([(g) => OrderingTerm.desc(g.createdAt)])).get();

  Future<Goal?> goalById(String id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<void> upsertGoal(GoalsCompanion entry) =>
      into(goals).insertOnConflictUpdate(entry);

  Future<int> deleteGoal(String id) async {
    final n = await (delete(contributions)
          ..where((c) => c.goalId.equals(id)))
        .go();
    return n +
        await (delete(goals)..where((g) => g.id.equals(id))).go();
  }

  Future<List<Contribution>> contributionsForGoal(String goalId) =>
      (select(contributions)
            ..where((c) => c.goalId.equals(goalId))
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .get();

  Future<List<Contribution>> allContributions() =>
      (select(contributions)..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .get();

  Future<int> insertContribution(ContributionsCompanion entry) =>
      into(contributions).insert(entry);

  Future<int> deleteContribution(String id) =>
      (delete(contributions)..where((c) => c.id.equals(id))).go();

  /// Wipe all financial data (categories re-seeded) — used by reset & replace
  /// restore.
  Future<void> wipeAll() async {
    await transaction(() async {
      await delete(contributions).go();
      await delete(goals).go();
      await delete(budgets).go();
      await delete(transactions).go();
      await delete(categories).go();
    });
    await _seedDefaults();
  }

  /// Raw row inserts used by backup restore (bypass companions' defaults).
  Future<void> restoreRows({
    required List<CategoriesCompanion> cats,
    required List<TransactionsCompanion> txs,
    required List<BudgetsCompanion> buds,
    required List<GoalsCompanion> goalRows,
    required List<ContributionsCompanion> contribs,
    bool replace = false,
  }) async {
    await transaction(() async {
      if (replace) {
        await delete(contributions).go();
        await delete(goals).go();
        await delete(budgets).go();
        await delete(transactions).go();
        await delete(categories).go();
      }
      if (cats.isNotEmpty) await batch((b) => b.insertAll(categories, cats, mode: InsertMode.insertOrIgnore));
      if (txs.isNotEmpty) await batch((b) => b.insertAll(transactions, txs, mode: InsertMode.insertOrIgnore));
      if (buds.isNotEmpty) await batch((b) => b.insertAll(budgets, buds, mode: InsertMode.insertOrIgnore));
      if (goalRows.isNotEmpty) {
        await batch((b) => b.insertAll(goals, goalRows, mode: InsertMode.insertOrIgnore));
      }
      if (contribs.isNotEmpty) {
        await batch((b) => b.insertAll(contributions, contribs, mode: InsertMode.insertOrIgnore));
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'moneybag.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Convenience: new ids for app-generated rows.
abstract final class MbIds {
  static String newId() => MbUtils.uuid();
}
