package com.hotncold.hotncold

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register ARCore platform view
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "com.hotncold.ar/arcore_view",
                ARCoreViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )
        
        // Setup event channel
        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hotncold.ar/ar_events"
        )
        val eventHandler = AREventStreamHandler()
        eventChannel.setStreamHandler(eventHandler)
    }
}

