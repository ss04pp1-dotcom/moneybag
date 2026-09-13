import '../core/palette.dart';

/// The 10 default categories seeded on first launch (TRD: Data Model).
///
/// Ids are stable strings so budgets/transactions survive backup/restore.
const List<(String, String, String, int, String)> kDefaultCategories = [
  // (id, name, icon, color, kind)
  ('food', 'খাবার ও চা', '🍛', MbPalette.food, 'expense'),
  ('transport', 'যাতায়াত', '🚌', MbPalette.transport, 'expense'),
  ('bills', 'বিল ও ইউটিলিটি', '💡', MbPalette.bills, 'expense'),
  ('groceries', 'বাজার', '🥬', MbPalette.groceries, 'expense'),
  ('shopping', 'শপিং', '🛍️', MbPalette.shopping, 'expense'),
  ('entertainment', 'বিনোদন', '🎬', MbPalette.entertainment, 'expense'),
  ('health', 'স্বাস্থ্য', '💊', MbPalette.health, 'expense'),
  ('education', 'শিক্ষা', '📚', MbPalette.education, 'expense'),
  ('personal', 'ব্যক্তিগত', '👤', MbPalette.personal, 'expense'),
  ('salary', 'বেতন', '💰', MbPalette.salary, 'income'),
];

/// English names for the default categories (used when UI language is en).
const Map<String, String> kDefaultCategoryNamesEn = {
  'food': 'Food & Tea',
  'transport': 'Transport',
  'bills': 'Bills & Utilities',
  'groceries': 'Groceries',
  'shopping': 'Shopping',
  'entertainment': 'Entertainment',
  'health': 'Health',
  'education': 'Education',
  'personal': 'Personal',
  'salary': 'Salary',
};

/// Display name of a default category for the given language.
String defaultCategoryName(String id, {bool bangla = true}) {
  if (bangla) {
    for (final c in kDefaultCategories) {
      if (c.$1 == id) return c.$2;
    }
    return id;
  }
  return kDefaultCategoryNamesEn[id] ?? id;
}
