package com.example.frontend

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.sentrykey/autofill"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateAutofillCache") {
                val cacheJson = call.argument<String>("cacheJson")
                if (cacheJson != null) {
                    val prefs = getSharedPreferences("sentrykey_autofill_cache", Context.MODE_PRIVATE)
                    prefs.edit().putString("credentials_cache", cacheJson).apply()
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "cacheJson is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
