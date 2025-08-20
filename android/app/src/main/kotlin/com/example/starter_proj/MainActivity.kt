package com.example.todo_list

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val REQUEST_POST_NOTIFICATIONS = 1001
	private val CHANNEL = "app.settings"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		// Initial passive request on first launch (optional). You can remove this
		// if you prefer to request from Dart when needed.
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			ActivityCompat.requestPermissions(
				this,
				arrayOf(Manifest.permission.POST_NOTIFICATIONS),
				REQUEST_POST_NOTIFICATIONS
			)
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"openSettings" -> {
					openAppSettings()
					result.success(true)
				}
				"checkNotificationPermission" -> {
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
						val permission = Manifest.permission.POST_NOTIFICATIONS
						val granted = ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
						val shouldShow = ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
						val map: Map<String, Any> = mapOf(
							"granted" to granted,
							"shouldShowRationale" to shouldShow
						)
						result.success(map)
					} else {
						val map: Map<String, Any> = mapOf(
							"granted" to true,
							"shouldShowRationale" to false
						)
						result.success(map)
					}
				}
				"requestNotificationPermission" -> {
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
						ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_POST_NOTIFICATIONS)
						result.success(true)
					} else {
						result.success(false)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun openAppSettings() {
		val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
			data = Uri.fromParts("package", packageName, null)
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}
		startActivity(intent)
	}
}
