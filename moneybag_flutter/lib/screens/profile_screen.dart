import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/palette.dart';
import '../services/ads_service.dart';
import '../services/auto_restore_flow.dart';
import '../services/remote_config_service.dart';
import '../services/csv_service.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/google_logo.dart';
import '../widgets/pin_setup_sheet.dart';
import 'backup_screen.dart';
import 'categories_screen.dart';
import 'notifications_screen.dart';

/// Profile — settings hub: general, alerts, data, about, reset.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
          // ── Header ──
          MbFadeSlideIn(
            index: 0,
            child: Row(
            children: [
              // Profile photo — tap to change (camera / gallery / remove).
              const MbScaleIn(child: MbAvatar(size: 68)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.userName.isEmpty ? L.appName : state.userName,
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${state.transactions.length} ${L.txCountMany(state.transactions.length)}'
                      ' · ${L.currencyLabel}: BDT ৳',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _editName(context, state),
              ),
            ],
          ),
          ),
          const SizedBox(height: 24),

          // ── Account (Google) ──
          _Section(label: L.accountSection),
          const MbFadeSlideIn(index: 1, child: _AccountCard()),
          const SizedBox(height: 20),

          // ── General ──
          _Section(label: L.settingsSectionGeneral),
          MbFadeSlideIn(
            index: 2,
            child: MbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Language
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(L.settingsLanguage),
                  trailing: SegmentedButton<MbLanguage>(
                    segments: const [
                      ButtonSegment(value: MbLanguage.bangla, label: Text('বাং')),
                      ButtonSegment(
                          value: MbLanguage.english, label: Text('EN')),
                    ],
                    selected: {state.language},
                    onSelectionChanged: (s) => state.setLanguage(s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                  ),
                ),
                Divider(color: scheme.outlineVariant, height: 1),
                // Theme
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(L.settingsTheme),
                  trailing: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(L.settingsDark)),
                      ButtonSegment(value: 1, label: Text(L.settingsLight)),
                    ],
                    selected: {
                      state.themeMode == ThemeMode.light ? 1 : 0
                    },
                    onSelectionChanged: (s) => state.setThemeMode(
                        s.first == 1 ? ThemeMode.light : ThemeMode.dark),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                  ),
                ),
                Divider(color: scheme.outlineVariant, height: 1),
                // Bengali digits
                SwitchListTile(
                  secondary: const Icon(Icons.translate_rounded),
                  title: Text(L.settingsBnDigits),
                  subtitle: Text(L.settingsBnDigitsHelp),
                  value: state.bengaliDigits,
                  onChanged: state.setBengaliDigits,
                ),
                Divider(color: scheme.outlineVariant, height: 1),
                // Monthly income
                ListTile(
                  leading: const Icon(Icons.payments_rounded),
                  title: Text(L.monthlyIncome),
                  subtitle: Text(state.monthlyIncomeMinor == null
                      ? '—'
                      : MbFormat.money(state.monthlyIncomeMinor!,
                          bengaliDigits: state.bengaliDigits)),
                  trailing: const Icon(Icons.edit_rounded, size: 19),
                  onTap: () => _editIncome(context, state),
                ),
                // v2.1: fingerprint lock (hidden when unsupported)
                const _BioLockTile(),
              ],
            ),
          ),
          ),
          const SizedBox(height: 20),

          // ── Alerts ──
          _Section(label: L.settingsSectionAlerts),
          MbFadeSlideIn(
            index: 3,
            child: MbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_rounded),
                  title: Text(L.settingsBudgetAlerts),
                  subtitle: Text(L.settingsBudgetAlertsHelp),
                  value: state.budgetAlerts,
                  onChanged: state.setBudgetAlerts,
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 20),

          // ── Notifications (system) ──
          _Section(label: L.notifSettingsTitle),
          MbFadeSlideIn(
            index: 4,
            child: MbCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: Text(L.notifCenterTitle),
              subtitle: Text(
                '${state.dailyReminder ? L.notifDailyReminder : ''}'
                '${state.dailyReminder && state.weeklySummary ? ' · ' : ''}'
                '${state.weeklySummary ? L.settingsWeeklySummary : ''}',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => MbNav.push(context, const NotificationsScreen()),
            ),
          ),
          ),
          const SizedBox(height: 20),

          // ── Support (rewarded ads → 24h ad-free) ──
          const MbFadeSlideIn(index: 5, child: _SupportCard()),
          const SizedBox(height: 20),
          _Section(label: L.settingsSectionData),
          MbFadeSlideIn(
            index: 6,
            child: MbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_view_rounded),
                  title: Text(L.settingsExportCsv),
                  subtitle: Text(L.settingsExportCsvHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    try {
                      final csv = MbCsvService(state);
                      await csv.exportAndShare();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${L.settingsExportFail}: $e')));
                      }
                    }
                  },
                ),
                Divider(color: scheme.outlineVariant, height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_rounded),
                  title: Text(L.settingsBackup),
                  subtitle: Text(L.settingsBackupHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => MbNav.push(context, const BackupScreen()),
                ),
                Divider(color: scheme.outlineVariant, height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: Text(L.settingsRestore),
                  subtitle: Text(L.settingsRestoreHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => MbNav.push(context, const BackupScreen()),
                ),
                Divider(color: scheme.outlineVariant, height: 1),
                ListTile(
                  leading: const Icon(Icons.category_rounded),
                  title: Text(L.settingsCategories),
                  subtitle: Text(L.settingsCategoriesHelp),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => MbNav.push(context, const CategoriesScreen()),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 20),

          // ── About ──
          _Section(label: L.settingsSectionAbout),
          MbFadeSlideIn(
            index: 7,
            child: MbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MbPalette.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('৳',
                            style: TextStyle(
                                color: Color(0xFF06130C), fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(L.appName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      '${L.settingsVersion} ${MbConfig.appVersion}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  L.tagline,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  L.settingsPrivacyBody,
                  style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12.5,
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 20),

          // ── Danger zone ──
          MbFadeSlideIn(
            index: 8,
            child: MbCard(
            color: scheme.errorContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: 8),
                    Text(L.settingsReset,
                        style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  L.settingsResetBody,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                  ),
                  onPressed: () => _resetAll(context, state),
                  child: Text(L.settingsReset),
                ),
              ],
            ),
          ),
          ),
        ],
        ),
      ),
    );
  }

  void _editName(BuildContext context, MbAppState state) {
    final ctl = TextEditingController(text: state.userName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.L.yourName),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(context.L.cancel)),
          FilledButton(
            onPressed: () async {
              await state.setUserName(ctl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(context.L.save),
          ),
        ],
      ),
    );
  }

  void _editIncome(BuildContext context, MbAppState state) {
    final ctl = TextEditingController(
      text: state.monthlyIncomeMinor == null
          ? ''
          : (state.monthlyIncomeMinor! / 100).toStringAsFixed(0),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.L.monthlyIncome),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '৳ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(context.L.cancel)),
          FilledButton(
            onPressed: () async {
              final v = MbFormat.parseAmount(ctl.text);
              await state
                  .setMonthlyIncome(v == null ? null : (v * 100).round());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(context.L.save),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAll(BuildContext context, MbAppState state) async {
    final L = context.L;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.settingsResetConfirm),
        content: Text(L.settingsResetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MbPalette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.confirm),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.resetAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.settingsResetDone)));
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Account card — Google sign-in / sign-out (the only login method).
class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _busy = false;

  Future<void> _signIn() async {
    final state = context.read<MbAppState>();
    final L = context.L;

    if (state.googleLinked) return;
    if (!MbConfig.driveConfigured) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(L.loginSetupTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L.loginSetupBody),
              const SizedBox(height: 12),
              Text('• ${L.driveSetupStep1}'),
              Text('• ${L.driveSetupStep2}'),
              Text('• ${L.driveSetupStep3}'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.ok),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await state.signInWithGoogle();
      if (!mounted) return;
      if (ok) {
        // Signed in from the profile: same auto-restore flow as the login
        // screen (checks Drive, restores when the device is empty).
        await runAutoRestoreFlow(context);
        if (mounted) setState(() => _busy = false);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${L.loginFailed} (${e.toString()})')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    if (state.googleLinked) {
      return MbCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  image: state.googlePhotoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(state.googlePhotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: state.googlePhotoUrl == null
                    ? const Center(child: MbGoogleG(size: 22))
                    : null,
              ),
              title: Text(
                state.googleName ?? state.googleEmail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                state.googleEmail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ),
            Divider(color: scheme.outlineVariant, height: 1),
            ListTile(
              leading: Icon(Icons.cloud_done_outlined,
                  color: scheme.primary, size: 22),
              title: Text(L.accountSignedInHelp,
                  style: const TextStyle(fontSize: 13)),
              dense: true,
            ),
            Divider(color: scheme.outlineVariant, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: MbPalette.danger),
              title: Text(L.accountSignOut,
                  style: const TextStyle(
                      color: MbPalette.danger, fontWeight: FontWeight.w700)),
              onTap: _busy ? null : () async => state.unlinkGoogle(),
            ),
          ],
        ),
      );
    }

    return MbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(L.accountGuest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            L.loginPrivacyNote,
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 12,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          MbPressable(
            pressedScale: 0.97,
            onTap: _busy ? null : _signIn,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  else ...[
                    const MbGoogleG(size: 21),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      L.accountSignIn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        color: Color(0xFF1F1F1F),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Support card — watch one rewarded ad, stay ad-free for 24 hours.
///
/// Shown only while the admin panel has ads enabled; while an ad-free
/// period is active it shows the remaining time instead.
class _SupportCard extends StatefulWidget {
  const _SupportCard();

  @override
  State<_SupportCard> createState() => _SupportCardState();
}

class _SupportCardState extends State<_SupportCard> {
  bool _busy = false;

  Future<void> _watch() async {
    if (_busy) return;
    final L = context.L;
    setState(() => _busy = true);
    try {
      final earned = await MbAdsService.instance.showRewarded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(earned ? L.rewardedGranted : L.rewardedFailed),
          backgroundColor: earned ? MbPalette.greenDeep : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([
        MbRemoteConfigService.instance,
        MbAdsService.instance,
      ]),
      builder: (context, _) {
        final ads = MbAdsService.instance;
        if (!ads.adsEnabled) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(label: L.rewardedSection),
            MbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: MbPalette.green.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        ads.adFreeActive
                            ? Icons.verified_rounded
                            : Icons.card_giftcard_rounded,
                        size: 20,
                        color: MbPalette.greenDeep,
                      ),
                    ),
                    title: Text(
                      L.rewardedTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      ads.adFreeActive
                          ? L.rewardedLeft(ads.adFreeRemainingHours)
                          : L.rewardedBody,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 12.5,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!ads.adFreeActive)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: MbPalette.green,
                            foregroundColor: const Color(0xFF06130C),
                          ),
                          onPressed: _busy ? null : _watch,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2),
                                )
                              : const Icon(Icons.play_circle_fill_rounded),
                          label: Text(
                              _busy ? L.rewardedLoading : L.rewardedWatch),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// v2.1 — Fingerprint / device-PIN app-lock switch.
///
/// Shown only when the device can actually authenticate (checked async at
/// build time — invisible while checking, gone entirely when unsupported).
/// Enabling runs one real authentication first, so the user can never trap
/// themselves with a lock that does not work.
class _BioLockTile extends StatefulWidget {
  const _BioLockTile();

  @override
  State<_BioLockTile> createState() => _BioLockTileState();
}

class _BioLockTileState extends State<_BioLockTile> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool? _supported; // null → still checking (render nothing)
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    try {
      final can = await _auth.isDeviceSupported() ||
          await _auth.canCheckBiometrics;
      if (mounted) setState(() => _supported = can);
    } catch (_) {
      if (mounted) setState(() => _supported = false);
    }
  }

  Future<void> _onChanged(bool v) async {
    final state = context.read<MbAppState>();
    final L = context.L;
    if (v) {
      // Verify once immediately — enabling must never create a broken lock.
      setState(() => _busy = true);
      try {
        final ok = await _auth.authenticate(
          localizedReason: L.settingsBiometricHelp,
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(L.lockFailed)));
          }
          return; // switch stays off
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(L.settingsBiometricUnsupported)));
        }
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    await state.setBiometricLock(v);

    // v2.1.1: right after enabling, offer a backup PIN once — this is the
    // guaranteed unlock path on OEM devices where the system biometric
    // prompt never offers the device credential fallback.
    if (v && !state.hasBackupPin && mounted) {
      final want = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(L.pinSetTitle),
          content: Text(L.pinSetBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.pinSkip),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L.pinManage),
            ),
          ],
        ),
      );
      if (want == true && mounted) {
        await showPinSetupSheet(context, state);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_supported != true) return const SizedBox.shrink();
    final state = context.watch<MbAppState>();
    final scheme = Theme.of(context).colorScheme;
    final L = context.L;
    return Column(
      children: [
        Divider(color: scheme.outlineVariant, height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint_rounded),
          title: Text(L.settingsBiometric),
          subtitle: Text(L.settingsBiometricHelp,
              style: const TextStyle(fontSize: 12)),
          value: state.biometricLock,
          onChanged: _busy ? null : _onChanged,
        ),
        // v2.1.1: backup PIN management (only while the lock is on).
        if (state.biometricLock) _pinManageTile(context, state, scheme, L),
      ],
    );
  }

  Widget _pinManageTile(
      BuildContext context, MbAppState state, ColorScheme scheme, MbStrings L) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.dialpad_rounded),
      title: Text(L.pinManage, style: const TextStyle(fontSize: 14.5)),
      subtitle: Text(
        state.hasBackupPin ? L.pinStatusSet('') : L.pinManageHelp,
        style: TextStyle(
          fontSize: 12,
          color: state.hasBackupPin ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: state.hasBackupPin ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      onTap: () => _managePin(context, state, L),
    );
  }

  Future<void> _managePin(
      BuildContext context, MbAppState state, MbStrings L) async {
    if (!state.hasBackupPin) {
      await showPinSetupSheet(context, state);
      return;
    }
    // Already set → change / remove.
    final change = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(L.pinManage),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'change'),
            child: Row(children: [
              const Icon(Icons.edit_rounded, size: 20),
              const SizedBox(width: 12),
              Text(L.pinManage),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'remove'),
            child: Row(children: [
              const Icon(Icons.delete_rounded, size: 20),
              const SizedBox(width: 12),
              Text(L.pinRemove),
            ]),
          ),
        ],
      ),
    );
    if (change == 'change' && context.mounted) {
      await showPinSetupSheet(context, state);
    } else if (change == 'remove' && context.mounted) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(L.pinRemove),
          content: Text(L.pinRemoveConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L.delete),
            ),
          ],
        ),
      );
      if (sure == true) {
        await state.clearBackupPin();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(L.pinRemoved)));
        }
      }
    }
  }
}
