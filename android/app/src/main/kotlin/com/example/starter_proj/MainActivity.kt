package com.example.todo_list

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	private val REQUEST_POST_NOTIFICATIONS = 1001

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		// Request POST_NOTIFICATIONS at runtime for Android 13+
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			ActivityCompat.requestPermissions(
				this,
				arrayOf(Manifest.permission.POST_NOTIFICATIONS),
				REQUEST_POST_NOTIFICATIONS
			)
		}
	}
}
