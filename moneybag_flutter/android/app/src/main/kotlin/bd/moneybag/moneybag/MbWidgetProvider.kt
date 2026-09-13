package bd.moneybag.moneybag

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * v2.2.1 — MoneyBag home screen widget (2x2).
 *
 * History of the "blank widget" bugs:
 * • v2.1.0/2.1.1 read the wrong SharedPreferences file → no data.
 * • v2.1.2 fixed the prefs source (extends the plugin's HomeWidgetProvider).
 * • v2.2.1 adds the missing RE-RENDER paths: [onRestored] (app update
 *   re-binds widget ids) and [MbBootReceiver] (repaints after reboot /
 *   package replace WITHOUT starting Flutter). OEM launchers (MIUI/HyperOS,
 *   ColorOS…) frequently drop a sideloaded app's widget bind while the
 *   process is dead — a native repaint is the only reliable recovery.
 *
 * Also new in v2.2.1: overall-budget progress row (label + spent/limit +
 * thin progress bar), fed by [bd.moneybag.moneybag MbWidgetSyncService].
 */
class MbWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        renderAll(context, appWidgetManager, appWidgetIds, widgetData)
    }

    /**
     * Called after the app is UPDATED (or the widget is restored): the
     * launcher hands us the NEW widget ids. Repaint immediately — otherwise
     * the widget can sit on its placeholder layout until the app is opened.
     * (Platform signature: onRestored(Context, oldIds, newIds) — no manager.)
     */
    override fun onRestored(
        context: Context,
        oldWidgetIds: IntArray,
        newWidgetIds: IntArray
    ) {
        renderAll(
            context,
            AppWidgetManager.getInstance(context),
            newWidgetIds,
            HomeWidgetPlugin.getData(context)
        )
    }

    companion object {

        /** Paints the widget for the given ids from the given prefs snapshot. */
        @JvmStatic
        internal fun renderAll(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            widgetData: SharedPreferences
        ) {
            // Bangla-first placeholders (the app's default locale) for the
            // very first renders, before any data has been pushed.
            val todayLabel = widgetData.getString("todayLabel", null) ?: "আজ"
            val todayValue = widgetData.getString("todayValue", null) ?: "—"
            val monthLabel = widgetData.getString("monthLabel", null) ?: "এই মাসে"
            val monthValue = widgetData.getString("monthValue", null) ?: "—"

            // v2.2.1: budget progress row (hidden entirely without a budget).
            val hasBudget = widgetData.getBoolean("budgetHas", false)
            val budgetLabel = widgetData.getString("budgetLabel", null) ?: "বাজেট"
            val budgetValue = widgetData.getString("budgetValue", null) ?: "—"
            val budgetPct = widgetData.getInt("budgetPct", 0).coerceIn(0, 100)

            // Explicit launch intent — getLaunchIntentForPackage() can return
            // null on some OEM launchers, which would crash the update.
            val launch = Intent(context, MainActivity::class.java)
            launch.action = Intent.ACTION_MAIN
            launch.addCategory(Intent.CATEGORY_LAUNCHER)
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val openApp = PendingIntent.getActivity(
                context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            for (id in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.moneybag_widget)
                views.setTextViewText(R.id.widget_brand, "মানিব্যাগ")
                views.setTextViewText(R.id.widget_today_label, todayLabel)
                views.setTextViewText(R.id.widget_today_value, todayValue)
                views.setTextViewText(R.id.widget_month_label, monthLabel)
                views.setTextViewText(R.id.widget_month_value, monthValue)

                if (hasBudget) {
                    views.setViewVisibility(R.id.widget_budget_row, View.VISIBLE)
                    views.setTextViewText(R.id.widget_budget_label, budgetLabel)
                    views.setTextViewText(R.id.widget_budget_value, budgetValue)
                    views.setProgressBar(R.id.widget_budget_bar, 100, budgetPct, false)
                    // Red bar when the budget is blown; green otherwise.
                    try {
                        views.setInt(
                            R.id.widget_budget_bar, "setProgressTint",
                            if (budgetPct >= 100) Color.parseColor("#FFFF5252")
                            else Color.parseColor("#FF2ED573")
                        )
                    } catch (_: Exception) {
                        // Older OEM RemoteViews implementations may not allow
                        // setProgressTint — the XML tint stays as-is.
                    }
                } else {
                    views.setViewVisibility(R.id.widget_budget_row, View.GONE)
                }

                views.setOnClickPendingIntent(R.id.widget_root, openApp)
                appWidgetManager.updateAppWidget(id, views)
            }
        }

        /** All widget ids currently placed on home screens (for the boot receiver). */
        @JvmStatic
        internal fun placedIds(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, MbWidgetProvider::class.java))
    }
}
