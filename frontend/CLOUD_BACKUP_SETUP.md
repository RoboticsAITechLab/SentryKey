# ☁️ SentryKey Encrypted Cloud Backup Setup Guide

This guide contains your active developer certificates and exact step-by-step instructions to register SentryKey in the Google Cloud / Firebase Console so that **Google Drive Encrypted Sync** works flawlessly on your device.

---

## 🔑 Your Developer Certificates

These are the unique cryptographic signatures of your local machine's developer keystore. You must register **both** in your Google Cloud / Firebase settings.

### 1. SHA-1 Fingerprint (Required for Google Sign-In)
```text
4A:2F:00:1D:6B:31:A9:94:E6:1D:F1:E0:60:F3:9D:9F:9C:39:9B:9F
```

### 2. SHA-256 Fingerprint (Required for play-integrity & secure bindings)
```text
94:71:E9:57:86:AB:3F:34:45:6B:C6:83:01:81:11:BE:44:39:40:DD:85:7C:94:E4:CA:FB:E2:D3:10:B4:6F:9E
```

---

## 🛠️ Step-by-Step Registration Guide

Since the Google Console resides on the web, you need to open your browser and add these keys to your project:

### Option A: If using Firebase (Recommended)
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Select your SentryKey project.
3. Click the **Gear Icon (Settings)** next to "Project Overview" in the left sidebar and select **Project Settings**.
4. Scroll down to the **Your Apps** section and select your Android app (`com.example.frontend`).
5. Click **Add Fingerprint** and paste your **SHA-1 Fingerprint** (from above), then click **Save**.
6. Click **Add Fingerprint** again, paste your **SHA-256 Fingerprint** (from above), and click **Save**.
7. Download the updated **`google-services.json`** file.
8. Place the `google-services.json` in this folder:
   👉 `c:\Users\Ankit\Desktop\SentryKey\frontend\android\app/`

---

### Option B: If using standard Google Cloud Console (Without Firebase)
1. Go to the [Google Cloud Console Credentials Page](https://console.cloud.google.com/apis/credentials).
2. Select your SentryKey project from the top dropdown.
3. Click **Create Credentials** -> **OAuth client ID**.
4. Under **Application type**, select **Android**.
5. In **Package name**, enter exactly: `com.example.frontend`
6. In **SHA-1 certificate fingerprint**, paste:
   `4A:2F:00:1D:6B:31:A9:94:E6:1D:F1:E0:60:F3:9D:9F:9C:39:9B:9F`
7. Click **Create**.
8. Repeat the process to create another OAuth client ID, and register the **SHA-256 Fingerprint** if needed for other Google APIs.
