package bd.moneybag.moneybag

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity (instead of FlutterActivity) is required by the
 * local_auth plugin — the biometric prompt attaches to a fragment activity.
 * Behaviour is otherwise identical for the Flutter app.
 *
 * v2.2.3: the `moneybag/device` method channel exposes the two OEM
 * reliability helpers the notification center needs on BD-market phones
 * (Walton/Symphony/MIUI-class ROMs kill background alarms aggressively):
 *  • isIgnoringBatteryOptimizations — show a warning tile when not exempt
 *  • requestIgnoreBatteryOptimizations — system "allow" dialog
 *  • openNotificationSettings — deep-link to this app's notification screen
 *    (a denied POST_NOTIFICATIONS is otherwise undiscoverable)
 */
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "moneybag/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Exception) {
            true // don't scare the user when the check fails
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        try {
            @Suppress("DEPRECATION")
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } catch (_: Exception) {
            // Some ROMs block the direct dialog — fall back to the list.
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                // Nothing more we can do; the warning tile stays honest.
            }
        }
    }

    private fun openNotificationSettings() {
        try {
            val intent: Intent =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                } else {
                    @Suppress("DEPRECATION")
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.parse("package:$packageName"))
                }
            startActivity(intent)
        } catch (_: Exception) {
            // Fall back to the app-details page on exotic ROMs.
            try {
                @Suppress("DEPRECATION")
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.parse("package:$packageName"))
                )
            } catch (_: Exception) {
            }
        }
    }
}
