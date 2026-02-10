package com.hotncold.hotncold

import android.app.Activity
import android.content.Context
import android.view.View
import com.google.ar.core.*
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.Node
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.rendering.MaterialFactory
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.rendering.ShapeFactory
import com.google.ar.sceneform.ux.ArFragment
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.cos
import kotlin.math.sin

/**
 * Factory for creating ARCore platform views
 */
class ARCoreViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ARCoreView(context, viewId, messenger)
    }
}

/**
 * ARCore platform view that renders 3D rewards in augmented reality
 */
class ARCoreView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler {
    
    private val arFragment: ArFragment = ArFragment()
    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.hotncold.ar/native_ar")
    private var eventSink: EventChannel.EventSink? = null
    
    // AR session state
    private var rewardNode: Node? = null
    private var rewardAnchor: Anchor? = null
    private var rewardBearing: Double = 0.0
    private var rewardDistance: Double = 0.0
    private var rewardElevation: Double = 0.0
    private var rewardType: String = "points"
    private var userLatitude: Double = 0.0
    private var userLongitude: Double = 0.0
    
    init {
        methodChannel.setMethodCallHandler(this)
        
        // Setup ARCore fragment
        arFragment.setOnTapArPlaneListener { hitResult, _, _ ->
            // User tapped on AR plane - could be used for manual placement
        }
        
        arFragment.arSceneView.scene.addOnUpdateListener {
            // Called every frame - could check distance to reward
        }
    }
    
    override fun getView(): View {
        return arFragment.view ?: View(context)
    }
    
    override fun dispose() {
        arFragment.onDestroy()
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startARSession" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return
                }
                startARSession(args, result)
            }
            "stopARSession" -> stopARSession(result)
            "isARSupported" -> {
                val arCoreAvailable = ArCoreApk.getInstance().checkAvailability(context)
                result.success(arCoreAvailable.isSupported)
            }
            "collectReward" -> collectReward(result)
            else -> result.notImplemented()
        }
    }
    
    private fun startARSession(args: Map<*, *>, result: MethodChannel.Result) {
        try {
            // Parse arguments
            rewardBearing = (args["rewardBearing"] as? Number)?.toDouble() ?: 0.0
            rewardDistance = (args["rewardDistance"] as? Number)?.toDouble() ?: 0.0
            rewardElevation = (args["rewardElevation"] as? Number)?.toDouble() ?: 0.0
            rewardType = args["rewardType"] as? String ?: "points"
            userLatitude = (args["userLatitude"] as? Number)?.toDouble() ?: 0.0
            userLongitude = (args["userLongitude"] as? Number)?.toDouble() ?: 0.0
            
            // Start AR session
            val session = arFragment.arSceneView.session
            if (session != null) {
                val config = Config(session).apply {
                    updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                    planeFindingMode = Config.PlaneFindingMode.DISABLED
                }
                session.configure(config)
                
                // Place reward after short delay
                arFragment.arSceneView.scene.addOnUpdateListener {
                    placeRewardAnchor()
                }
                
                sendEvent(mapOf("type" to "arSessionStarted"))
                result.success(true)
            } else {
                result.error("AR_UNAVAILABLE", "AR session not available", null)
            }
        } catch (e: Exception) {
            result.error("AR_ERROR", "Failed to start AR session: ${e.message}", null)
        }
    }
    
    private fun stopARSession(result: MethodChannel.Result) {
        rewardNode?.let { node ->
            node.setParent(null)
            rewardNode = null
        }
        rewardAnchor?.detach()
        rewardAnchor = null
        result.success(true)
    }
    
    private fun placeRewardAnchor() {
        // Only place once
        if (rewardAnchor != null) return
        
        val session = arFragment.arSceneView.session ?: return
        val frame = arFragment.arSceneView.arFrame ?: return
        
        // Convert bearing and distance to world coordinates
        // ARCore uses: +X = Right, +Y = Up, +Z = Back (camera-relative)
        val bearingRadians = Math.toRadians(rewardBearing)
        
        // Calculate position relative to camera
        val x = (rewardDistance * sin(bearingRadians)).toFloat()
        val z = -(rewardDistance * cos(bearingRadians)).toFloat() // Negative because forward is -Z
        val y = rewardElevation.toFloat()
        
        // Create anchor at camera pose + offset
        val cameraPose = frame.camera.pose
        val translation = floatArrayOf(x, y, z)
        val anchorPose = cameraPose.compose(Pose.makeTranslation(translation))
        
        try {
            val anchor = session.createAnchor(anchorPose)
            rewardAnchor = anchor
            
            // Create 3D model and attach to anchor
            create3DRewardNode(anchor)
        } catch (e: Exception) {
            sendEvent(mapOf("type" to "arSessionFailed", "error" to e.message))
        }
    }
    
    private fun create3DRewardNode(anchor: Anchor) {
        // For now, create simple colored shapes as placeholders
        // In production, you would load GLB/GLTF models here
        val activity = context as? Activity ?: return
        
        val (color, size, shape) = when (rewardType) {
            "points" -> Triple(
                com.google.ar.sceneform.rendering.Color(1f, 0.84f, 0f), // Gold
                Vector3(0.15f, 0.04f, 0.15f), // Cylinder dimensions
                "cylinder"
            )
            "coupon" -> Triple(
                com.google.ar.sceneform.rendering.Color(0f, 0.8f, 0f), // Green
                Vector3(0.2f, 0.3f, 0.02f), // Box dimensions
                "box"
            )
            "raffle" -> Triple(
                com.google.ar.sceneform.rendering.Color(0.6f, 0f, 1f), // Purple
                Vector3(0.12f, 0.12f, 0.12f), // Sphere dimensions
                "sphere"
            )
            "product" -> Triple(
                com.google.ar.sceneform.rendering.Color(1f, 0f, 0f), // Red
                Vector3(0.2f, 0.2f, 0.2f), // Box dimensions
                "box"
            )
            else -> Triple(
                com.google.ar.sceneform.rendering.Color(1f, 0.5f, 0f), // Orange
                Vector3(0.15f, 0.15f, 0.15f), // Sphere dimensions
                "sphere"
            )
        }
        
        MaterialFactory.makeOpaqueWithColor(activity, color)
            .thenAccept { material ->
                val renderable = when (shape) {
                    "cylinder" -> ShapeFactory.makeCylinder(size.x, size.y, Vector3.zero(), material)
                    "box" -> ShapeFactory.makeCube(size, Vector3.zero(), material)
                    else -> ShapeFactory.makeSphere(size.x, Vector3.zero(), material)
                }
                
                // Create anchor node
                val anchorNode = AnchorNode(anchor)
                anchorNode.setParent(arFragment.arSceneView.scene)
                
                // Create reward node
                val node = Node().apply {
                    this.renderable = renderable
                    this.setParent(anchorNode)
                    this.localPosition = Vector3(0f, size.y, 0f) // Lift slightly
                    
                    // Add tap listener
                    this.setOnTapListener { _, _ ->
                        sendEvent(mapOf("type" to "rewardCollected"))
                    }
                }
                
                rewardNode = node
                sendEvent(mapOf("type" to "rewardInView"))
            }
    }
    
    private fun collectReward(result: MethodChannel.Result) {
        val node = rewardNode
        if (node == null) {
            result.error("NO_REWARD", "No reward to collect", null)
            return
        }
        
        // Remove node
        node.setParent(null)
        rewardNode = null
        rewardAnchor?.detach()
        rewardAnchor = null
        
        result.success(true)
    }
    
    private fun sendEvent(event: Map<String, Any?>) {
        eventSink?.success(event)
    }
}

/**
 * Event channel stream handler for AR events
 */
class AREventStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    fun send(event: Map<String, Any?>) {
        eventSink?.success(event)
    }
}
