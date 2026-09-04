// package com.sih.voicebridge

// import android.Manifest
// import android.content.pm.PackageManager
// import com.sih.voicebridge.bridge.NativeBridgeHandler
// import androidx.core.app.ActivityCompat
// import io.flutter.embedding.android.FlutterActivity
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.EventChannel
// import io.flutter.plugin.common.MethodChannel

// class MainActivity : FlutterActivity() {
//     companion object {
//         private const val MICROPHONE_PERMISSION_REQUEST_CODE = 9101
//     }

//     private lateinit var nativeBridgeHandler: NativeBridgeHandler

//     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//         super.configureFlutterEngine(flutterEngine)

//         ensureMicrophonePermission()

//         nativeBridgeHandler = NativeBridgeHandler(this)

//         MethodChannel(
//             flutterEngine.dartExecutor.binaryMessenger,
//             "com.sih.voicebridge/native",
//         ).setMethodCallHandler(nativeBridgeHandler)

//         EventChannel(
//             flutterEngine.dartExecutor.binaryMessenger,
//             "com.sih.voicebridge/native_events",
//         ).setStreamHandler(nativeBridgeHandler)
//     }

//     private fun ensureMicrophonePermission() {
//         if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
//             return
//         }

//         ActivityCompat.requestPermissions(
//             this,
//             arrayOf(Manifest.permission.RECORD_AUDIO),
//             MICROPHONE_PERMISSION_REQUEST_CODE,
//         )
//     }
// }
package com.sih.voicebridge

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import com.sih.voicebridge.bridge.NativeBridgeHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val MICROPHONE_PERMISSION_REQUEST_CODE = 9101
    }

    private lateinit var nativeBridgeHandler: NativeBridgeHandler

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(flutterEngine)

        ensureMicrophonePermission()

        nativeBridgeHandler =
            NativeBridgeHandler(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sih.voicebridge/native",
        ).setMethodCallHandler(
            nativeBridgeHandler
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sih.voicebridge/native_events",
        ).setStreamHandler(
            nativeBridgeHandler
        )
    }

    private fun ensureMicrophonePermission() {
        if (
            checkSelfPermission(
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            MICROPHONE_PERMISSION_REQUEST_CODE,
        )
    }

    override fun onDestroy() {
        if (::nativeBridgeHandler.isInitialized) {
            nativeBridgeHandler.dispose()
        }

        super.onDestroy()
    }
}