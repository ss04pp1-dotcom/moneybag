/// Money & date formatting for MoneyBag — BDT (৳), Bengali-first.
///
/// All monetary amounts are stored as integers in poisha (1/100 of a taka)
/// so no float rounding ever occurs. This module is the ONLY place that
/// converts an amount into a user-visible string.
library;

/// Bengali digit mapping: 0123456789 → ০১২৩৪৫৬৭৮৯
const List<String> _bnDigits = <String>[
  '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯',
];

/// Number formatting + ৳ currency presentation.
abstract final class MbFormat {
  /// `12000` → `"12,000"` (western grouping) or `"1,20,000"` (lakh/crore
  /// grouping, used in Bangladesh when Bengali numerals are on).
  static String groupDigits(int value, {required bool lakhStyle}) {
    final neg = value < 0;
    final digits = value.abs().toString();
    final out = lakhStyle ? _groupLakh(digits) : _group3(digits);
    return neg ? '-$out' : out;
  }

  /// Bangladeshi/Indian grouping: last 3 digits together, then groups of 2.
  /// `1234567` → `12,34,567` · `10000000` → `1,00,00,000`
  static String _groupLakh(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    final rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    var i = rest.length;
    while (i > 0) {
      final start = i - 2 < 0 ? 0 : i - 2;
      parts.insert(0, rest.substring(start, i));
      i -= 2;
    }
    return '${parts.join(',')},$last3';
  }

  static String _group3(String digits) {
    final buf = StringBuffer();
    final n = digits.length;
    for (var i = 0; i < n; i++) {
      buf.write(digits[i]);
      final remain = n - 1 - i;
      if (remain > 0 && remain % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  /// Convert ASCII digits in [text] to Bengali digits.
  static String toBnDigits(String text) {
    var out = text;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll('$i', _bnDigits[i]);
    }
    return out;
  }

  /// v2.2.0: the INVERSE mapping — Bengali digits in [text] back to ASCII.
  ///
  /// The app is Bengali-first and renders ৳৫০০ everywhere, but every money
  /// field parsed input with a plain `double.tryParse`/`int.tryParse`, so a
  /// user who types ৫০০ got a silent "amount required" error. Run user
  /// input through this before parsing.
  static String toEnDigits(String text) {
    var out = text;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(_bnDigits[i], '$i');
    }
    return out;
  }

  /// v2.2.0: parse a user-typed money amount — accepts Bengali OR ASCII
  /// digits, comma group separators and an optional ৳ prefix.
  /// Returns null when the text is not a valid amount.
  static double? parseAmount(String raw) {
    var s = toEnDigits(raw.trim());
    if (s.startsWith('৳')) s = s.substring(1).trim();
    s = s.replaceAll(',', '');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  /// Full money string with the ৳ sign.
  ///
  /// [bengaliDigits]: render numerals in Bengali (৳১,২৩৪) — the app default.
  /// Decimals are shown only when the poisha part is non-zero (৳250 not
  /// ৳250.00; ৳250.50 when poisha exists).
  static String money(
    int minor, {
    bool bengaliDigits = true,
    bool sign = false,
  }) {
    final neg = minor < 0;
    final abs = minor.abs();
    final taka = abs ~/ 100;
    final poisha = abs % 100;
    final lakhStyle = bengaliDigits;
    var digits = groupDigits(taka, lakhStyle: lakhStyle);
    if (poisha != 0) {
      final p = poisha.toString().padLeft(2, '0');
      digits = '$digits.$p';
    }
    if (bengaliDigits) digits = toBnDigits(digits);
    final prefix = neg ? '-৳' : (sign ? '+৳' : '৳');
    return '$prefix$digits';
  }

  /// Compact display for charts / chips: ৳1.2k / ৳3.5L / ৳1.2Cr.
  /// v2.2.0: unit spacing made consistent ("৳1.2কোটি" previously had no
  /// space while "৳3.5 লাখ" did). 'k' stays Latin — it is the common usage
  /// even in Bengali contexts.
  static String moneyCompact(int minor, {bool bengaliDigits = true}) {
    final taka = minor.abs() / 100;
    String core;
    if (taka >= 10000000) {
      core =
          '${_trim(taka / 10000000)} ${bengaliDigits ? 'কোটি' : 'Cr'}';
    } else if (taka >= 100000) {
      core = '${_trim(taka / 100000)} ${bengaliDigits ? 'লাখ' : 'L'}';
    } else if (taka >= 1000) {
      core = '${_trim(taka / 1000)}k';
    } else {
      core = _trim(taka);
    }
    final neg = minor < 0;
    final body = bengaliDigits ? toBnDigits(core) : core;
    return '${neg ? '-' : ''}৳$body';
  }

  static String _trim(num v) {
    var s = v.toStringAsFixed(1);
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return s;
  }

  /// Percent as integer string (Bengali digits optional). `87.4` → `৮৭%`.
  static String percent(num v, {bool bengaliDigits = true}) {
    final p = v.isFinite ? v.round() : 0;
    final s = p.toString();
    return bengaliDigits ? '${toBnDigits(s)}%' : '$s%';
  }

  /// Bengali month names (Gregorian, as used in Bangladesh).
  static const List<String> bnMonths = <String>[
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
  ];

  static const List<String> enMonths = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Month label for headers: `সেপ্টেম্বর ২০২৫` / `Sep 2025`.
  static String monthLabel(int year, int month, {bool bangla = true}) {
    final names = bangla ? bnMonths : enMonths;
    final y = bangla ? toBnDigits('$year') : '$year';
    return '${names[month - 1]} $y';
  }

  /// Bengali weekday names (short).
  static const List<String> bnWeekdays = <String>[
    'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি',
  ];

  static const List<String> enWeekdays = <String>[
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  /// Day label: `১১ সেপ্টেম্বর` / `11 Sep`.
  static String dayLabel(DateTime d, {bool bangla = true}) {
    final names = bangla ? bnMonths : enMonths;
    final day = bangla ? toBnDigits('${d.day}') : '${d.day}';
    return '$day ${names[d.month - 1]}';
  }

  /// Group header: `আজ` / `গতকাল` / `১১ সেপ্টেম্বর, বৃহঃ`.
  static String dayGroupLabel(DateTime day, DateTime today, {bool bangla = true}) {
    final a = DateTime(day.year, day.month, day.day);
    final b = DateTime(today.year, today.month, today.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return bangla ? 'আজ' : 'Today';
    if (diff == 1) return bangla ? 'গতকাল' : 'Yesterday';
    final wd = (bangla ? bnWeekdays : enWeekdays)[day.weekday % 7];
    final base = dayLabel(day, bangla: bangla);
    return bangla ? '$base, $wd' : '$wd, $base';
  }

  /// Greeting by hour of day.
  static String greeting(DateTime now, {bool bangla = true}) {
    final h = now.hour;
    if (bangla) {
      if (h < 5) return 'শুভ রাত্রি';
      if (h < 12) return 'শুভ সকাল';
      if (h < 16) return 'শুভ দুপুর';
      if (h < 19) return 'শুভ বিকাল';
      return 'শুভ সন্ধ্যা';
    }
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 16) return 'Good afternoon';
    if (h < 19) return 'Good evening';
    return 'Good evening';
  }

  /// Short relative age of a past event: `আজ` / `৭ দিন আগে` / `2 days ago`.
  static String relativeDays(int days, {bool bangla = true}) {
    if (days <= 0) return bangla ? 'আজ' : 'today';
    final d = bangla ? toBnDigits('$days') : '$days';
    return bangla ? '$d দিন আগে' : '$days day${days == 1 ? '' : 's'} ago';
  }
}
