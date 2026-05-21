package com.example.frontend

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.autofill.AutofillManager
import android.net.Uri

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
            } else if (call.method == "checkAutofillStatus") {
                val autofillManager = getSystemService(AutofillManager::class.java)
                val isSupported = autofillManager != null && autofillManager.isAutofillSupported
                val hasEnabled = autofillManager != null && autofillManager.hasEnabledAutofillServices()
                result.success(mapOf("isSupported" to isSupported, "hasEnabled" to hasEnabled))
            } else if (call.method == "requestAutofillSetup") {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_SETTINGS)
                    startActivity(intent)
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
