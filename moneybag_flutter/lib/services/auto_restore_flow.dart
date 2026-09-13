import 'dart:async';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../services/auto_sync_service.dart';
import '../widgets/common.dart';

/// Runs right after a successful Google Sign-In:
///
/// ১ silent check — "Drive-এ ব্যাকআপ খোঁজা হচ্ছে…" (non-dismissable, quick
///    when there is nothing to do)
/// ২ auto-restore — when the device is empty and the passphrase is known,
///    everything happens with ZERO taps (download → decrypt → SQLite)
/// ৩ one-tap passphrase — fresh install with a backup on Drive: a single
///    inline dialog (never a trip to the backup screen), after which the
///    flow completes automatically and future logins restore silently.
Future<void> runAutoRestoreFlow(BuildContext context) async {
  final L = context.L;
  final nav = Navigator.of(context, rootNavigator: true);

  // Non-dismissable lightweight progress dialog (fire-and-forget).
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2.4),
            const SizedBox(width: 18),
            Flexible(
              child: Text(
                L.autoRestoreChecking,
                style: const TextStyle(fontFamily: 'NotoSansBengali'),
              ),
            ),
          ],
        ),
      ),
    ),
  ));

  final result = await MbAutoSyncService.instance.maybeAutoRestoreOnLogin();
  nav.pop(); // close the progress dialog

  if (!context.mounted) return;

  switch (result.status) {
    case MbAutoRestoreStatus.restored:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.autoRestoreDone(result.stats?.transactions ?? 0)),
          backgroundColor: MbPalette.greenDeep,
        ),
      );
      break;

    case MbAutoRestoreStatus.needsPassphrase:
      await _askPassphraseAndRestore(context);
      break;

    case MbAutoRestoreStatus.failed:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.autoRestoreFailed)),
      );
      break;

    default:
      // notConfigured / notSignedIn / noBackup / localDataPresent — silent.
      break;
  }
}

Future<void> _askPassphraseAndRestore(BuildContext context) async {
  final L = context.L;
  final ctl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(L.autoRestoreNeedPassTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.autoRestoreNeedPassHelp,
            style: const TextStyle(
                fontFamily: 'NotoSansBengali', fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctl,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(hintText: L.backupPassphraseHint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(L.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(L.settingsRestore),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final pass = ctl.text;
  if (pass.length < 6) return;

  // Restore (and remember the passphrase so everything is automatic later).
  final result = await MbAutoSyncService.instance.restoreNewestWith(pass);
  if (!context.mounted) return;
  if (result.status == MbAutoRestoreStatus.restored) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.autoRestoreDone(result.stats?.transactions ?? 0)),
        backgroundColor: MbPalette.greenDeep,
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.autoRestoreFailed)),
    );
  }
}
