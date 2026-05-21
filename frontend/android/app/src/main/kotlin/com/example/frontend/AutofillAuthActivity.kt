package com.example.frontend

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.autofill.Dataset
import android.view.autofill.AutofillManager
import android.widget.Toast

class AutofillAuthActivity : Activity() {
    companion object {
        const val REQUEST_CODE_CONFIRM_CREDENTIALS = 1001
        const val EXTRA_DATASET = "extra_dataset"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (keyguardManager.isKeyguardSecure) {
            val intent = keyguardManager.createConfirmDeviceCredentialIntent("SentryKey Autofill", "Authenticate to fill password")
            if (intent != null) {
                startActivityForResult(intent, REQUEST_CODE_CONFIRM_CREDENTIALS)
            } else {
                finishAuth(false)
            }
        } else {
            // No lock screen set up, allow autofill for convenience but warn user
            Toast.makeText(this, "Device is not secure. Please set up a lock screen.", Toast.LENGTH_LONG).show()
            finishAuth(true)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_CONFIRM_CREDENTIALS) {
            finishAuth(resultCode == RESULT_OK)
        }
    }

    private fun finishAuth(success: Boolean) {
        if (success) {
            val dataset = intent.getParcelableExtra<Dataset>(EXTRA_DATASET)
            val replyIntent = Intent().apply {
                putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset)
            }
            setResult(RESULT_OK, replyIntent)
        } else {
            setResult(RESULT_CANCELED)
        }
        finish()
    }
}
