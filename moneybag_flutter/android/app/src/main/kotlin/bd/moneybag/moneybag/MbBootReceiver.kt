package bd.moneybag.moneybag

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * v2.2.1 — repaints the home screen widget after a reboot or an app update.
 *
 * Why this exists: OEM launchers (MIUI/HyperOS, ColorOS, Realme UI…) often
 * drop a sideloaded (non-Play-Store) app's widget bind when the process is
 * killed or the phone reboots — the widget then sits on the launcher's blank
 * placeholder until the app is manually opened. This receiver repaints from
 * the LAST persisted snapshot (HomeWidgetPreferences) directly — no Flutter
 * engine, no database, ~1 ms of work.
 *
 * Registered for BOOT_COMPLETED and MY_PACKAGE_REPLACED (both protected
 * system broadcasts, only the OS can send them).
 */
class MbBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        try {
            val ids = MbWidgetProvider.placedIds(context)
            if (ids != null && ids.isNotEmpty()) {
                MbWidgetProvider.renderAll(
                    context,
                    AppWidgetManager.getInstance(context),
                    ids,
                    HomeWidgetPlugin.getData(context)
                )
            }
        } catch (_: Exception) {
            // Widget repaint is best-effort — never crash the boot receiver.
        }
    }
}
