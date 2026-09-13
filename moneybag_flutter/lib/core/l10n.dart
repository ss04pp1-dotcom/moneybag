import 'package:flutter/material.dart';

/// Bengali-first localization. Every user-visible string in the app flows
/// through [L] so the entire UI can switch between বাংলা and English.
///
/// `L` is looked up via an inherited dependency registered in `app.dart`,
/// so widgets simply call `context.L.xxx`.

enum MbLanguage { bangla, english }

/// All UI strings, keyed by language. Access via [MbStrings.of]/context.L.
abstract final class L {
  static MbStrings of(BuildContext context) => MbInherited.of(context);

  static Widget wrapper({
    required MbLanguage language,
    required Widget child,
  }) {
    return MbInherited(strings: stringsFor(language), child: child);
  }

  static MbStrings stringsFor(MbLanguage lang) =>
      lang == MbLanguage.bangla ? _bn : _en;

  static const MbStrings _bn = _BnStrings();
  static const MbStrings _en = _EnStrings();
}

class MbInherited extends InheritedWidget {
  const MbInherited({
    super.key,
    required this.strings,
    required super.child,
  });

  final MbStrings strings;

  static MbStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MbInherited>()!.strings;

  @override
  bool updateShouldNotify(MbInherited oldWidget) =>
      oldWidget.strings != strings;
}

/// Concrete string tables. Fields are nullable; every table MUST define all
/// keys, missing ones fall back to the other language at lookup time.
abstract class MbStrings {
  const MbStrings();

  // ── global ──
  String get appName;
  String get tagline;
  String get save;
  String get cancel;
  String get delete;
  String get edit;
  String get done;
  String get ok;
  String get next;
  String get back;
  String get skip;
  String get start;
  String get continueLabel;
  String get confirm;
  String get all;
  String get expense;
  String get income;
  String get today;
  String get searchHint;
  String get error;
  String get retry;
  String get empty;
  String get seeAll;
  String get amount;
  String get note;
  String get noteHint;
  String get date;
  String get category;
  String get select;
  String get none;
  String get yes;
  String get no;

  // ── onboarding ──
  String get ob1Title;
  String get ob1Body;
  String get ob2Title;
  String get ob2Body;
  String get ob3Title;
  String get ob3Body;
  String get ob4Title;
  String get ob4Body;
  String get ob5Title;
  String get ob5Body;
  String get ob6Title;
  String get ob6Body;

  // ── profile setup ──
  String get setupTitle;
  String get setupSubtitle;
  String get yourName;
  String get yourNameHint;
  String get monthlyIncome;
  String get monthlyIncomeHint;
  String get monthlyIncomeHelp;
  String get languageLabel;
  String get appearance;
  String get darkTheme;
  String get lightTheme;
  String get setupCta;

  // ── nav ──
  String get navHome;
  String get navTransactions;
  String get navBudget;
  String get navProfile;

  // ── dashboard ──
  String get dashMonthIncome;
  String get dashMonthExpense;
  String get dashNetSavings;
  String get dashSavingsRate;
  String get dashBudgetTitle;
  String get dashBudgetLeft;
  String get dashBudgetOver;
  String get dashBudgetNone;
  String get dashRecent;
  String get dashTopCategories;
  String get dashThisMonth;
  String get noTransactions;
  String get noTransactionsHint;
  String get addFirstTransaction;
  String get setBudgetCta;

  // ── dashboard: floating “আজকের হিসাব” card (restored 1.3.x) ──
  String get todaySummaryTitle;
  String get todaySummaryNoTx;
  String get todaySummaryNoTxHint;
  String get todayAdd;
  String get todayNet;
  String todaySavedToday(String amount);
  String get todayOverspent;
  String todayExpenseOnly(String amount);
  // v2.2.2: budget-pace daily allowance on the today card.
  String todaySafeToSpend(String amount);

  // ── transactions ──
  String get txTitle;
  String get txSearchHint;
  String get txFiltersAll;
  String get txFiltersExpense;
  String get txFiltersIncome;
  String get txDayTotal;
  String get txDeleted;
  String get txEmptyFiltered;
  String get txCountOne;
  String txCountMany(int n);

  // ── add/edit transaction ──
  String get txAddExpense;
  String get txAddIncome;
  String get txEditTitle;
  String get txAmountHint;
  String get txSelectCategory;
  String get txDeleteConfirm;
  String get txDeleteConfirmBody;
  String get txSaved;
  String get txAmountRequired;
  String get txNoteFor;
  // v2.2.2: smart quick-fill chips in the editor.
  String get txFrequentAmounts;
  String get txRecentNotes;

  // v2.2.3 — category OR note requirement
  String get txCategoryOrNote;

  // v2.2.5 — free-text category box: "what was it for" IS the category
  // (typed text saves as a category; chips only needed when box is empty).
  String get txWhatForExpenseLabel;
  String get txWhatForIncomeLabel;
  String get txWhatForHint;
  String get txWhatForHelper;
  String get txCategoryOptional;

  // ── budget ──
  String get budgetTitle;
  String get budgetOverall;
  String get budgetOverallCard;
  String get budgetByCategory;
  String get budgetSpent;
  String get budgetOf;
  String get budgetLeftShort;
  String get budgetOverShort;
  String get budgetSet;
  String get budgetEdit;
  String get budgetEmpty;
  String get budgetEmptyHint;
  // v2.2.1: distinct hints so the two empty budget cards (overall vs
  // per-category) no longer look like a duplicated card.
  String get budgetOverallHint;
  String get budgetCategoryHint;
  String get budgetAddFirst;
  String get budgetLimitLabel;
  String get budgetLimitHint;
  String get budgetForLabel;
  String get budgetOverallOption;
  String get budgetRollover;
  String get budgetRolloverHint;
  String get budgetAlertLabel;
  String get budgetAlertHelp;
  String get budgetOverBody;
  String get budgetNearBody;
  String get budgetSaved;
  String get budgetDelete;

  // v2.2.3 — budget sheet category fallback
  String get budgetNoCategories;
  String get budgetManageCategories;

  // ── analytics ──
  String get analyticsTitle;
  String get anThisMonth;
  String get anLastMonth;
  String get anThisYear;
  String get anSpendingByCategory;
  String get anWeeklySpend;
  String get anMonthlyTrend;
  String get anIncomeVsExpense;
  String get anTopSpending;
  String get anInsights;
  String get anNoData;
  String get anNoDataHint;
  String get anShare;

  // ── savings / goals ──
  String get savingsTitle;
  String get savingsTotalSaved;
  String get savingsMonthNet;
  String get savingsInGoals;
  String goalsCountMany(int n);
  String get goalsTitle;
  String get goalsActive;
  String get goalsEmpty;
  String get goalsEmptyHint;
  String get goalAdd;
  String get goalEdit;
  String get goalName;
  String get goalNameHint;
  String get goalTarget;
  String get goalTargetHint;
  String get goalTargetDate;
  String get goalTargetDateOptional;
  String get goalTargetReached;
  String get goalProgressOf;
  String get goalContribute;
  String get goalContributeTitle;
  String get goalWithdraw;
  String get goalHistory;
  String get goalNoHistory;
  String get goalSavedOn;
  String get goalDelete;
  String get goalDeleteBody;
  String get goalMarkComplete;
  String get goalCompletedBadge;
  String get goalContributionAdded;
  String get goalNeedMore;
  String get goalNoTargetDate;
  String get goalDaysLeft;
  String get goalOverdue;

  // ── categories ──
  String get categoriesTitle;
  String get catExpenseTab;
  String get catIncomeTab;
  String get catAdd;
  String get catEdit;
  String get catName;
  String get catNameHint;
  String get catIcon;
  String get catColor;
  String get catTxUsed;
  String get catDeleteConfirm;
  String get catDeleteBody;
  String get catDeleteBlock;
  String get catSaved;
  String get catNameRequired;

  // ── profile / settings ──
  String get profileTitle;
  String get settingsSectionGeneral;
  String get settingsLanguage;
  String get settingsBangla;
  String get settingsEnglish;
  String get settingsTheme;
  String get settingsDark;
  String get settingsLight;
  String get settingsSystem;
  String get settingsBnDigits;
  String get settingsBnDigitsHelp;
  String get settingsSectionAlerts;
  String get settingsBudgetAlerts;
  String get settingsBudgetAlertsHelp;
  String get settingsWeeklySummary;
  String get settingsWeeklySummaryHelp;
  String get settingsSectionData;
  String get settingsExportCsv;
  String get settingsExportCsvHelp;
  String get settingsBackup;
  String get settingsBackupHelp;
  String get settingsRestore;
  String get settingsRestoreHelp;
  String get settingsCategories;
  String get settingsCategoriesHelp;
  String get settingsSectionAbout;
  String get settingsPrivacyTitle;
  String get settingsPrivacyBody;
  String get settingsVersion;
  String get settingsReset;
  String get settingsResetConfirm;
  String get settingsResetBody;
  String get settingsResetDone;
  String get settingsExported;
  String get settingsExportFail;

  // ── backup ──
  String get backupTitle;
  String get backupIntro;
  String get backupPassphrase;
  String get backupPassphraseHint;
  String get backupPassphraseRepeat;
  String get backupCreate;
  String get backupCreating;
  String get backupCreatedTitle;
  String get backupCreatedBody;
  String get backupShare;
  String get backupDone;
  String get backupPassShort;
  String get backupPassMismatch;
  String get backupRestoreTitle;
  String get backupRestoreIntro;
  String get backupPickFile;
  String get backupDecrypting;
  String get backupWrongPass;
  String get backupInvalidFile;
  String get backupCorruptFile;
  String get backupRestoreMode;
  String get backupModeReplace;
  String get backupModeReplaceHelp;
  String get backupModeMerge;
  String get backupModeMergeHelp;
  String get backupRestoreCta;
  String get backupRestoredTitle;
  String get backupRestoredBody;
  String get backupFormatNote;
  String get backupStats;

  // ── notifications (in-app) ──
  String get notifBudgetTitle;
  String get notifWeeklyTitle;
  String get notifBudgetBody;
  String get notifWeeklyBody;

  // ── insights ──
  String get insTopCategoryT;
  String insTopCategoryB(String cat, String amt);
  String get insMoMUpT;
  String insMoMB(double pct);
  String get insMoMDownT;
  String insMoMDownB(double pct);
  String get insSavingsRateT;
  String insSavingsRateB(double pct);
  String get insDailyAvgT;
  String insDailyAvgB(String amt);
  String get insProjectedT;
  String insProjectedB(String amt);
  String get insBudgetWarnT;
  String insBudgetWarnB(String cat);
  String get insBudgetOverT;
  String insBudgetOverB(String cat);
  String get insBiggestT;
  String insBiggestB(String amt, String cat);
  String get insNoSpendT;
  String insNoSpendB(int n);
  String get insGreetingT;
  String get insGreetingB;
  // v2.2.2: single category far above its trailing average.
  String get insSpikeT;
  String insSpikeB(String cat, double pct);

  // ── misc ──
  String get currencyLabel;
  String get appsNoData;
  String get requiredField;

  // ── profile photo ──
  String get photoTitle;
  String get photoCamera;
  String get photoGallery;
  String get photoRemove;
  String get photoTapHint;
  String get photoGoogleHint;

  // ── dashboard banner ──
  String bannerBackupTitle(String when);
  String get bannerBackupBody;
  String get bannerBackupCta;
  String get bannerSavingsTitle;
  String bannerSavingsBody(String rate);
  String get bannerSavingsCta;
  String get bannerGoalTitle;
  String bannerGoalBody(String pct, String left);
  String get bannerGoalCta;
  String get bannerAddTxTitle;
  String get bannerAddTxBody;
  String get bannerAddTxCta;

  // ── notifications (system) ──
  String get notifSettingsTitle;
  String get notifDailyReminder;
  String get notifDailyReminderHelp;
  String get notifDailyTime;
  String get notifDenied;
  String notifDailyTitle(String time);
  String get notifDailyBody;
  String notifWeeklyBodyLive(String spent);
  String get notifBudgetThresholdBody;
  String notifBudgetOverBodyLive(String cat, String money);
  String notifBudgetNearBodyLive(String cat, String pct);

  // ── Google Drive backup ──
  String get driveTab;
  String get driveIntro;
  String get driveSignIn;
  String get driveSignOut;
  String get driveSignedInAs;
  String get driveBackupNow;
  String get driveBackups;
  String get driveNoBackups;
  String get driveUploading;
  String get driveUploaded;
  String get driveDeleting;
  String get driveRestoreFailed;
  String get driveSetupNeeded;
  String get driveSetupNeededBody;
  String get driveSetupStep1;
  String get driveSetupStep2;
  String get driveSetupStep3;
  String get driveShareAlt;
  String get driveShareAltHelp;
  String get driveLastBackupNever;
  String get driveLoadMore;

  // ── login (Google) ──
  String get loginSubtitle;
  String get loginWithGoogle;
  String get loginContinueWithout;
  String get loginPrivacyNote;
  String get loginSetupTitle;
  String get loginSetupBody;
  String get loginFailed;

  // ── account (profile) ──
  String get accountSection;
  String get accountSignedInHelp;
  String get accountGuest;
  String get accountSignIn;
  String get accountSignOut;

  // ── announcements / ads (from admin API) ──
  String get announcementLabel;
  String get announcementDismiss;
  String get adLabel;

  // ── notification center (v2) ──
  String get notifCenterTitle;
  String get notifSectionReminders;
  String get notifSectionStatus;
  String get notifSectionNotices;
  String get notifCenterEmpty;
  String get notifDailyScheduledFail;
  String notifStatusAllOk(int n);
  String get notifLastError;
  String get notifPushLabel;
  String get notifPushOn;
  String get notifResync;

  // v2.2.3 — smart notifications + device health
  String get notifSmartToggle;
  String get notifSmartHelp;
  String get notifTestBtn;
  String get notifTestHelp;
  String get notifTestSent;
  String notifSmartYesterday(String spent);
  String notifSmartMonth(String spent);
  String notifSmartLeft(String left);
  String get notifPermWarning;
  String get notifPermHelp;
  String get notifPermAction;
  String get notifBatteryTitle;
  String get notifBatteryHelp;
  String get notifBatteryAction;

  // ── rewarded ads / support (v2) ──
  String get rewardedSection;
  String get rewardedTitle;
  String get rewardedBody;
  String get rewardedWatch;
  String get rewardedGranted;
  String get rewardedLeftMins(int mins);
  String get rewardedFailed;
  String get rewardedLoading;
  String get maintenancePopupTitle;
  String get maintenancePopupBody;

  // ── auto Drive sync (v2) ──
  String get autoSyncTitle;
  String get autoSyncHelp;
  String get autoSyncLastNever;
  String get autoSyncRemember;
  String get autoSyncRememberHelp;
  String get autoSyncNow;
  String get autoSyncSyncing;
  String get autoRestoreChecking;
  String autoRestoreDone(int txCount);
  String get autoRestoreNeedPassTitle;
  String get autoRestoreNeedPassHelp;
  String get autoRestoreSkipLocal;
  String get autoRestoreFailed;

  // ── v2.1 smart features ──
  String get budgetSuggestAvg;
  String get budgetSuggestUse;
  String get budgetSuggestNoData;
  String get insWeekendT;
  String insWeekendB(double pct);
  String get insBurnRateT;
  String insBurnRateB(String projected, String budget);
  String get insBurnRateOverT;
  String insBurnRateOverB(String projected, String budget);
  String get scanReceipt;
  String get scanningReceipt;
  String get ocrNoAmount;
  String get ocrFound;
  String get ocrUse;
  String get lockTitle;
  String get lockSubtitle;
  String get lockUnlock;
  String get lockFailed;
  String get settingsBiometric;
  String get settingsBiometricHelp;
  String get settingsBiometricUnsupported;
  String get widgetToday;
  String get widgetMonth;
  String get widgetBudget;
  String get goalEtaLabel;
  String goalEtaB(int months, String monthLabel);
  String get goalEtaNoData;
  String get dupTitle;
  String dupBody(String money, String category);
  String get dupSaveAnyway;
  String get dupGoBack;

  // ── v2.1.1: "What's New" upgrade guide ──
  String get guideTitle;
  String get guideSubtitle;
  String get guideStart;
  String get guideFpTitle;
  String guideFpBody(String where);
  String get guideOcrTitle;
  String guideOcrBody(String where);
  String get guideBudgetTitle;
  String guideBudgetBody(String where);

  // v2.2.5 guide rows — the two headline fixes of this version.
  String get guideCatBudgetTitle;
  String get guideCatBudgetBody;
  String get guideFreeCatTitle;
  String get guideFreeCatBody;
  String get guideInsightTitle;
  String guideInsightBody(String where);
  String get guideEtaTitle;
  String guideEtaBody(String where);
  String get guideWidgetTitle;
  String guideWidgetBody(String where);
  String get guideWidgetWhere;
  String get guideMyTitle;
  String guideMyBody(String where);
  String get guideDupTitle;
  String guideDupBody(String where);

  // ── v2.1.2: fix announcements for the What's New guide ──
  String get guideFixLockTitle;
  String get guideFixLockBody;
  String get guideFixWidgetTitle;
  String get guideFixWidgetBody;

  // ── v2.1.1: backup PIN for the app lock ──
  String get pinUsePin;
  String get pinSheetTitle;
  String get pinSheetHint;
  String get pinWrong;
  String pinAttemptsLeft(int n);
  String get pinTryFingerprint;
  String get pinSetTitle;
  String get pinSetBody;
  String get pinConfirmTitle;
  String get pinMismatch;
  String get pinSaved;
  String get pinSkip;
  String get pinManage;
  String get pinManageHelp;
  String pinStatusSet(String v);
  String get pinRemove;
  String get pinRemoveConfirm;
  String get pinRemoved;
  String get pinEnter4;
}

class _BnStrings extends MbStrings {
  const _BnStrings();

  @override
  String get appName => 'মানিব্যাগ';
  @override
  String get tagline => 'টাকা ট্র্যাক করুন। খরচ বুঝুন। সঞ্চয় গড়ুন।';
  @override
  String get save => 'সেভ';
  @override
  String get cancel => 'বাতিল';
  @override
  String get delete => 'ডিলিট';
  @override
  String get edit => 'এডিট';
  @override
  String get done => 'সম্পন্ন';
  @override
  String get ok => 'ঠিক আছে';
  @override
  String get next => 'পরবর্তী';
  @override
  String get back => 'পেছনে';
  @override
  String get skip => 'স্কিপ';
  @override
  String get start => 'শুরু করুন';
  @override
  String get continueLabel => 'চালিয়ে যান';
  @override
  String get confirm => 'নিশ্চিত করুন';
  @override
  String get all => 'সব';
  @override
  String get expense => 'খরচ';
  @override
  String get income => 'আয়';
  @override
  String get today => 'আজ';
  @override
  String get searchHint => 'খুঁজুন (নোট বা ক্যাটাগরি)';
  @override
  String get error => 'সমস্যা হয়েছে';
  @override
  String get retry => 'আবার চেষ্টা করুন';
  @override
  String get empty => 'খালি';
  @override
  String get seeAll => 'সব দেখুন';
  @override
  String get amount => 'পরিমাণ';
  @override
  String get note => 'নোট';
  @override
  String get noteHint => 'কিসের জন্য? যেমন: রিকশা ভাড়া, বাজার';
  @override
  String get date => 'তারিখ';
  @override
  String get category => 'ক্যাটাগরি';
  @override
  String get select => 'বাছাই করুন';
  @override
  String get none => 'কিছুই না';
  @override
  String get yes => 'হ্যাঁ';
  @override
  String get no => 'না';

  @override
  String get ob1Title => 'মানিব্যাগে স্বাগতম';
  @override
  String get ob1Body => 'আপনার দৈনন্দিন খরচ, আয় আর সঞ্চয় — সব এক জায়গায়, সহজ বাংলায়।';
  @override
  String get ob2Title => 'খরচ ট্র্যাক করুন';
  @override
  String get ob2Body => 'চা হোক বা বাজার — কয়েক সেকেন্ডে লেনদেন লিখে ফেলুন।';
  @override
  String get ob3Title => 'বাজেট সীমা ঠিক রাখুন';
  @override
  String get ob3Body => 'ক্যাটাগরি ধরে মাসিক বাজেট দিন, সীমা ছাড়ার আগেই সতর্কতা পান।';
  @override
  String get ob4Title => 'সঞ্চয়ের লক্ষ্য পূরণ করুন';
  @override
  String get ob4Body => 'শুয়োরের ব্যাংকে টাকা জমান, লক্ষ্য পূরণের পথে এগিয়ে থাকুন।';
  @override
  String get ob5Title => 'স্মার্ট ইনসাইট পান';
  @override
  String get ob5Body => 'কোথায় বেশি খরচ হচ্ছে, কতটা সঞ্চয় হচ্ছে — এক নজরে দেখুন।';
  @override
  String get ob6Title => 'আপনার ডেটা, আপনার ডিভাইসে';
  @override
  String get ob6Body => 'সব তথ্য আপনার ফোনেই থাকে — কোনো সার্ভারে যায় না। চাইলে এনক্রিপ্টেড ব্যাকআপ নিন।';

  @override
  String get setupTitle => 'প্রোফাইল সেটআপ';
  @override
  String get setupSubtitle => 'একবার সেট করুন, দিনভর সহজে ব্যবহার করুন';
  @override
  String get yourName => 'আপনার নাম';
  @override
  String get yourNameHint => 'যেমন: রাহাত';
  @override
  String get monthlyIncome => 'মাসিক আয় (ঐচ্ছিক)';
  @override
  String get monthlyIncomeHint => 'যেমন: 50000';
  @override
  String get monthlyIncomeHelp => 'সঞ্চয়ের হার হিসাব করতে সাহায্য করে';
  @override
  String get languageLabel => 'ভাষা';
  @override
  String get appearance => 'থিম';
  @override
  String get darkTheme => 'ডার্ক';
  @override
  String get lightTheme => 'লাইট';
  @override
  String get setupCta => 'শুরু করা যাক';

  @override
  String get navHome => 'হোম';
  @override
  String get navTransactions => 'লেনদেন';
  @override
  String get navBudget => 'বাজেট';
  @override
  String get navProfile => 'প্রোফাইল';

  @override
  String get dashMonthIncome => 'আয় (এই মাস)';
  @override
  String get dashMonthExpense => 'খরচ (এই মাস)';
  @override
  String get dashNetSavings => 'নিট সঞ্চয়';
  @override
  String get dashSavingsRate => 'সঞ্চয়ের হার';
  @override
  String get dashBudgetTitle => 'বাজেট ওভারভিউ';
  @override
  String get dashBudgetLeft => 'বাকি আছে';
  @override
  String get dashBudgetOver => 'সীমা ছাড়িয়েছে';
  @override
  String get dashBudgetNone => 'এখনো বাজেট সেট করা হয়নি';
  @override
  String get dashRecent => 'সাম্প্রতিক লেনদেন';
  @override
  String get dashTopCategories => 'শীর্ষ ক্যাটাগরি';
  @override
  String get dashThisMonth => 'এই মাস';
  @override
  String get noTransactions => 'কোনো লেনদেন নেই';
  @override
  String get noTransactionsHint => 'প্রথম লেনদেন যোগ করে শুরু করুন';
  @override
  String get addFirstTransaction => 'লেনদেন যোগ করুন';
  @override
  String get setBudgetCta => 'বাজেট সেট করুন';
  @override
  String get todaySummaryTitle => 'আজকের হিসাব';
  @override
  String get todaySummaryNoTx => 'আজ এখনো কোনো লেনদেন নেই';
  @override
  String get todaySummaryNoTxHint =>
      'খরচ বা আয় যোগ করলে এখানে আজকের হিসাব দেখা যাবে';
  @override
  String get todayAdd => 'যোগ করুন';
  @override
  String get todayNet => 'নিট';
  @override
  String todaySavedToday(String amount) =>
      'দুর্দান্ত! আজ $amount সাশ্রয় হয়েছে';
  @override
  String get todayOverspent => 'আজ খরচ আয়ের চেয়ে বেশি হয়েছে';
  @override
  String todayExpenseOnly(String amount) => 'আজ $amount খরচ হয়েছে';
  @override
  String todaySafeToSpend(String amount) => 'আজ নিরাপদে খরচ করা যায় $amount';

  @override
  String get txTitle => 'লেনদেন';
  @override
  String get txSearchHint => 'খুঁজুন…';
  @override
  String get txFiltersAll => 'সব';
  @override
  String get txFiltersExpense => 'খরচ';
  @override
  String get txFiltersIncome => 'আয়';
  @override
  String get txDayTotal => 'দিনের মোট';
  @override
  String get txDeleted => 'লেনদেন ডিলিট হয়েছে';
  @override
  String get txEmptyFiltered => 'এই ফিল্টারে কিছু পাওয়া যায়নি';
  @override
  String get txCountOne => '১টি লেনদেন';
  @override
  String txCountMany(int n) => '$nটি লেনদেন';

  @override
  String get txAddExpense => 'খরচ যোগ করুন';
  @override
  String get txAddIncome => 'আয় যোগ করুন';
  @override
  String get txEditTitle => 'লেনদেন এডিট';
  @override
  String get txAmountHint => '0';
  @override
  String get txSelectCategory => 'ক্যাটাগরি বাছাই করুন';
  @override
  String get txDeleteConfirm => 'লেনদেন ডিলিট?';
  @override
  String get txDeleteConfirmBody => 'এটি ফিরিয়ে আনা যাবে না।';
  @override
  String get txSaved => 'সেভ হয়েছে';
  @override
  String get txAmountRequired => 'পরিমাণ লিখুন';
  @override
  String get txNoteFor => 'নোট';
  @override
  String get txFrequentAmounts => 'প্রায়ই যা খরচ হয়';
  @override
  String get txRecentNotes => 'আগের নোট';

  // v2.2.3 — category OR note requirement (bn)
  @override
  String get txCategoryOrNote =>
      'ক্যাটাগরি বাছাই করুন বা উপরে কিসে খরচ হলো লিখুন';

  // v2.2.5 — free-text category box
  @override
  String get txWhatForExpenseLabel => 'কিসে খরচ হলো?';
  @override
  String get txWhatForIncomeLabel => 'কিসে আয় হলো?';
  @override
  String get txWhatForHint => 'যেমন: রিকশা ভাড়া, চা, বাজার — এটাই ক্যাটাগরি হবে';
  @override
  String get txWhatForHelper =>
      'লিখলে এটাই ক্যাটাগরি সেভ হবে — নিচে বাছাই করতে হবে না';
  @override
  String get txCategoryOptional => 'বাক্সে কিছু লিখলে ক্যাটাগরি ঐচ্ছিক';

  @override
  String get budgetTitle => 'বাজেট';
  @override
  String get budgetOverall => 'সামগ্রিক';
  @override
  String get budgetOverallCard => 'মাসিক সামগ্রিক বাজেট';
  @override
  String get budgetByCategory => 'ক্যাটাগরি বাজেট';
  @override
  String get budgetSpent => 'খরচ হয়েছে';
  @override
  String get budgetOf => 'এর মধ্যে';
  @override
  String get budgetLeftShort => 'বাকি';
  @override
  String get budgetOverShort => 'অতিরিক্ত';
  @override
  String get budgetSet => 'বাজেট সেট করুন';
  @override
  String get budgetEdit => 'বাজেট এডিট';
  @override
  String get budgetEmpty => 'কোনো বাজেট নেই';
  @override
  String get budgetEmptyHint => 'মাসিক সীমা দিয়ে খরচ নিয়ন্ত্রণ শুরু করুন';
  @override
  String get budgetOverallHint =>
      'সব ক্যাটাগরির খরচ মিলিয়ে একটাই মাসিক সীমা — মোট খরচ এক নজরে নিয়ন্ত্রণ রাখুন';
  @override
  String get budgetCategoryHint =>
      'প্রতিটা ক্যাটাগরির জন্য আলাদা সীমা — খাবার, যাতায়াত, বিল আলাদা করে ট্র্যাক হয়';
  @override
  String get budgetAddFirst => 'বাজেট যোগ করুন';
  @override
  String get budgetLimitLabel => 'বাজেটের সীমা';
  @override
  String get budgetLimitHint => 'যেমন: 30000';
  @override
  String get budgetForLabel => 'কীসের জন্য';
  @override
  String get budgetOverallOption => 'সামগ্রিক (সব খরচ)';
  @override
  String get budgetRollover => 'অব্যবহৃত অংশ পরের মাসে যোগ';
  @override
  String get budgetRolloverHint => 'এই মাসে বাকি থাকলে পরের মাসের সীমা বাড়বে';
  @override
  String get budgetAlertLabel => 'সতর্কতা (৮৫% ডিফল্ট)';
  @override
  String get budgetAlertHelp => 'সীমার ৮৫% খরচ হলে হোমে সতর্কতা দেখাবে';
  @override
  String get budgetOverBody => 'বাজেট সীমা ছাড়িয়ে গেছে!';
  @override
  String get budgetNearBody => 'বাজেটের সীমার কাছাকাছি';
  @override
  String get budgetSaved => 'বাজেট সেভ হয়েছে';
  @override
  String get budgetDelete => 'বাজেট ডিলিট';

  // v2.2.3 — budget sheet category fallback (bn)
  @override
  String get budgetNoCategories => 'কোনো খরচের ক্যাটাগরি নেই';
  @override
  String get budgetManageCategories => 'ক্যাটাগরি যোগ করুন';

  @override
  String get analyticsTitle => 'অ্যানালিটিক্স';
  @override
  String get anThisMonth => 'এই মাস';
  @override
  String get anLastMonth => 'গত মাস';
  @override
  String get anThisYear => 'এই বছর';
  @override
  String get anSpendingByCategory => 'ক্যাটাগরি অনুযায়ী খরচ';
  @override
  String get anWeeklySpend => 'সাপ্তাহিক খরচ';
  @override
  String get anMonthlyTrend => 'মাসিক ট্রেন্ড (৬ মাস)';
  @override
  String get anIncomeVsExpense => 'আয় বনাম খরচ';
  @override
  String get anTopSpending => 'সর্বোচ্চ খরচ';
  @override
  String get anInsights => 'ইনসাইট';
  @override
  String get anNoData => 'পর্যাপ্ত ডেটা নেই';
  @override
  String get anNoDataHint => 'কিছু লেনদেন যোগ করলে চার্ট দেখা যাবে';
  @override
  String get anShare => 'সব দেখুন';

  @override
  String get savingsTitle => 'সঞ্চয়';
  @override
  String get savingsTotalSaved => 'মোট সঞ্চয়';

  @override
  String get savingsMonthNet => 'এই মাসের সঞ্চয়';

  @override
  String get savingsInGoals => 'লক্ষ্যে জমা';

  @override
  String goalsCountMany(int n) => '$nটি লক্ষ্য';
  @override
  String get goalsTitle => 'সঞ্চয়ের লক্ষ্য';
  @override
  String get goalsActive => 'চলমান লক্ষ্য';
  @override
  String get goalsEmpty => 'কোনো লক্ষ্য নেই';
  @override
  String get goalsEmptyHint => 'নতুন লক্ষ্য বানিয়ে সঞ্চয় শুরু করুন';
  @override
  String get goalAdd => 'লক্ষ্য যোগ করুন';
  @override
  String get goalEdit => 'লক্ষ্য এডিট';
  @override
  String get goalName => 'লক্ষ্যের নাম';
  @override
  String get goalNameHint => 'যেমন: নতুন ফোন';
  @override
  String get goalTarget => 'লক্ষ্যের পরিমাণ';
  @override
  String get goalTargetHint => 'যেমন: 25000';
  @override
  String get goalTargetDate => 'লক্ষ্যের তারিখ';
  @override
  String get goalTargetDateOptional => 'ঐচ্ছিক';
  @override
  String get goalTargetReached => '🎉 লক্ষ্য পূরণ!';
  @override
  String get goalProgressOf => 'এর মধ্যে';
  @override
  String get goalContribute => 'টাকা জমান';
  @override
  String get goalContributeTitle => 'সঞ্চয়ে টাকা যোগ';
  @override
  String get goalWithdraw => 'টাকা তুলুন';
  @override
  String get goalHistory => 'ইতিহাস';
  @override
  String get goalNoHistory => 'এখনো কোনো জমা নেই';
  @override
  String get goalSavedOn => 'জমা হয়েছে';
  @override
  String get goalDelete => 'লক্ষ্য ডিলিট';
  @override
  String get goalDeleteBody => 'লক্ষ্য ও এর সব জমার ইতিহাস মুছে যাবে।';
  @override
  String get goalMarkComplete => 'সম্পন্ন হিসেবে চিহ্নিত';
  @override
  String get goalCompletedBadge => 'সম্পন্ন';
  @override
  String get goalContributionAdded => 'জমা হয়েছে';
  @override
  String get goalNeedMore => 'বাকি';
  @override
  String get goalNoTargetDate => 'তারিখ নেই';
  @override
  String get goalDaysLeft => 'দিন বাকি';
  @override
  String get goalOverdue => 'সময় পার';

  @override
  String get categoriesTitle => 'ক্যাটাগরি';
  @override
  String get catExpenseTab => 'খরচ';
  @override
  String get catIncomeTab => 'আয়';
  @override
  String get catAdd => 'ক্যাটাগরি যোগ';
  @override
  String get catEdit => 'ক্যাটাগরি এডিট';
  @override
  String get catName => 'নাম';
  @override
  String get catNameHint => 'যেমন: কফি';
  @override
  String get catIcon => 'আইকন';
  @override
  String get catColor => 'রং';
  @override
  String get catTxUsed => 'টি লেনদেনে ব্যবহৃত';
  @override
  String get catDeleteConfirm => 'ক্যাটাগরি ডিলিট?';
  @override
  String get catDeleteBody => 'ক্যাটাগরি মুছে ফেলা হবে। এর লেনদেনগুলো থেকে যাবে (ক্যাটাগরি ছাড়া)।';
  @override
  String get catDeleteBlock => 'এই ক্যাটাগরিতে লেনদেন আছে — ডিলিট করা যাবে না';
  @override
  String get catSaved => 'ক্যাটাগরি সেভ হয়েছে';
  @override
  String get catNameRequired => 'নাম দিন';

  @override
  String get profileTitle => 'প্রোফাইল';
  @override
  String get settingsSectionGeneral => 'সাধারণ';
  @override
  String get settingsLanguage => 'ভাষা';
  @override
  String get settingsBangla => 'বাংলা';
  @override
  String get settingsEnglish => 'English';
  @override
  String get settingsTheme => 'থিম';
  @override
  String get settingsDark => 'ডার্ক';
  @override
  String get settingsLight => 'লাইট';
  @override
  String get settingsSystem => 'সিস্টেম';
  @override
  String get settingsBnDigits => 'বাংলা সংখ্যা';
  @override
  String get settingsBnDigitsHelp => '৳১,২৫০ এর মতো বাংলা অঙ্কে দেখান';
  @override
  String get settingsSectionAlerts => 'সতর্কতা';
  @override
  String get settingsBudgetAlerts => 'বাজেট সতর্কতা';
  @override
  String get settingsBudgetAlertsHelp => 'বাজেট ৮৫% পার হলে হোমে ব্যানার';
  @override
  String get settingsWeeklySummary => 'সাপ্তাহিক সারসংক্ষেপ';
  @override
  String get settingsWeeklySummaryHelp => 'সপ্তাহের খরচের সারসংক্ষেপ হোমে দেখান';
  @override
  String get settingsSectionData => 'ডেটা';
  @override
  String get settingsExportCsv => 'CSV এক্সপোর্ট';
  @override
  String get settingsExportCsvHelp => 'সব লেনদেন ফাইলে সেভ/শেয়ার করুন';
  @override
  String get settingsBackup => 'এনক্রিপ্টেড ব্যাকআপ';
  @override
  String get settingsBackupHelp => 'পাসফ্রেজ দিয়ে সুরক্ষিত ব্যাকআপ তৈরি করুন';
  @override
  String get settingsRestore => 'ব্যাকআপ রিস্টোর';
  @override
  String get settingsRestoreHelp => '.mbbak ফাইল থেকে ফিরিয়ে আনুন';
  @override
  String get settingsCategories => 'ক্যাটাগরি ম্যানেজ';
  @override
  String get settingsCategoriesHelp => 'কাস্টম ক্যাটাগরি যোগ/এডিট করুন';
  @override
  String get settingsSectionAbout => 'অ্যাপ সম্পর্কে';
  @override
  String get settingsPrivacyTitle => 'প্রাইভেসি';
  @override
  String get settingsPrivacyBody => 'মানিব্যাগ আপনার সব তথ্য শুধু আপনার ডিভাইসেই রাখে। কোনো সার্ভারে কিছু পাঠানো হয় না। ব্যাংক অ্যাকাউন্ট বা পাসওয়ার্ড কখনো চাওয়া হয় না — এটি শুধুই একটি হিসাব রাখার অ্যাপ।';
  @override
  String get settingsVersion => 'ভার্সন';
  @override
  String get settingsReset => 'সব ডেটা রিসেট';
  @override
  String get settingsResetConfirm => 'সব ডেটা মুছে ফেলবেন?';
  @override
  String get settingsResetBody => 'সব লেনদেন, বাজেট, লক্ষ্য ও সেটিংস মুছে যাবে। এটি ফেরানো যাবে না।';
  @override
  String get settingsResetDone => 'রিসেট সম্পন্ন';
  @override
  String get settingsExported => 'এক্সপোর্ট হয়েছে';
  @override
  String get settingsExportFail => 'এক্সপোর্ট ব্যর্থ';

  @override
  String get backupTitle => 'ব্যাকআপ';
  @override
  String get backupIntro => 'আপনার সব ডেটার এনক্রিপ্টেড কপি বানান। AES-256 এ সুরক্ষিত, পাসফ্রেজ ছাড়া কেউ খুলতে পারবে না।';
  @override
  String get backupPassphrase => 'পাসফ্রেজ';
  @override
  String get backupPassphraseHint => 'কমপক্ষে ৬ অক্ষর';
  @override
  String get backupPassphraseRepeat => 'পাসফ্রেজ আবার দিন';
  @override
  String get backupCreate => 'ব্যাকআপ তৈরি করুন';
  @override
  String get backupCreating => 'ব্যাকআপ হচ্ছে…';
  @override
  String get backupCreatedTitle => 'ব্যাকআপ তৈরি হয়েছে';
  @override
  String get backupCreatedBody => 'ফাইল সেভ হয়েছে — নিচের বাটনে শেয়ার/সেভ করে রাখুন';
  @override
  String get backupShare => 'ফাইল শেয়ার করুন';
  @override
  String get backupDone => 'সম্পন্ন';
  @override
  String get backupPassShort => 'পাসফ্রেজ কমপক্ষে ৬ অক্ষরের হতে হবে';
  @override
  String get backupPassMismatch => 'পাসফ্রেজ দুটি মেলেনি';
  @override
  String get backupRestoreTitle => 'ব্যাকআপ রিস্টোর';
  @override
  String get backupRestoreIntro => 'আগের ব্যাকআপ (.mbbak) ফাইল বাছাই করুন';
  @override
  String get backupPickFile => 'ফাইল বাছাই';
  @override
  String get backupDecrypting => 'ফাইল খোলা হচ্ছে…';
  @override
  String get backupWrongPass => 'ভুল পাসফ্রেজ';
  @override
  String get backupInvalidFile => 'এটি মানিব্যাগের ব্যাকআপ ফাইল নয়';
  @override
  String get backupCorruptFile => 'ফাইলটি নষ্ট হয়েছে';
  @override
  String get backupRestoreMode => 'রিস্টোর মোড';
  @override
  String get backupModeReplace => 'রিপ্লেস';
  @override
  String get backupModeReplaceHelp => 'বর্তমান সব ডেটা মুছে ব্যাকআপের ডেটা বসবে';
  @override
  String get backupModeMerge => 'মার্জ';
  @override
  String get backupModeMergeHelp => 'ব্যাকআপের নতুন লেনদেনগুলো যোগ হবে';
  @override
  String get backupRestoreCta => 'রিস্টোর করুন';
  @override
  String get backupRestoredTitle => 'রিস্টোর সম্পন্ন';
  @override
  String get backupRestoredBody => 'আপনার ডেটা ফিরিয়ে আনা হয়েছে';
  @override
  String get backupFormatNote => 'ফরম্যাট: moneybag-backup-v1 · AES-256-GCM · PBKDF2';
  @override
  String get backupStats => 'ব্যাকআপে আছে';

  @override
  String get notifBudgetTitle => 'বাজেট সতর্কতা';
  @override
  String get notifWeeklyTitle => 'সাপ্তাহিক সারসংক্ষেপ';
  @override
  String get notifBudgetBody => 'একটি বাজেট ৮৫% ছাড়িয়ে গেছে';
  @override
  String get notifWeeklyBody => 'এই সপ্তাহের খরচ দেখে নিন';

  @override
  String get insTopCategoryT => 'সর্বোচ্চ খরচের ক্ষেত্র';
  @override
  String insTopCategoryB(String cat, String amt) => 'এই মাসে $cat-এ সবচেয়ে বেশি: $amt';
  @override
  String get insMoMUpT => 'খরচ বেড়েছে';
  @override
  String insMoMB(double pct) => 'গত মাসের চেয়ে খরচ ${pct.round()}% বেশি';
  @override
  String get insMoMDownT => 'খরচ কমেছে';
  @override
  String insMoMDownB(double pct) => 'গত মাসের চেয়ে খরচ ${pct.round()}% কম — দুর্দান্ত!';
  @override
  String get insSavingsRateT => 'সঞ্চয়ের হার';
  @override
  String insSavingsRateB(double pct) => 'এই মাসে আয়ের ${pct.round()}% সঞ্চয় হয়েছে';
  @override
  String get insDailyAvgT => 'দৈনিক গড় খরচ';
  @override
  String insDailyAvgB(String amt) => 'প্রতিদিন গড়ে $amt খরচ হচ্ছে';
  @override
  String get insProjectedT => 'মাস শেষে অনুমান';
  @override
  String insProjectedB(String amt) => 'এই গতিতে মাস শেষে খরচ $amt হতে পারে';
  @override
  String get insBudgetWarnT => 'বাজেট সতর্কতা';
  @override
  String insBudgetWarnB(String cat) => '$cat বাজেটের সীমার কাছাকাছি';
  @override
  String get insBudgetOverT => 'বাজেট ছাড়িয়েছে';
  @override
  String insBudgetOverB(String cat) => '$cat বাজেটের সীমা পার হয়ে গেছে';
  @override
  String get insBiggestT => 'বড় লেনদেন';
  @override
  String insBiggestB(String amt, String cat) => 'এই মাসের সবচেয়ে বড়: $amt ($cat)';
  @override
  String get insNoSpendT => 'খরচ-মুক্ত দিন';
  @override
  String insNoSpendB(int n) => 'এই মাসে $n দিন কোনো খরচ হয়নি — সাবাশ!';
  @override
  String get insGreetingT => 'শুরু করা যাক';
  @override
  String get insGreetingB => 'লেনদেন যোগ করলে এখানে স্মার্ট ইনসাইট দেখা যাবে';
  @override
  String get insSpikeT => 'এক ক্যাটাগরিতে বাড়তি খরচ';
  @override
  String insSpikeB(String cat, double pct) =>
      '$cat-এ গত ৩ মাসের গড়ের চেয়ে ${pct.round()}% বেশি খরচ হয়েছে';

  @override
  String get currencyLabel => 'কারেন্সি';
  @override
  String get appsNoData => 'ডেটা নেই';
  @override
  String get requiredField => 'এটি দেওয়া জরুরি';

  // ── profile photo (bn) ──
  @override
  String get photoTitle => 'প্রোফাইল ছবি';
  @override
  String get photoCamera => 'ক্যামেরা';
  @override
  String get photoGallery => 'গ্যালারি';
  @override
  String get photoRemove => 'ছবি সরান';
  @override
  String get photoTapHint => 'ছবি যোগ করতে চাপুন';

  // ── dashboard banner (bn) ──
  @override
  String bannerBackupTitle(String when) => 'ব্যাকআপ · $when';
  @override
  String get bannerBackupBody => 'আপনার ডেটা এনক্রিপ্ট করে সুরক্ষিত রাখুন';
  @override
  String get bannerBackupCta => 'ব্যাকআপ নিন';
  @override
  String get bannerSavingsTitle => 'সঞ্চয়ের অগ্রগতি';
  @override
  String bannerSavingsBody(String rate) => 'এই মাসে আয়ের $rate সঞ্চয় হয়েছে';
  @override
  String get bannerSavingsCta => 'দেখুন';
  @override
  String get bannerGoalTitle => 'লক্ষ্যের খবর';
  @override
  String bannerGoalBody(String pct, String left) => 'লক্ষ্য পূরণ হয়েছে $pct — বাকি $left';
  @override
  String get bannerGoalCta => 'সঞ্চয় দেখুন';
  @override
  String get bannerAddTxTitle => 'আজকের হিসাব';
  @override
  String get bannerAddTxBody => 'খরচ বা আয় যোগ করলে ইনসাইট আরও নিখুঁত হবে';
  @override
  String get bannerAddTxCta => 'যোগ করুন';

  // ── notifications (bn) ──
  @override
  String get notifSettingsTitle => 'নোটিফিকেশন';
  @override
  String get notifDailyReminder => 'দৈনিক রিমাইন্ডার';
  @override
  String get notifDailyReminderHelp => 'প্রতিদিন সন্ধ্যায় খরচ লেখার মনে করিয়ে দেয়';
  @override
  String get notifDailyTime => 'সময়';
  @override
  String get notifDenied => 'নোটিফিকেশনের অনুমতি দেওয়া হয়নি';
  @override
  String notifDailyTitle(String time) => 'আজকের খরচ লিখুন';
  @override
  String get notifDailyBody => 'মাত্র ১ মিনিট লাগবে — আজকের হিসাব গুছিয়ে ফেলুন';
  @override
  String notifWeeklyBodyLive(String spent) => 'গত ৭ দিনে খরচ: $spent';
  @override
  String get notifBudgetThresholdBody => 'একটি বাজেট সীমার কাছাকাছি';
  @override
  String notifBudgetOverBodyLive(String cat, String money) => '$cat বাজেট ছাড়িয়েছে ($money)';
  @override
  String notifBudgetNearBodyLive(String cat, String pct) => '$cat বাজেটের $pct খরচ হয়েছে';

  // ── Google Drive backup (bn) ──
  @override
  String get driveTab => 'Google Drive';
  @override
  String get driveIntro => 'এনক্রিপ্টেড ব্যাকআপ আপনার Google Drive-এর লুকানো অ্যাপ-ফোল্ডারে জমা থাকে — Google-ও পড়তে পারে না';
  @override
  String get driveSignIn => 'Google অ্যাকাউন্টে সাইন-ইন';
  @override
  String get driveSignOut => 'সাইন-আউট';
  @override
  String get driveSignedInAs => 'সাইন-ইন করা আছে';
  @override
  String get driveBackupNow => 'Drive-এ ব্যাকআপ নিন';
  @override
  String get driveBackups => 'Drive-এ থাকা ব্যাকআপ';
  @override
  String get driveNoBackups => 'এখনো কোনো ব্যাকআপ নেই';
  @override
  String get driveUploading => 'আপলোড হচ্ছে…';
  @override
  String get driveUploaded => 'Drive-এ ব্যাকআপ সম্পন্ন';
  @override
  String get driveDeleting => 'ডিলিট হচ্ছে…';
  @override
  String get driveRestoreFailed => 'ডাউনলোড ব্যর্থ হয়েছে';
  @override
  String get driveSetupNeeded => 'Drive সেটআপ দরকার';
  @override
  String get driveSetupNeededBody => 'সরাসরি Drive-এ ব্যাকআপ নিতে একবার সেটআপ করতে হয়:';
  @override
  String get driveSetupStep1 => 'Google Cloud Console-এ Web OAuth Client ID তৈরি করুন';
  @override
  String get driveSetupStep2 => 'অ্যাপের SHA-1 আঙুলছাপ সেখানে যোগ করুন';
  @override
  String get driveSetupStep3 => 'ID-টি lib/core/config.dart-এ বসিয়ে আবার বিল্ড করুন';
  @override
  String get driveShareAlt => 'ব্যাকআপ শেয়ার করুন';
  @override
  String get driveShareAltHelp => 'শেয়ার মেনু থেকে Drive বেছে নিলেই সেভ হবে';
  @override
  String get driveLastBackupNever => 'কখনো ব্যাকআপ নেওয়া হয়নি';
  @override
  String get driveLoadMore => 'আরও';

  @override
  String get photoGoogleHint => 'Google প্রোফাইলের ছবি ও নাম বসে গেছে — চাইলে বদলে নিতে পারেন';

  // ── login (bn) ──
  @override
  String get loginSubtitle => 'আপনার টাকার হিসাব, আপনার হাতের মুঠোয়';
  @override
  String get loginWithGoogle => 'Google দিয়ে সাইন-ইন করুন';
  @override
  String get loginContinueWithout => 'সাইন-ইন ছাড়াই চালিয়ে যান';
  @override
  String get loginPrivacyNote =>
      'সাইন-ইন করলে নাম-ছবি নিজে থেকে বসে যায় আর Drive ব্যাকআপ সহজ হয়। না করলেও অ্যাপের সব কিছু কাজ করবে — ডেটা আপনার ফোনেই থাকে।';
  @override
  String get loginSetupTitle => 'Google সাইন-ইন সেটআপ দরকার';
  @override
  String get loginSetupBody =>
      'একবার Web OAuth Client ID বসালেই Google সাইন-ইন চালু হবে (Drive ব্যাকআপও একই ID ব্যবহার করে)। ততক্ষণ সাইন-ইন ছাড়াই চালিয়ে যেতে পারেন।';
  @override
  String get loginFailed => 'সাইন-ইন করা যায়নি';

  // ── account (bn) ──
  @override
  String get accountSection => 'অ্যাকাউন্ট';
  @override
  String get accountSignedInHelp => 'Google অ্যাকাউন্টে সাইন-ইন করা আছে';
  @override
  String get accountGuest => 'সাইন-ইন করা নেই';
  @override
  String get accountSignIn => 'Google দিয়ে সাইন-ইন';
  @override
  String get accountSignOut => 'সাইন-আউট';

  // ── announcements / ads (bn) ──
  @override
  String get announcementLabel => 'নোটিশ';
  @override
  String get announcementDismiss => 'বুঝেছি';
  @override
  String get adLabel => 'বিজ্ঞাপন';

  // ── notification center (v2, bn) ──
  @override
  String get notifCenterTitle => 'নোটিফিকেশন';
  @override
  String get notifSectionReminders => 'রিমাইন্ডার';
  @override
  String get notifSectionStatus => 'অবস্থা';
  @override
  String get notifSectionNotices => 'নোটিশ ও পুশ';
  @override
  String get notifCenterEmpty => 'এখন কোনো নোটি অ্যাক্টিভ নেই';
  @override
  String get notifDailyScheduledFail => 'শিডিউল হয়নি — সময়টা আবার সেট করুন';
  @override
  String notifStatusAllOk(int n) {
    const d = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    final digits = n
        .toString()
        .split('')
        .map((c) => d[int.tryParse(c) ?? 0])
        .join();
    return 'সব ঠিক আছে · $digitsটি রিমাইন্ডার সক্রিয়';
  }
  @override
  String get notifLastError => 'কারণ';
  @override
  String get notifPushLabel => 'রিয়েল-টাইম পুশ';
  @override
  String get notifPushOn => 'চালু';
  @override
  String get notifResync => 'আবার সিঙ্ক করুন';

  // v2.2.3 — smart notifications + device health (bn)
  @override
  String get notifSmartToggle => 'স্মার্ট নোটিফিকেশন';
  @override
  String get notifSmartHelp =>
      'রিমাইন্ডারে আপনার আসল খরচের হিসাব দেখানো হয় (গতকাল, এ মাসে, বাজেট)';
  @override
  String get notifTestBtn => 'টেস্ট নোটিফিকেশন পাঠান';
  @override
  String get notifTestHelp => 'নোটিফিকেশন এখনই এসেছে কিনা যাচাই করুন';
  @override
  String get notifTestSent => 'টেস্ট নোটিফিকেশন পাঠানো হয়েছে';
  @override
  String notifSmartYesterday(String spent) => 'গতকাল $spent';
  @override
  String notifSmartMonth(String spent) => 'এ মাসে $spent';
  @override
  String notifSmartLeft(String left) => 'বাজেটে বাকি $left';
  @override
  String get notifPermWarning => 'নোটিফিকেশন বন্ধ আছে';
  @override
  String get notifPermHelp =>
      'অনুমতি ছাড়া রিমাইন্ডার দেখাতে পারে না — সেটিংস থেকে চালু করুন';
  @override
  String get notifPermAction => 'চালু করুন';
  @override
  String get notifBatteryTitle => 'ব্যাটারি সেভার রিমাইন্ডার চুপ করে দেয়';
  @override
  String get notifBatteryHelp =>
      'ব্যাকগ্রাউন্ডে অ্যালার্ম বন্ধ হয়ে যাওয়ার প্রধান কারণ — অনুমতি দিলে রিমাইন্ডার ঠিক থাকবে';
  @override
  String get notifBatteryAction => 'অনুমতি দিন';

  // ── rewarded ads / support (v2, bn) ──
  @override
  String get rewardedSection => 'সাপোর্ট';
  @override
  String get rewardedTitle => 'বিজ্ঞাপনমুক্ত থাকুন';
  @override
  String get rewardedBody =>
      'একটা রিওয়ার্ড অ্যাড দেখে ১ ঘণ্টার জন্য সব বিজ্ঞাপন বন্ধ রাখুন।';
  @override
  String get rewardedWatch => 'রিওয়ার্ড অ্যাড দেখুন';
  @override
  String get rewardedGranted => '১ ঘণ্টার জন্য বিজ্ঞাপন বন্ধ রাখা হলো!';
  @override
  String get rewardedLeftMins(int mins) => 'বিজ্ঞাপনমুক্ত চলছে — আর $mins মিনিট বাকি';
  @override
  String get rewardedFailed => 'অ্যাড লোড হয়নি — কিছুক্ষণ পর আবার চেষ্টা করুন';
  @override
  String get rewardedLoading => 'অ্যাড লোড হচ্ছে…';
  @override
  String get maintenancePopupTitle => 'অ্যাপ মেইনটেন্যান্স সমর্থন করুন';
  @override
  String get maintenancePopupBody => 'অ্যাপটি মেইনটেইন করার জন্য দয়া করে আমাদের সমর্থন করুন। একটি রিওয়ার্ড অ্যাড দেখলে ১ ঘণ্টার জন্য সব বিজ্ঞাপন বন্ধ থাকবে।';

  // ── auto Drive sync (v2, bn) ──
  @override
  String get autoSyncTitle => 'অটো সিঙ্ক (Google Drive)';
  @override
  String get autoSyncHelp =>
      'কিছু সেভ/ডিলিট করার ৫ সেকেন্ড পর নিজে থেকেই এনক্রিপ্টেড ব্যাকআপ Drive-এ যাবে';
  @override
  String get autoSyncLastNever => 'শেষ অটো ব্যাকআপ: এখনো হয়নি';
  @override
  String get autoSyncRemember => 'পাসফ্রেজ মনে রাখুন (অটো সিঙ্কের জন্য)';
  @override
  String get autoSyncRememberHelp =>
      'শুধু এই ডিভাইসে সেভ থাকবে — অটো ব্যাকআপ ও অটো রিস্টোরে ব্যবহৃত হবে';
  @override
  String get autoSyncNow => 'এখনই ব্যাকআপ করুন';
  @override
  String get autoSyncSyncing => 'সিঙ্ক হচ্ছে…';
  @override
  String get autoRestoreChecking => 'Drive-এ ব্যাকআপ খোঁজা হচ্ছে…';
  @override
  String autoRestoreDone(int txCount) =>
      'Drive-এর ব্যাকআপ রিস্টোর হয়েছে ($txCountটি লেনদেন ফিরে এসেছে)';
  @override
  String get autoRestoreNeedPassTitle => 'ব্যাকআপ পাওয়া গেছে!';
  @override
  String get autoRestoreNeedPassHelp =>
      'Drive-এ আপনার এনক্রিপ্টেড ব্যাকআপ আছে। একবার পাসফ্রেজ দিন — এরপর সব অটো হবে।';
  @override
  String get autoRestoreSkipLocal => 'ডিভাইসে ডেটা আছে — অটো-রিস্টোর করা হয়নি';
  @override
  String get autoRestoreFailed => 'ব্যাকআপ রিস্টোর করা যায়নি';

  // ── v2.1 স্মার্ট ফিচার ──
  @override
  String get budgetSuggestAvg => 'গত ৩ মাসের গড় খরচ';
  @override
  String get budgetSuggestUse => 'এটাই দাও';
  @override
  String get budgetSuggestNoData => 'গত ৩ মাসের খরচ নেই';
  @override
  String get insWeekendT => 'সপ্তাহান্তের ধরন';
  @override
  String insWeekendB(double pct) =>
      'শুক্র-শনিবারে সপ্তাহের দিনের চেয়ে ${pct.round()}% বেশি খরচ হচ্ছে';
  @override
  String get insBurnRateT => 'বাজেটের গতি';
  @override
  String insBurnRateB(String projected, String budget) =>
      'এই গতিতে মাস শেষ হবে $projected-এ — বাজেট $budget মানে ঠিক আছেন';
  @override
  String get insBurnRateOverT => 'গতি বেশি হচ্ছে';
  @override
  String insBurnRateOverB(String projected, String budget) =>
      'সাবধান! এই গতিতে খরচ $projected-এ পৌঁছাবে — বাজেট ($budget) পার হয়ে যাবে';
  @override
  String get scanReceipt => 'রিসিট স্ক্যান';
  @override
  String get scanningReceipt => 'রিসিট পড়া হচ্ছে…';
  @override
  String get ocrNoAmount => 'কোনো অঙ্ক পাওয়া যায়নি — পরিষ্কার ছবি দিন';
  @override
  String get ocrFound => 'রিসিটে যা পাওয়া গেল';
  @override
  String get ocrUse => 'বসাও';
  @override
  String get lockTitle => 'মানিব্যাগ লক করা';
  @override
  String get lockSubtitle => 'চালিয়ে যেতে আনলক করুন';
  @override
  String get lockUnlock => 'আনলক';
  @override
  String get lockFailed => 'মিলল না — আবার চেষ্টা করুন';
  @override
  String get settingsBiometric => 'ফিঙ্গারপ্রিন্ট লক';
  @override
  String get settingsBiometricHelp =>
      'ফিঙ্গারপ্রিন্ট বা ডিভাইসের পিন দিয়ে মানিব্যাগ লক হবে';
  @override
  String get settingsBiometricUnsupported => 'এই ডিভাইসে সাপোর্ট নেই';
  @override
  String get widgetToday => 'আজ';
  @override
  String get widgetMonth => 'এই মাসে';
  @override
  String get widgetBudget => 'বাজেট';
  @override
  String get goalEtaLabel => 'এই গতিতে';
  @override
  String goalEtaB(int months, String monthLabel) =>
      '$months মাস বাকি → $monthLabel';
  @override
  String get goalEtaNoData => 'নিয়মিত জমালে আনুমানিক সময় দেখাবে';
  @override
  String get dupTitle => 'আবার সেভ করবেন?';
  @override
  String dupBody(String money, String category) =>
      'আজ $category ক্যাটাগরিতে $money আগেই সেভ করা আছে।';
  @override
  String get dupSaveAnyway => 'তবু সেভ করুন';
  @override
  String get dupGoBack => 'ফিরে যান';

  // ── v2.1.1: What's New guide ──
  @override
  String get guideTitle => 'নতুন কী এসেছে';
  @override
  String get guideSubtitle => 'v2.1.2 — লক ও উইজেটের সমস্যা ঠিক হয়েছে';
  @override
  String get guideStart => 'শুরু করি';
  @override
  String get guideFpTitle => 'ফিঙ্গারপ্রিন্ট লক';
  @override
  String guideFpBody(String where) => 'ফিঙ্গারপ্রিন্ট বা ব্যাকআপ পিন দিয়ে অ্যাপ লক। $where';
  @override
  String get guideOcrTitle => 'রিসিট স্ক্যান';
  @override
  String guideOcrBody(String where) => 'ছবি তুললেই টাকার অঙ্ক নিজে বসে যায়। $where';
  @override
  String get guideBudgetTitle => 'স্মার্ট বাজেট পরামর্শ';

  // v2.2.5 guide rows (bn)
  @override
  String get guideCatBudgetTitle => 'ক্যাটাগরি বাজেট ঠিক হয়েছে';
  @override
  String get guideCatBudgetBody =>
      'ক্যাটাগরি বাজেট যোগ করার শিটে এখন ক্যাটাগরি দেখায় ও সেভ হয় — আগের বাগে সব বাজেট একই রকম হয়ে যেত।';
  @override
  String get guideFreeCatTitle => 'লিখলেই ক্যাটাগরি';
  @override
  String get guideFreeCatBody =>
      'খরচ যোগ করার উপরের বাক্সে লিখুন কিসে খরচ হলো — লেখাটাই ক্যাটাগরি হয়ে সেভ হবে, নিচে থেকে বাছাই করতে হবে না।';
  @override
  String guideBudgetBody(String where) => 'গত ৩ মাসের গড় খরচ থেকে বাজেট সাজেস্ট করবে। $where';
  @override
  String get guideInsightTitle => 'স্মার্ট ইনসাইট';
  @override
  String guideInsightBody(String where) => 'খরচের গতি আর সপ্তাহান্তের ধরন বুঝিয়ে দেবে। $where';
  @override
  String get guideEtaTitle => 'সঞ্চয়ের আনুমানিক সময়';
  @override
  String guideEtaBody(String where) => 'এই গতিতে কখন লক্ষ্য পূরণ হবে দেখাবে। $where';
  @override
  String get guideWidgetTitle => 'হোম স্ক্রিন উইজেট';
  @override
  String guideWidgetBody(String where) => 'আজকের ও মাসের খরচ এক নজরে। $where';
  @override
  String get guideWidgetWhere => 'হোম স্ক্রিনে লং-প্রেস → উইজেট → মানিব্যাগ';
  @override
  String get guideMyTitle => 'Material You রঙ';
  @override
  String guideMyBody(String where) => 'Android 12+ এ ওয়ালপেপারের সাথে রঙ বদলায়। $where';
  @override
  String get guideDupTitle => 'ডুপ্লিকেট সতর্কতা';
  @override
  String guideDupBody(String where) => 'একই দিনে একই খরচ দুবার সেভ করলে আগে জিজ্ঞেস করবে। $where';

  // ── v2.1.2: fix announcements ──
  @override
  String get guideFixLockTitle => 'লক এখন ঠিকঠাক';
  @override
  String get guideFixLockBody =>
      'অ্যাপ বন্ধ করে আবার খুললেও এখন ফিঙ্গারপ্রিন্ট বা পিন চাইবে।';
  @override
  String get guideFixWidgetTitle => 'উইজেট এখন ঠিকঠাক';
  @override
  String get guideFixWidgetBody =>
      'পুরনো উইজেটটা খুলে ফেলে আবার যোগ করুন — আজকের ও মাসের খরচ দেখাবে।';

  // ── v2.1.1: backup PIN ──
  @override
  String get pinUsePin => 'পিন দিয়ে আনলক';
  @override
  String get pinSheetTitle => 'ব্যাকআপ পিন লিখুন';
  @override
  String get pinSheetHint => '৪ ডিজিটের পিন';
  @override
  String get pinWrong => 'পিন মিলল না';
  @override
  String pinAttemptsLeft(int n) => '$n বার চেষ্টা বাকি';
  @override
  String get pinTryFingerprint => 'ফিঙ্গারপ্রিন্ট ব্যবহার করুন';
  @override
  String get pinSetTitle => 'ব্যাকআপ পিন দিন';
  @override
  String get pinSetBody =>
      'ফিঙ্গারপ্রিন্ট কাজ না করলে বা পড়লে এই পিন দিয়ে মানিব্যাগ আনলক করতে পারবেন।';
  @override
  String get pinConfirmTitle => 'পিনটি আবার লিখুন';
  @override
  String get pinMismatch => 'দুটো পিন মেলেনি — আবার চেষ্টা করুন';
  @override
  String get pinSaved => 'ব্যাকআপ পিন সেভ হয়েছে';
  @override
  String get pinSkip => 'এখন না';
  @override
  String get pinManage => 'ব্যাকআপ পিন';
  @override
  String get pinManageHelp => 'ফিঙ্গারপ্রিন্ট না কাজ করলে এই পিন লাগবে';
  @override
  String pinStatusSet(String v) => 'সেট করা আছে ····$v';
  @override
  String get pinRemove => 'পিন মুছে ফেলুন';
  @override
  String get pinRemoveConfirm => 'ব্যাকআপ পিন মুছে ফেলবেন? তারপর শুধু ফিঙ্গারপ্রিন্ট/ডিভাইস লক দিয়ে আনলক হবে।';
  @override
  String get pinRemoved => 'ব্যাকআপ পিন মুছে গেছে';
  @override
  String get pinEnter4 => '৪ ডিজিটের পিন দিন';
}

class _EnStrings extends MbStrings {
  const _EnStrings();

  @override
  String get appName => 'MoneyBag';
  @override
  String get tagline => 'Track your money. Understand your spending. Build your savings.';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get done => 'Done';
  @override
  String get ok => 'OK';
  @override
  String get next => 'Next';
  @override
  String get back => 'Back';
  @override
  String get skip => 'Skip';
  @override
  String get start => 'Get started';
  @override
  String get continueLabel => 'Continue';
  @override
  String get confirm => 'Confirm';
  @override
  String get all => 'All';
  @override
  String get expense => 'Expense';
  @override
  String get income => 'Income';
  @override
  String get today => 'Today';
  @override
  String get searchHint => 'Search (note or category)';
  @override
  String get error => 'Something went wrong';
  @override
  String get retry => 'Try again';
  @override
  String get empty => 'Empty';
  @override
  String get seeAll => 'See all';
  @override
  String get amount => 'Amount';
  @override
  String get note => 'Note';
  @override
  String get noteHint => 'What was it for? e.g. rickshaw fare, groceries';
  @override
  String get date => 'Date';
  @override
  String get category => 'Category';
  @override
  String get select => 'Select';
  @override
  String get none => 'None';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';

  @override
  String get ob1Title => 'Welcome to MoneyBag';
  @override
  String get ob1Body => 'Your daily expenses, income and savings — all in one place.';
  @override
  String get ob2Title => 'Track expenses';
  @override
  String get ob2Body => 'Chai or groceries — log a transaction in seconds.';
  @override
  String get ob3Title => 'Stay within budget';
  @override
  String get ob3Body => 'Set monthly budgets per category and get warned before you cross the line.';
  @override
  String get ob4Title => 'Reach savings goals';
  @override
  String get ob4Body => 'Feed your piggy bank and stay on track toward your goals.';
  @override
  String get ob5Title => 'Get smart insights';
  @override
  String get ob5Body => 'See where your money goes and how much you save — at a glance.';
  @override
  String get ob6Title => 'Your data stays on your device';
  @override
  String get ob6Body => 'Nothing ever leaves your phone. Optionally take an encrypted backup.';

  @override
  String get setupTitle => 'Profile setup';
  @override
  String get setupSubtitle => 'Set it once, use it effortlessly';
  @override
  String get yourName => 'Your name';
  @override
  String get yourNameHint => 'e.g. Rahat';
  @override
  String get monthlyIncome => 'Monthly income (optional)';
  @override
  String get monthlyIncomeHint => 'e.g. 50000';
  @override
  String get monthlyIncomeHelp => 'Helps calculate your savings rate';
  @override
  String get languageLabel => 'Language';
  @override
  String get appearance => 'Theme';
  @override
  String get darkTheme => 'Dark';
  @override
  String get lightTheme => 'Light';
  @override
  String get setupCta => "Let's go";

  @override
  String get navHome => 'Home';
  @override
  String get navTransactions => 'Transactions';
  @override
  String get navBudget => 'Budget';
  @override
  String get navProfile => 'Profile';

  @override
  String get dashMonthIncome => 'Income (this month)';
  @override
  String get dashMonthExpense => 'Expenses (this month)';
  @override
  String get dashNetSavings => 'Net savings';
  @override
  String get dashSavingsRate => 'Savings rate';
  @override
  String get dashBudgetTitle => 'Budget overview';
  @override
  String get dashBudgetLeft => 'left';
  @override
  String get dashBudgetOver => 'over limit';
  @override
  String get dashBudgetNone => 'No budget set yet';
  @override
  String get dashRecent => 'Recent transactions';
  @override
  String get dashTopCategories => 'Top categories';
  @override
  String get dashThisMonth => 'This month';
  @override
  String get noTransactions => 'No transactions yet';
  @override
  String get noTransactionsHint => 'Add your first transaction to get started';
  @override
  String get addFirstTransaction => 'Add transaction';
  @override
  String get setBudgetCta => 'Set a budget';
  @override
  String get todaySummaryTitle => "Today's summary";
  @override
  String get todaySummaryNoTx => 'No transactions yet today';
  @override
  String get todaySummaryNoTxHint =>
      'Add an expense or income to see today here';
  @override
  String get todayAdd => 'Add';
  @override
  String get todayNet => 'Net';
  @override
  String todaySavedToday(String amount) => 'Great! You saved $amount today';
  @override
  String get todayOverspent => 'Today you spent more than you earned';
  @override
  String todayExpenseOnly(String amount) => '$amount spent today';
  @override
  String todaySafeToSpend(String amount) => 'Safe to spend today: $amount';

  @override
  String get txTitle => 'Transactions';
  @override
  String get txSearchHint => 'Search…';
  @override
  String get txFiltersAll => 'All';
  @override
  String get txFiltersExpense => 'Expense';
  @override
  String get txFiltersIncome => 'Income';
  @override
  String get txDayTotal => 'Day total';
  @override
  String get txDeleted => 'Transaction deleted';
  @override
  String get txEmptyFiltered => 'Nothing matches this filter';
  @override
  String get txCountOne => '1 transaction';
  @override
  String txCountMany(int n) => '$n transactions';

  @override
  String get txAddExpense => 'Add expense';
  @override
  String get txAddIncome => 'Add income';
  @override
  String get txEditTitle => 'Edit transaction';
  @override
  String get txAmountHint => '0';
  @override
  String get txSelectCategory => 'Pick a category';
  @override
  String get txDeleteConfirm => 'Delete transaction?';
  @override
  String get txDeleteConfirmBody => 'This cannot be undone.';
  @override
  String get txSaved => 'Saved';
  @override
  String get txAmountRequired => 'Enter an amount';
  @override
  String get txNoteFor => 'Note';
  @override
  String get txFrequentAmounts => 'Frequent amounts';
  @override
  String get txRecentNotes => 'Past notes';

  // v2.2.3 — category OR note requirement (en)
  @override
  String get txCategoryOrNote =>
      'Pick a category or write what it was for above';

  // v2.2.5 — free-text category box
  @override
  String get txWhatForExpenseLabel => 'What did you spend on?';
  @override
  String get txWhatForIncomeLabel => 'What was the income for?';
  @override
  String get txWhatForHint =>
      'e.g. rickshaw fare, tea, groceries — saved as the category';
  @override
  String get txWhatForHelper =>
      'Typed here it becomes the category — no picking needed below';
  @override
  String get txCategoryOptional => 'Optional when the box above is filled';

  @override
  String get budgetTitle => 'Budget';
  @override
  String get budgetOverall => 'Overall';
  @override
  String get budgetOverallCard => 'Monthly overall budget';
  @override
  String get budgetByCategory => 'Category budgets';
  @override
  String get budgetSpent => 'Spent';
  @override
  String get budgetOf => 'of';
  @override
  String get budgetLeftShort => 'left';
  @override
  String get budgetOverShort => 'over';
  @override
  String get budgetSet => 'Set budget';
  @override
  String get budgetEdit => 'Edit budget';
  @override
  String get budgetEmpty => 'No budgets yet';
  @override
  String get budgetEmptyHint => 'Start with a monthly limit';
  @override
  String get budgetOverallHint =>
      'One monthly limit across all categories — keep total spend in check';
  @override
  String get budgetCategoryHint =>
      'A separate limit per category — food, transport, bills tracked on their own';
  @override
  String get budgetAddFirst => 'Add budget';
  @override
  String get budgetLimitLabel => 'Budget limit';
  @override
  String get budgetLimitHint => 'e.g. 30000';
  @override
  String get budgetForLabel => 'For';
  @override
  String get budgetOverallOption => 'Overall (all expenses)';
  @override
  String get budgetRollover => 'Roll over unused amount';
  @override
  String get budgetRolloverHint => "This month's leftover adds to next month";
  @override
  String get budgetAlertLabel => 'Alert threshold (85% default)';
  @override
  String get budgetAlertHelp => 'Warns on Home at 85% of the limit';
  @override
  String get budgetOverBody => 'Budget limit exceeded!';
  @override
  String get budgetNearBody => 'Close to your budget limit';
  @override
  String get budgetSaved => 'Budget saved';
  @override
  String get budgetDelete => 'Delete budget';

  // v2.2.3 — budget sheet category fallback (en)
  @override
  String get budgetNoCategories => 'No expense categories';
  @override
  String get budgetManageCategories => 'Add categories';

  @override
  String get analyticsTitle => 'Analytics';
  @override
  String get anThisMonth => 'This month';
  @override
  String get anLastMonth => 'Last month';
  @override
  String get anThisYear => 'This year';
  @override
  String get anSpendingByCategory => 'Spending by category';
  @override
  String get anWeeklySpend => 'Weekly spend';
  @override
  String get anMonthlyTrend => 'Monthly trend (6 months)';
  @override
  String get anIncomeVsExpense => 'Income vs expense';
  @override
  String get anTopSpending => 'Top spending';
  @override
  String get anInsights => 'Insights';
  @override
  String get anNoData => 'Not enough data';
  @override
  String get anNoDataHint => 'Add a few transactions to see charts';
  @override
  String get anShare => 'See all';

  @override
  String get savingsTitle => 'Savings';
  @override
  String get savingsTotalSaved => 'Total saved';

  @override
  String get savingsMonthNet => 'This month';

  @override
  String get savingsInGoals => 'Saved in goals';

  @override
  String goalsCountMany(int n) => '$n goals';
  @override
  String get goalsTitle => 'Savings goals';
  @override
  String get goalsActive => 'Active goals';
  @override
  String get goalsEmpty => 'No goals yet';
  @override
  String get goalsEmptyHint => 'Create a goal to start saving';
  @override
  String get goalAdd => 'Add goal';
  @override
  String get goalEdit => 'Edit goal';
  @override
  String get goalName => 'Goal name';
  @override
  String get goalNameHint => 'e.g. New phone';
  @override
  String get goalTarget => 'Target amount';
  @override
  String get goalTargetHint => 'e.g. 25000';
  @override
  String get goalTargetDate => 'Target date';
  @override
  String get goalTargetDateOptional => 'optional';
  @override
  String get goalTargetReached => '🎉 Goal reached!';
  @override
  String get goalProgressOf => 'of';
  @override
  String get goalContribute => 'Contribute';
  @override
  String get goalContributeTitle => 'Add to savings';
  @override
  String get goalWithdraw => 'Withdraw';
  @override
  String get goalHistory => 'History';
  @override
  String get goalNoHistory => 'No contributions yet';
  @override
  String get goalSavedOn => 'Saved on';
  @override
  String get goalDelete => 'Delete goal';
  @override
  String get goalDeleteBody => 'The goal and all its contributions will be removed.';
  @override
  String get goalMarkComplete => 'Mark complete';
  @override
  String get goalCompletedBadge => 'Done';
  @override
  String get goalContributionAdded => 'Added';
  @override
  String get goalNeedMore => 'left';
  @override
  String get goalNoTargetDate => 'No date';
  @override
  String get goalDaysLeft => 'days left';
  @override
  String get goalOverdue => 'Overdue';

  @override
  String get categoriesTitle => 'Categories';
  @override
  String get catExpenseTab => 'Expense';
  @override
  String get catIncomeTab => 'Income';
  @override
  String get catAdd => 'Add category';
  @override
  String get catEdit => 'Edit category';
  @override
  String get catName => 'Name';
  @override
  String get catNameHint => 'e.g. Coffee';
  @override
  String get catIcon => 'Icon';
  @override
  String get catColor => 'Color';
  @override
  String get catTxUsed => 'transactions use this';
  @override
  String get catDeleteConfirm => 'Delete category?';
  @override
  String get catDeleteBody => 'The category will be removed. Its transactions stay (without a category).';
  @override
  String get catDeleteBlock => 'This category has transactions — cannot delete';
  @override
  String get catSaved => 'Category saved';
  @override
  String get catNameRequired => 'Enter a name';

  @override
  String get profileTitle => 'Profile';
  @override
  String get settingsSectionGeneral => 'General';
  @override
  String get settingsLanguage => 'Language';
  @override
  String get settingsBangla => 'বাংলা';
  @override
  String get settingsEnglish => 'English';
  @override
  String get settingsTheme => 'Theme';
  @override
  String get settingsDark => 'Dark';
  @override
  String get settingsLight => 'Light';
  @override
  String get settingsSystem => 'System';
  @override
  String get settingsBnDigits => 'Bengali numerals';
  @override
  String get settingsBnDigitsHelp => 'Show amounts like ৳1,250 in Bengali digits';
  @override
  String get settingsSectionAlerts => 'Alerts';
  @override
  String get settingsBudgetAlerts => 'Budget alerts';
  @override
  String get settingsBudgetAlertsHelp => 'Banner on Home when a budget passes 85%';
  @override
  String get settingsWeeklySummary => 'Weekly summary';
  @override
  String get settingsWeeklySummaryHelp => "Show this week's spending summary on Home";
  @override
  String get settingsSectionData => 'Data';
  @override
  String get settingsExportCsv => 'Export CSV';
  @override
  String get settingsExportCsvHelp => 'Save/share all transactions as a file';
  @override
  String get settingsBackup => 'Encrypted backup';
  @override
  String get settingsBackupHelp => 'Create a passphrase-protected backup';
  @override
  String get settingsRestore => 'Restore backup';
  @override
  String get settingsRestoreHelp => 'Bring data back from a .mbbak file';
  @override
  String get settingsCategories => 'Manage categories';
  @override
  String get settingsCategoriesHelp => 'Add/edit custom categories';
  @override
  String get settingsSectionAbout => 'About';
  @override
  String get settingsPrivacyTitle => 'Privacy';
  @override
  String get settingsPrivacyBody => 'MoneyBag keeps everything on your device only. Nothing is ever sent to a server. It never asks for bank accounts or passwords — it is purely a record-keeping app.';
  @override
  String get settingsVersion => 'Version';
  @override
  String get settingsReset => 'Reset all data';
  @override
  String get settingsResetConfirm => 'Erase all data?';
  @override
  String get settingsResetBody => 'All transactions, budgets, goals and settings will be erased. This cannot be undone.';
  @override
  String get settingsResetDone => 'Reset complete';
  @override
  String get settingsExported => 'Exported';
  @override
  String get settingsExportFail => 'Export failed';

  @override
  String get backupTitle => 'Backup';
  @override
  String get backupIntro => 'Create an encrypted copy of all your data. AES-256 protected — nobody can open it without your passphrase.';
  @override
  String get backupPassphrase => 'Passphrase';
  @override
  String get backupPassphraseHint => 'At least 6 characters';
  @override
  String get backupPassphraseRepeat => 'Repeat passphrase';
  @override
  String get backupCreate => 'Create backup';
  @override
  String get backupCreating => 'Backing up…';
  @override
  String get backupCreatedTitle => 'Backup created';
  @override
  String get backupCreatedBody => 'File saved — use the button below to share/keep it';
  @override
  String get backupShare => 'Share file';
  @override
  String get backupDone => 'Done';
  @override
  String get backupPassShort => 'Passphrase must be at least 6 characters';
  @override
  String get backupPassMismatch => 'Passphrases do not match';
  @override
  String get backupRestoreTitle => 'Restore backup';
  @override
  String get backupRestoreIntro => 'Pick a MoneyBag backup (.mbbak) file';
  @override
  String get backupPickFile => 'Pick file';
  @override
  String get backupDecrypting => 'Unlocking file…';
  @override
  String get backupWrongPass => 'Wrong passphrase';
  @override
  String get backupInvalidFile => 'Not a MoneyBag backup file';
  @override
  String get backupCorruptFile => 'The file is corrupted';
  @override
  String get backupRestoreMode => 'Restore mode';
  @override
  String get backupModeReplace => 'Replace';
  @override
  String get backupModeReplaceHelp => 'Wipes current data and restores the backup';
  @override
  String get backupModeMerge => 'Merge';
  @override
  String get backupModeMergeHelp => 'Adds transactions from the backup';
  @override
  String get backupRestoreCta => 'Restore';
  @override
  String get backupRestoredTitle => 'Restore complete';
  @override
  String get backupRestoredBody => 'Your data has been brought back';
  @override
  String get backupFormatNote => 'Format: moneybag-backup-v1 · AES-256-GCM · PBKDF2';
  @override
  String get backupStats => 'The backup contains';

  @override
  String get notifBudgetTitle => 'Budget alert';
  @override
  String get notifWeeklyTitle => 'Weekly summary';
  @override
  String get notifBudgetBody => 'A budget passed 85%';
  @override
  String get notifWeeklyBody => "Check this week's spending";

  @override
  String get insTopCategoryT => 'Top spending area';
  @override
  String insTopCategoryB(String cat, String amt) => '$cat leads this month: $amt';
  @override
  String get insMoMUpT => 'Spending is up';
  @override
  String insMoMB(double pct) => '${pct.round()}% more than last month';
  @override
  String get insMoMDownT => 'Spending is down';
  @override
  String insMoMDownB(double pct) => '${pct.round()}% less than last month — great!';
  @override
  String get insSavingsRateT => 'Savings rate';
  @override
  String insSavingsRateB(double pct) => 'You saved ${pct.round()}% of income this month';
  @override
  String get insDailyAvgT => 'Daily average';
  @override
  String insDailyAvgB(String amt) => 'You spend $amt per day on average';
  @override
  String get insProjectedT => 'Month-end projection';
  @override
  String insProjectedB(String amt) => 'On this pace you may spend $amt this month';
  @override
  String get insBudgetWarnT => 'Budget warning';
  @override
  String insBudgetWarnB(String cat) => '$cat is close to its limit';
  @override
  String get insBudgetOverT => 'Budget exceeded';
  @override
  String insBudgetOverB(String cat) => '$cat has crossed its limit';
  @override
  String get insBiggestT => 'Biggest transaction';
  @override
  String insBiggestB(String amt, String cat) => 'Largest this month: $amt ($cat)';
  @override
  String get insNoSpendT => 'No-spend days';
  @override
  String insNoSpendB(int n) => '$n days without spending this month — well done!';
  @override
  String get insGreetingT => "Let's get started";
  @override
  String get insGreetingB => 'Add transactions and smart insights will appear here';
  @override
  String get insSpikeT => 'Category spike';
  @override
  String insSpikeB(String cat, double pct) =>
      '$cat is ${pct.round()}% above your 3-month average';

  @override
  String get currencyLabel => 'Currency';
  @override
  String get appsNoData => 'No data';
  @override
  String get requiredField => 'This field is required';

  // ── profile photo (en) ──
  @override
  String get photoTitle => 'Profile photo';
  @override
  String get photoCamera => 'Camera';
  @override
  String get photoGallery => 'Gallery';
  @override
  String get photoRemove => 'Remove photo';
  @override
  String get photoTapHint => 'Tap to add a photo';

  // ── dashboard banner (en) ──
  @override
  String bannerBackupTitle(String when) => 'Backup · $when';
  @override
  String get bannerBackupBody => 'Encrypt and safeguard your data';
  @override
  String get bannerBackupCta => 'Back up';
  @override
  String get bannerSavingsTitle => 'Savings progress';
  @override
  String bannerSavingsBody(String rate) => 'You saved $rate of income this month';
  @override
  String get bannerSavingsCta => 'View';
  @override
  String get bannerGoalTitle => 'Goal update';
  @override
  String bannerGoalBody(String pct, String left) => 'Goal is $pct complete — $left to go';
  @override
  String get bannerGoalCta => 'See savings';
  @override
  String get bannerAddTxTitle => 'Today\'s record';
  @override
  String get bannerAddTxBody => 'Add today\'s income or expense for sharper insights';
  @override
  String get bannerAddTxCta => 'Add';

  // ── notifications (en) ──
  @override
  String get notifSettingsTitle => 'Notifications';
  @override
  String get notifDailyReminder => 'Daily reminder';
  @override
  String get notifDailyReminderHelp => 'A gentle evening nudge to log today\'s spending';
  @override
  String get notifDailyTime => 'Time';
  @override
  String get notifDenied => 'Notification permission was not granted';
  @override
  String notifDailyTitle(String time) => 'Log today\'s spending';
  @override
  String get notifDailyBody => 'Takes 1 minute — keep your records tidy';
  @override
  String notifWeeklyBodyLive(String spent) => 'Last 7 days spending: $spent';
  @override
  String get notifBudgetThresholdBody => 'A budget is near its limit';
  @override
  String notifBudgetOverBodyLive(String cat, String money) => '$cat budget exceeded ($money)';
  @override
  String notifBudgetNearBodyLive(String cat, String pct) => '$cat budget is at $pct';

  // ── Google Drive backup (en) ──
  @override
  String get driveTab => 'Google Drive';
  @override
  String get driveIntro => 'Encrypted backups live in a hidden app folder on your Google Drive — even Google can\'t read them';
  @override
  String get driveSignIn => 'Sign in with Google';
  @override
  String get driveSignOut => 'Sign out';
  @override
  String get driveSignedInAs => 'Signed in as';
  @override
  String get driveBackupNow => 'Back up to Drive';
  @override
  String get driveBackups => 'Backups on Drive';
  @override
  String get driveNoBackups => 'No backups yet';
  @override
  String get driveUploading => 'Uploading…';
  @override
  String get driveUploaded => 'Backup uploaded to Drive';
  @override
  String get driveDeleting => 'Deleting…';
  @override
  String get driveRestoreFailed => 'Download failed';
  @override
  String get driveSetupNeeded => 'Drive setup needed';
  @override
  String get driveSetupNeededBody => 'One-time setup unlocks direct-to-Drive backup:';
  @override
  String get driveSetupStep1 => 'Create a Web OAuth Client ID in Google Cloud Console';
  @override
  String get driveSetupStep2 => 'Add this app\'s SHA-1 fingerprint there';
  @override
  String get driveSetupStep3 => 'Paste the ID into lib/core/config.dart and rebuild';
  @override
  String get driveShareAlt => 'Share backup';
  @override
  String get driveShareAltHelp => 'Pick Drive from the share sheet to save it';
  @override
  String get driveLastBackupNever => 'Never backed up';
  @override
  String get driveLoadMore => 'More';

  @override
  String get photoGoogleHint => 'Your Google photo and name are set — tap to change them';

  // ── login (en) ──
  @override
  String get loginSubtitle => 'Your money, in your hands';
  @override
  String get loginWithGoogle => 'Sign in with Google';
  @override
  String get loginContinueWithout => 'Continue without signing in';
  @override
  String get loginPrivacyNote =>
      'Sign-in fills your name & photo automatically and enables one-tap Drive backup. Every feature works without it too — your data stays on your phone.';
  @override
  String get loginSetupTitle => 'Google sign-in needs setup';
  @override
  String get loginSetupBody =>
      'Paste a Web OAuth Client ID into lib/core/config.dart to enable Google sign-in (the same ID powers Drive backup). You can continue without it for now.';
  @override
  String get loginFailed => 'Sign-in failed';

  // ── account (en) ──
  @override
  String get accountSection => 'Account';
  @override
  String get accountSignedInHelp => 'Signed in with Google';
  @override
  String get accountGuest => 'Not signed in';
  @override
  String get accountSignIn => 'Sign in with Google';
  @override
  String get accountSignOut => 'Sign out';

  // ── announcements / ads (en) ──
  @override
  String get announcementLabel => 'Notice';
  @override
  String get announcementDismiss => 'Got it';
  @override
  String get adLabel => 'Ad';

  // ── notification center (v2, en) ──
  @override
  String get notifCenterTitle => 'Notifications';
  @override
  String get notifSectionReminders => 'Reminders';
  @override
  String get notifSectionStatus => 'Status';
  @override
  String get notifSectionNotices => 'Notices & push';
  @override
  String get notifCenterEmpty => 'No active notifications right now';
  @override
  String get notifDailyScheduledFail => 'Not scheduled — set the time again';
  @override
  String notifStatusAllOk(int n) =>
      (n == 1 ? 'All good · 1 active reminder' : 'All good · $n active reminders');
  @override
  String get notifLastError => 'Reason';
  @override
  String get notifPushLabel => 'Real-time push';
  @override
  String get notifPushOn => 'On';
  @override
  String get notifResync => 'Re-sync now';

  // v2.2.3 — smart notifications + device health (en)
  @override
  String get notifSmartToggle => 'Smart notifications';
  @override
  String get notifSmartHelp =>
      'Reminders carry your real numbers (yesterday, this month, budget)';
  @override
  String get notifTestBtn => 'Send a test notification';
  @override
  String get notifTestHelp => 'Check instantly whether notifications arrive';
  @override
  String get notifTestSent => 'Test notification sent';
  @override
  String notifSmartYesterday(String spent) => 'Yesterday $spent';
  @override
  String notifSmartMonth(String spent) => 'This month $spent';
  @override
  String notifSmartLeft(String left) => 'Budget left $left';
  @override
  String get notifPermWarning => 'Notifications are turned off';
  @override
  String get notifPermHelp =>
      'Reminders cannot show without permission — enable them in Settings';
  @override
  String get notifPermAction => 'Turn on';
  @override
  String get notifBatteryTitle => 'Battery saver silences reminders';
  @override
  String get notifBatteryHelp =>
      'The top cause of dead background alarms — allowing it keeps reminders alive';
  @override
  String get notifBatteryAction => 'Allow';

  // ── rewarded ads / support (v2, en) ──
  @override
  String get rewardedSection => 'Support';
  @override
  String get rewardedTitle => 'Stay ad-free';
  @override
  String get rewardedBody =>
      'Watch one rewarded ad and enjoy 1 hour completely ad-free.';
  @override
  String get rewardedWatch => 'Watch rewarded ad';
  @override
  String get rewardedGranted => 'Ads are off for the next 1 hour!';
  @override
  String get rewardedLeftMins(int mins) => 'Ad-free active — $mins m left';
  @override
  String get rewardedFailed => 'Ad failed to load — try again in a bit';
  @override
  String get rewardedLoading => 'Loading ad…';
  @override
  String get maintenancePopupTitle => 'Support App Maintenance';
  @override
  String get maintenancePopupBody => 'Please support us to maintain the app. Watch one rewarded ad and enjoy 1 hour completely ad-free.';

  // ── auto Drive sync (v2, en) ──
  @override
  String get autoSyncTitle => 'Auto sync (Google Drive)';
  @override
  String get autoSyncHelp =>
      '5 seconds after each save/delete, an encrypted backup silently goes to Drive';
  @override
  String get autoSyncLastNever => 'Last auto backup: never';
  @override
  String get autoSyncRemember => 'Remember passphrase (for auto sync)';
  @override
  String get autoSyncRememberHelp =>
      'Stored on this device only — used for auto backup & auto restore';
  @override
  String get autoSyncNow => 'Back up now';
  @override
  String get autoSyncSyncing => 'Syncing…';
  @override
  String get autoRestoreChecking => 'Looking for your Drive backup…';
  @override
  String autoRestoreDone(int txCount) =>
      'Drive backup restored ($txCount transactions are back)';
  @override
  String get autoRestoreNeedPassTitle => 'Backup found!';
  @override
  String get autoRestoreNeedPassHelp =>
      'Your encrypted backup is on Drive. Enter the passphrase once — everything after that is automatic.';
  @override
  String get autoRestoreSkipLocal => 'This device already has data — auto-restore skipped';
  @override
  String get autoRestoreFailed => 'Could not restore the backup';

  // ── v2.1 smart features ──
  @override
  String get budgetSuggestAvg => "Last 3 months' average";
  @override
  String get budgetSuggestUse => 'Use this';
  @override
  String get budgetSuggestNoData => 'No spend history yet';
  @override
  String get insWeekendT => 'Weekend pattern';
  @override
  String insWeekendB(double pct) =>
      'Fri–Sat days cost you ${pct.round()}% more per day than weekdays';
  @override
  String get insBurnRateT => 'Budget pace';
  @override
  String insBurnRateB(String projected, String budget) =>
      'At this pace the month ends at $projected — inside your $budget budget';
  @override
  String get insBurnRateOverT => 'Fast pace';
  @override
  String insBurnRateOverB(String projected, String budget) =>
      'At this pace the month would end at $projected — over your $budget budget';
  @override
  String get scanReceipt => 'Scan receipt';
  @override
  String get scanningReceipt => 'Reading receipt…';
  @override
  String get ocrNoAmount => 'No amount found — try a clearer photo';
  @override
  String get ocrFound => 'Found on the receipt';
  @override
  String get ocrUse => 'Fill';
  @override
  String get lockTitle => 'MoneyBag is locked';
  @override
  String get lockSubtitle => 'Unlock to continue';
  @override
  String get lockUnlock => 'Unlock';
  @override
  String get lockFailed => 'Not recognized — try again';
  @override
  String get settingsBiometric => 'Fingerprint lock';
  @override
  String get settingsBiometricHelp =>
      'Lock MoneyBag with your fingerprint or device PIN';
  @override
  String get settingsBiometricUnsupported => 'Not available on this device';
  @override
  String get widgetToday => 'Today';
  @override
  String get widgetMonth => 'This month';
  @override
  String get widgetBudget => 'Budget';
  @override
  String get goalEtaLabel => 'At this pace';
  @override
  String goalEtaB(int months, String monthLabel) =>
      '$months months left → $monthLabel';
  @override
  String get goalEtaNoData => 'Save regularly to see the ETA';
  @override
  String get dupTitle => 'Save it again?';
  @override
  String dupBody(String money, String category) =>
      'You already saved $money in $category today.';
  @override
  String get dupSaveAnyway => 'Save anyway';
  @override
  String get dupGoBack => 'Go back';

  // ── v2.1.1: What's New guide ──
  @override
  String get guideTitle => "What's new";
  @override
  String get guideSubtitle => 'v2.1.2 — lock & widget fixes';
  @override
  String get guideStart => "Let's go";
  @override
  String get guideFpTitle => 'Fingerprint lock';
  @override
  String guideFpBody(String where) => 'Lock MoneyBag with your fingerprint or a backup PIN. $where';
  @override
  String get guideOcrTitle => 'Receipt scan';
  @override
  String guideOcrBody(String where) => 'Snap a receipt — the amount fills itself in. $where';
  @override
  String get guideBudgetTitle => 'Smart budget ideas';

  // v2.2.5 guide rows (en)
  @override
  String get guideCatBudgetTitle => 'Category budgets fixed';
  @override
  String get guideCatBudgetBody =>
      'The add-budget sheet now shows categories and saves them properly — the old bug turned every budget into the same overall one.';
  @override
  String get guideFreeCatTitle => 'Type it = category';
  @override
  String get guideFreeCatBody =>
      'Write what the money went for in the top box — the text itself saves as the category, no chip picking needed.';
  @override
  String guideBudgetBody(String where) => 'Suggests a limit from your last 3 months. $where';
  @override
  String get guideInsightTitle => 'Smart insights';
  @override
  String guideInsightBody(String where) => 'Spending pace and weekend patterns explained. $where';
  @override
  String get guideEtaTitle => 'Savings ETA';
  @override
  String guideEtaBody(String where) => 'See when your goal will be reached at this pace. $where';
  @override
  String get guideWidgetTitle => 'Home screen widget';
  @override
  String guideWidgetBody(String where) => "Today's and this month's spend at a glance. $where";
  @override
  String get guideWidgetWhere => 'Long-press home screen → Widgets → MoneyBag';
  @override
  String get guideMyTitle => 'Material You colors';
  @override
  String guideMyBody(String where) => 'On Android 12+ the app follows your wallpaper. $where';
  @override
  String get guideDupTitle => 'Duplicate warning';
  @override
  String guideDupBody(String where) => 'Asks before saving the same expense twice on one day. $where';

  // ── v2.1.2: fix announcements ──
  @override
  String get guideFixLockTitle => 'Lock now works properly';
  @override
  String get guideFixLockBody =>
      'Killing & reopening the app asks for your fingerprint or PIN again.';
  @override
  String get guideFixWidgetTitle => 'Widget now works properly';
  @override
  String get guideFixWidgetBody =>
      "Remove the old widget and add it again — it now shows today's and this month's spend.";

  // ── v2.1.1: backup PIN ──
  @override
  String get pinUsePin => 'Unlock with PIN';
  @override
  String get pinSheetTitle => 'Enter backup PIN';
  @override
  String get pinSheetHint => '4-digit PIN';
  @override
  String get pinWrong => 'Wrong PIN';
  @override
  String pinAttemptsLeft(int n) => '$n attempts left';
  @override
  String get pinTryFingerprint => 'Use fingerprint instead';
  @override
  String get pinSetTitle => 'Set a backup PIN';
  @override
  String get pinSetBody =>
      'If your fingerprint ever fails, unlock MoneyBag with this PIN.';
  @override
  String get pinConfirmTitle => 'Re-enter your PIN';
  @override
  String get pinMismatch => "PINs don't match — try again";
  @override
  String get pinSaved => 'Backup PIN saved';
  @override
  String get pinSkip => 'Not now';
  @override
  String get pinManage => 'Backup PIN';
  @override
  String get pinManageHelp => 'Used when fingerprint is unavailable';
  @override
  String pinStatusSet(String v) => 'Set ····$v';
  @override
  String get pinRemove => 'Remove PIN';
  @override
  String get pinRemoveConfirm =>
      'Remove the backup PIN? Only fingerprint / device lock will unlock afterwards.';
  @override
  String get pinRemoved => 'Backup PIN removed';
  @override
  String get pinEnter4 => 'Enter all 4 digits';
}
