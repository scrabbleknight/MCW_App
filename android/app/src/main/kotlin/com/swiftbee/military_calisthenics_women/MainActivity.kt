package com.swiftbee.military_calisthenics_women

import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) so the `health` plugin can
// launch the Health Connect permission screen via registerForActivityResult.
class MainActivity : FlutterFragmentActivity() {
    // Analytics stays off on Firebase Test Lab, which runs Google Play's
    // pre-launch reports (lib/core/funnel/analytics_environment.dart).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "swiftbee/funnel_environment")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTestLab") {
                    result.success(Settings.System.getString(contentResolver, "firebase.test.lab") == "true")
                } else {
                    result.notImplemented()
                }
            }
    }
}
