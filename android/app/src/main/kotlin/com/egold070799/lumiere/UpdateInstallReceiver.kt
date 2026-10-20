package com.egold070799.lumiere

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log

class UpdateInstallReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
      PackageInstaller.STATUS_PENDING_USER_ACTION -> {
        val confirmationIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
          intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
          @Suppress("DEPRECATION")
          intent.getParcelableExtra(Intent.EXTRA_INTENT) as? Intent
        }

        confirmationIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (confirmationIntent != null) {
          context.startActivity(confirmationIntent)
        } else {
          Log.e("LumiereUpdater", "Install confirmation intent was missing.")
        }
      }

      PackageInstaller.STATUS_SUCCESS ->
        Log.i("LumiereUpdater", "Lumiere update installed successfully.")

      else -> {
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        Log.e("LumiereUpdater", "Package install failed: $message")
      }
    }
  }
}
