package com.swiftbee.military_calisthenics_women

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) so the `health` plugin can
// launch the Health Connect permission screen via registerForActivityResult.
class MainActivity : FlutterFragmentActivity() {
    // Analytics stays off on emulators and on Firebase Test Lab, which runs
    // Google Play's pre-launch reports (lib/core/funnel/analytics_environment.dart).
    // Emulators by their hardware or build only: looser checks match real phones.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "swiftbee/funnel_environment")
            .setMethodCallHandler { call, result ->
                if (call.method == "environment") {
                    val emulator = Build.HARDWARE in setOf("ranchu", "goldfish", "vbox86") ||
                        Build.MODEL.startsWith("sdk_gphone") ||
                        Build.FINGERPRINT.startsWith("generic")
                    val testLab = Settings.System.getString(contentResolver, "firebase.test.lab") == "true"
                    result.success(mapOf("emulator" to emulator, "testLab" to testLab))
                } else {
                    result.notImplemented()
                }
            }
    }
}
