package com.luma.cabina360

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cabina360/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveVideo") {
                val sourcePath = call.argument<String>("sourcePath")
                val displayName = call.argument<String>("displayName")

                if (sourcePath == null || displayName == null) {
                    result.error("INVALID_ARGUMENTS", "sourcePath o displayName son nulos.", null)
                    return@setMethodCallHandler
                }

                val mediaStoreHandler = MediaStoreHandler(applicationContext)
                val uriString = mediaStoreHandler.saveVideo(sourcePath, displayName)

                if (uriString != null) {
                    result.success(uriString)
                } else {
                    result.error("SAVE_FAILED", "No se pudo guardar el video en MediaStore.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
