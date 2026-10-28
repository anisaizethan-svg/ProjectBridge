package com.example.pr_bridge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var attachments: AttachmentBridge
    @Deprecated("Activity result bridge for system pickers")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (::attachments.isInitialized) attachments.onResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        attachments = AttachmentBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        val preferences = getSharedPreferences("projectbridge_demo", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "projectbridge/demo_storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> result.success(preferences.getString("snapshot_v1", null))
                    "save" -> {
                        val snapshot = call.arguments as? String
                        if (snapshot == null) {
                            result.error("INVALID_DATA", "Expected a demo snapshot", null)
                        } else {
                            // Commit before acknowledging: a completed save survives process death.
                            val saved = preferences.edit().putString("snapshot_v1", snapshot).commit()
                            if (saved) result.success(null)
                            else result.error("SAVE_FAILED", "Could not save demo data", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
