package com.example.frontend

import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.service.autofill.Dataset
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.app.assist.AssistStructure
import android.widget.RemoteViews
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import org.json.JSONArray
import org.json.JSONObject
import android.util.Log

class SentryAutofillService : AutofillService() {

    override fun onFillRequest(request: FillRequest, cancellationSignal: android.os.CancellationSignal, callback: FillCallback) {
        val contexts = request.fillContexts
        if (contexts.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        val structure = contexts.last().structure
        val packageName = structure.activityComponent.packageName
        
        Log.d("SentryAutofill", "Autofill triggered for app: $packageName")

        val fields = mutableMapOf<String, AutofillId>()
        parseStructure(structure, fields)

        if (fields.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        // Read cached secrets securely from App Private Preferences
        val prefs = getSharedPreferences("sentrykey_autofill_cache", Context.MODE_PRIVATE)
        val cacheStr = prefs.getString("credentials_cache", "[]") ?: "[]"
        val credentials = JSONArray(cacheStr)

        var matchedUser: String? = null
        var matchedPass: String? = null

        // Parse package name keywords to match website logins (e.g. com.instagram.android matches instagram.com)
        val simplePackageName = packageName.substringAfterLast(".").replace("android", "")

        for (i in 0 until credentials.length()) {
            val item = credentials.getJSONObject(i)
            val website = item.optString("website", "").lowercase()
            val username = item.optString("username", "")
            val password = item.optString("password", "")

            if (packageName.contains(website) || website.contains(simplePackageName) || 
                (simplePackageName.isNotEmpty() && website.contains(simplePackageName))) {
                matchedUser = username
                matchedPass = password
                break
            }
        }

        // Fallback: If no direct match, take the first credential
        if (matchedUser == null || matchedPass == null) {
            if (credentials.length() > 0) {
                val firstItem = credentials.getJSONObject(0)
                matchedUser = firstItem.optString("username", "")
                matchedPass = firstItem.optString("password", "")
            }
        }

        if (matchedUser != null && matchedPass != null) {
            val responseBuilder = FillResponse.Builder()
            val datasetBuilder = Dataset.Builder()

            val usernameId = fields["username"]
            val passwordId = fields["password"]

            // Premium RemoteViews for beautiful autofill keyboards/dialog suggestions
            val presentationUser = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                setTextViewText(android.R.id.text1, "🔑 Autofill: $matchedUser")
            }

            if (usernameId != null) {
                datasetBuilder.setValue(usernameId, AutofillValue.forText(matchedUser), presentationUser)
            }
            if (passwordId != null) {
                val presentationPass = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                    setTextViewText(android.R.id.text1, "🔑 Autofill Password")
                }
                datasetBuilder.setValue(passwordId, AutofillValue.forText(matchedPass), presentationPass)
            }

            val unlockedDataset = datasetBuilder.build()

            // Setup Authentication Intent
            val authIntent = Intent(this, AutofillAuthActivity::class.java).apply {
                putExtra(AutofillAuthActivity.EXTRA_DATASET, unlockedDataset)
            }
            val intentSender = PendingIntent.getActivity(
                this, 1001, authIntent, 
                PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_MUTABLE
            ).intentSender

            // Build a locked dataset for presentation
            val lockedDatasetBuilder = Dataset.Builder()
            if (usernameId != null) {
                lockedDatasetBuilder.setValue(usernameId, null, presentationUser)
            }
            if (passwordId != null) {
                val presentationLock = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                    setTextViewText(android.R.id.text1, "🔒 Tap to unlock SentryKey")
                }
                lockedDatasetBuilder.setValue(passwordId, null, presentationLock)
            }
            lockedDatasetBuilder.setAuthentication(intentSender)

            responseBuilder.addDataset(lockedDatasetBuilder.build())
            callback.onSuccess(responseBuilder.build())
        } else {
            callback.onSuccess(null)
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    private fun parseStructure(structure: AssistStructure, fields: MutableMap<String, AutofillId>) {
        val nodes = structure.windowNodeCount
        for (i in 0 until nodes) {
            val windowNode = structure.getWindowNodeAt(i)
            if (windowNode != null && windowNode.rootViewNode != null) {
                traverseNode(windowNode.rootViewNode, fields)
            }
        }
    }

    private fun traverseNode(node: AssistStructure.ViewNode, fields: MutableMap<String, AutofillId>) {
        val hints = node.autofillHints
        if (hints != null) {
            for (hint in hints) {
                if (hint.contains("username", ignoreCase = true) || hint.contains("email", ignoreCase = true)) {
                    node.autofillId?.let { fields["username"] = it }
                } else if (hint.contains("password", ignoreCase = true)) {
                    node.autofillId?.let { fields["password"] = it }
                }
            }
        }

        // Fallback checks
        if (!fields.containsKey("username")) {
            val idEntry = node.idEntry
            if (idEntry != null) {
                if (idEntry.contains("username", ignoreCase = true) || idEntry.contains("email", ignoreCase = true) || idEntry.contains("login", ignoreCase = true)) {
                    node.autofillId?.let { fields["username"] = it }
                } else if (idEntry.contains("password", ignoreCase = true)) {
                    node.autofillId?.let { fields["password"] = it }
                }
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChildAt(i)
            if (child != null) {
                traverseNode(child, fields)
            }
        }
    }
}
