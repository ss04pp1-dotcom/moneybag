import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/palette.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'pin_pad.dart';

/// v2.1.1 — Set / change the backup PIN (two stages: enter → confirm).
///
/// Dark modal bottom sheet in the MoneyBag lock style. Called right after
/// the fingerprint lock is enabled (offer dialog) and from Settings →
/// Backup PIN (change).
Future<void> showPinSetupSheet(BuildContext context, MbAppState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MbPalette.darkBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _PinSetupSheet(),
  );
}

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet();

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  int _stage = 0; // 0 = first entry, 1 = confirm
  String? _first;
  int _confirmFails = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.read<MbAppState>();
    final L = context.L;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 14),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded,
                    size: 22, color: MbPalette.darkText.withOpacity(0.6)),
              ),
            ),
          ),
          if (_stage == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                L.pinSetBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: MbThemes.fontFamily,
                  fontSize: 12.5,
                  height: 1.5,
                  color: MbPalette.darkText.withOpacity(0.65),
                ),
              ),
            ),
          const SizedBox(height: 10),
          MbPinPad(
            key: ValueKey('pin-setup-$_stage'),
            title: _stage == 0 ? L.pinSetTitle : L.pinConfirmTitle,
            hint: _stage == 1 ? L.pinEnter4 : L.pinSheetHint,
            onSubmit: (pin) async {
              if (_stage == 0) {
                _first = pin;
                setState(() => _stage = 1);
                return true;
              }
              if (pin == _first) {
                await state.setBackupPin(pin);
                if (!context.mounted) return true;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L.pinSaved)),
                );
                return true;
              }
              _confirmFails++;
              if (_confirmFails >= 3) {
                // Three mismatches → start over cleanly.
                _confirmFails = 0;
                _first = null;
                if (mounted) setState(() => _stage = 0);
              }
              return false;
            },
          ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}
