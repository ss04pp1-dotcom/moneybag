import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/palette.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';

/// One-time profile setup after onboarding.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _income = TextEditingController();
  MbLanguage _lang = MbLanguage.bangla;
  ThemeMode _theme = ThemeMode.dark;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the Google profile when the user just signed in.
    final state = context.read<MbAppState>();
    _name.text = state.userName;
    _lang = state.language;
  }

  @override
  void dispose() {
    _name.dispose();
    _income.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.L.requiredField)),
      );
      return;
    }
    setState(() => _busy = true);
    final incomeTaka = MbFormat.parseAmount(_income.text);
    final incomeMinor =
        incomeTaka == null || incomeTaka <= 0 ? null : (incomeTaka * 100).round();
    final state = context.read<MbAppState>();
    await state.completeSetup(
      name: name,
      incomeMinor: incomeMinor,
      lang: _lang,
      mode: _theme,
    );
    // Setup done → switch the 2 auto notifications on for real: ask the
    // one-time system permission and schedule daily + weekly reminders.
    await MbNotifications.instance.init();
    await MbNotifications.instance.ensureAutoEnable(state);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<MbAppState>();

    return Scaffold(
      appBar: AppBar(title: Text(L.setupTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              L.setupSubtitle,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Optional profile photo — camera / gallery.
            Center(
              child: Column(
                children: [
                  const MbAvatar(size: 88),
                  const SizedBox(height: 6),
                  Text(
                    state.googleLinked
                        ? L.photoGoogleHint
                        : L.photoTapHint,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name
            Text(L.yourName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: L.yourNameHint),
            ),
            const SizedBox(height: 20),

            // Income
            Text(L.monthlyIncome,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _income,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: L.monthlyIncomeHint,
                prefixText: '৳ ',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              L.monthlyIncomeHelp,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // Language
            Text(L.languageLabel,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _choice(
                    label: 'বাংলা',
                    selected: _lang == MbLanguage.bangla,
                    onTap: () => setState(() => _lang = MbLanguage.bangla),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _choice(
                    label: 'English',
                    selected: _lang == MbLanguage.english,
                    onTap: () => setState(() => _lang = MbLanguage.english),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Theme
            Text(L.appearance,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _choice(
                    label: L.darkTheme,
                    icon: Icons.dark_mode_rounded,
                    selected: _theme == ThemeMode.dark,
                    onTap: () => setState(() => _theme = ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _choice(
                    label: L.lightTheme,
                    icon: Icons.light_mode_rounded,
                    selected: _theme == ThemeMode.light,
                    onTap: () => setState(() => _theme = ThemeMode.light),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Live currency preview
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${L.currencyLabel}: ${MbFormat.money(123455, bengaliDigits: _lang == MbLanguage.bangla)}',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _finish,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(L.setupCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? MbPalette.green.withOpacity(0.16) : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? MbPalette.green : scheme.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 18,
                  color: selected ? MbPalette.green : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? MbPalette.green : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
