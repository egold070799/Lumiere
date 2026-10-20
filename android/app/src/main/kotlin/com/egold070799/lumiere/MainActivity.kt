package com.egold070799.lumiere

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
  private val updateChannelName = "com.egold070799.lumiere/app_update"

  override fun onCreate(savedInstanceState: Bundle?) {
    // Aligns the Flutter view vertically with the window.
    WindowCompat.setDecorFitsSystemWindows(getWindow(), false)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      // Disable the Android splash screen fade out animation to avoid
      // a flicker before the similar frame is drawn in Flutter.
      splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
    }

    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "canInstallPackages" -> {
            result.success(
              Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                packageManager.canRequestPackageInstalls(),
            )
          }

          "openInstallPermissionSettings" -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
              val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
              )
              startActivity(intent)
            }
            result.success(null)
          }

          "installApk" -> {
            val apkPath = call.argument<String>("path")
            if (apkPath.isNullOrBlank()) {
              result.error("INVALID_APK_PATH", "APK path is missing.", null)
              return@setMethodCallHandler
            }

            try {
              installApk(apkPath)
              result.success(null)
            } catch (error: Exception) {
              result.error("APK_INSTALL_FAILED", error.message, null)
            }
          }

          else -> result.notImplemented()
        }
      }
  }

  private fun installApk(apkPath: String) {
    val apkFile = File(apkPath)
    require(apkFile.isFile && apkFile.length() > 0) { "Downloaded APK is missing." }

    val installer = packageManager.packageInstaller
    val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
    params.setAppPackageName(packageName)
    params.setSize(apkFile.length())
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
    }

    val sessionId = installer.createSession(params)
    installer.openSession(sessionId).use { session ->
      session.openWrite("lumiere-update.apk", 0, apkFile.length()).use { output ->
        FileInputStream(apkFile).use { input -> input.copyTo(output) }
        session.fsync(output)
      }

      val callbackIntent = Intent(this, UpdateInstallReceiver::class.java).apply {
        action = "$packageName.INSTALL_UPDATE_$sessionId"
      }
      var pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        pendingIntentFlags = pendingIntentFlags or PendingIntent.FLAG_MUTABLE
      }
      val callback = PendingIntent.getBroadcast(
        this,
        sessionId,
        callbackIntent,
        pendingIntentFlags,
      )
      session.commit(callback.intentSender)
    }
  }
}
