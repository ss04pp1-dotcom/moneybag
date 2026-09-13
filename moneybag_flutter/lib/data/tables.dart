import 'package:drift/drift.dart';

/// Categories — default 10 + unlimited custom.
///
/// [Categories.color] is an ARGB int; [Categories.icon] is an emoji.
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get icon => text().withDefault(const Constant('💸'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF9AA8A0))();
  TextColumn get kind => text()(); // 'expense' | 'income'
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transactions — expenses and income.
///
/// [Transactions.amountMinor] is in poisha (integer 1/100 ৳) — never a
/// double, so money math is exact.
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // 'expense' | 'income'
  IntColumn get amountMinor => integer()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get note => text().withLength(max: 200).nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => const [];
}

/// Monthly budgets — per category or overall (categoryId null).
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get amountMinor => integer()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Savings goals (piggy bank).
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get icon => text().withDefault(const Constant('🐷'))();
  IntColumn get targetMinor => integer()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  BoolColumn get completed =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Contributions toward goals (positive = deposit, negative = withdrawal).
class Contributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text()();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
