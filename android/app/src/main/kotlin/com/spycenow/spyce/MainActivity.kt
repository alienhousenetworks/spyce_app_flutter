package com.spycenow.spyce

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

/// FlutterFragmentActivity is required by AWS Amplify Face Liveness UI.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screen capture / recording of sensitive dating chats & photos
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
