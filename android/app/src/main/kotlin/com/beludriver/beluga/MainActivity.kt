package com.beludriver.beluga

import android.content.Intent
import android.content.IntentSender
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var locationResult: MethodChannel.Result? = null
    private var locationDialogClosed = false
    private var inForeground = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "beludriver/location_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestEnableLocation") {
                    requestEnableLocation(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun requestEnableLocation(result: MethodChannel.Result) {
        if (locationResult != null || isFinishing || isDestroyed) {
            result.success("cancelled")
            return
        }
        locationResult = result
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5_000L).build()
        val settingsRequest = LocationSettingsRequest.Builder()
            .addLocationRequest(locationRequest)
            .setAlwaysShow(true)
            .build()

        LocationServices.getSettingsClient(this).checkLocationSettings(settingsRequest)
            .addOnCompleteListener { task ->
                if (locationResult !== result || isFinishing || isDestroyed) return@addOnCompleteListener
                val resolution = task.exception as? ResolvableApiException
                when {
                    task.isSuccessful -> finishLocationRequest("enabled")
                    resolution != null -> try {
                        resolution.startResolutionForResult(this, LOCATION_SETTINGS_REQUEST)
                    } catch (_: IntentSender.SendIntentException) {
                        finishLocationRequest("unavailable")
                    }
                    else -> finishLocationRequest("unavailable")
                }
            }
    }

    @Deprecated("Called by Android for the location settings resolution")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == LOCATION_SETTINGS_REQUEST && locationResult != null) {
            // Check the actual device setting after the dialog returns to the app.
            locationDialogClosed = true
            if (inForeground) finishLocationRequest("closed")
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        inForeground = true
        if (locationDialogClosed) finishLocationRequest("closed")
    }

    override fun onPause() {
        inForeground = false
        super.onPause()
    }

    override fun onDestroy() {
        finishLocationRequest("cancelled")
        super.onDestroy()
    }

    private fun finishLocationRequest(outcome: String) {
        val result = locationResult
        locationResult = null
        locationDialogClosed = false
        result?.success(outcome)
    }

    private companion object {
        const val LOCATION_SETTINGS_REQUEST = 6041
    }
}
