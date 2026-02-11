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
    private var modelPath: String? = null
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
            modelPath = args["modelPath"] as? String
            userLatitude = (args["userLatitude"] as? Number)?.toDouble() ?: 0.0
            userLongitude = (args["userLongitude"] as? Number)?.toDouble() ?: 0.0
            
            if (modelPath != null) {
                android.util.Log.d("ARCore", "Using 3D model: $modelPath")
            }
            
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
        val activity = context as? Activity ?: return
        
        // Load 3D model (required)
        if (modelPath == null) {
            android.util.Log.e("ARCore", "ERROR: No model path provided")
            sendEvent(mapOf("type" to "arSessionFailed", "error" to "No 3D model specified"))
            return
        }
        
        android.util.Log.d("ARCore", "Loading 3D model from: $modelPath")
        load3DModel(anchor, activity)
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
    
    private fun load3DModel(anchor: Anchor, activity: Activity) {
        val path = modelPath ?: run {
            android.util.Log.e("ARCore", "ERROR: modelPath is null")
            return
        }
        
        android.util.Log.d("ARCore", "Loading 3D model from path: $path")
        
        // Convert Flutter asset path to Android asset path
        val assetPath = io.flutter.embedding.engine.loader.FlutterLoader.getInstance()
            .getLookupKeyForAsset(path)
        
        android.util.Log.d("ARCore", "Flutter asset key: $assetPath")
        
        try {
            // Load the GLB model using ModelRenderable
            ModelRenderable.builder()
                .setSource(activity, android.net.Uri.parse(assetPath))
                .setIsFilamentGltf(true)
                .build()
                .thenAccept { renderable ->
                    android.util.Log.d("ARCore", "Successfully loaded 3D model")
                    android.util.Log.d("ARCore", "Creating anchor node")
                    
                    // Create anchor node
                    val anchorNode = AnchorNode(anchor)
                    anchorNode.setParent(arFragment.arSceneView.scene)
                    
                    // Create node for the model
                    val node = Node().apply {
                        this.renderable = renderable
                        this.setParent(anchorNode)
                        
                        // Scale model 2x for visibility
                        this.localScale = Vector3(2f, 2f, 2f)
                        android.util.Log.d("ARCore", "Model scaled 2x for visibility")
                        
                        // Play all animations from the model
                        val animationData = renderable.animationDataList
                        android.util.Log.d("ARCore", "Model has ${animationData.size} animations")
                        
                        if (animationData.isNotEmpty()) {
                            for (i in 0 until animationData.size) {
                                val animator = com.google.ar.sceneform.animation.ModelAnimator(animationData[i], renderable)
                                animator.repeatCount = Int.MAX_VALUE // Loop forever
                                animator.start()
                                android.util.Log.d("ARCore", "Playing animation $i")
                            }
                        } else {
                            // If no animations in model, add continuous rotation
                            android.util.Log.d("ARCore", "No embedded animations found, adding rotation")
                            
                            // Use scene update to rotate continuously
                            arFragment.arSceneView.scene.addOnUpdateListener { frameTime ->
                                if (this.parent != null) {
                                    val rotationSpeed = 0.5f // degrees per frame
                                    val newRotation = this.localRotation
                                    this.localRotation = com.google.ar.sceneform.math.Quaternion.axisAngle(
                                        Vector3(0f, 1f, 0f),
                                        frameTime.deltaSeconds * 60f * rotationSpeed
                                    ).times(newRotation)
                                }
                            }
                        }
                        
                        // Add tap listener
                        this.setOnTapListener { _, _ ->
                            sendEvent(mapOf("type" to "rewardCollected"))
                        }
                    }
                    
                    android.util.Log.d("ARCore", "Node created with position: ${node.worldPosition}")
                    rewardNode = node
                    sendEvent(mapOf("type" to "rewardInView"))
                }
                .exceptionally { throwable ->
                    android.util.Log.e("ARCore", "Error loading 3D model: ${throwable.message}")
                    sendEvent(mapOf("type" to "arSessionFailed", "error" to "Failed to load 3D model"))
                    null
                }
        } catch (e: Exception) {
            android.util.Log.e("ARCore", "Exception loading 3D model: ${e.message}")
            sendEvent(mapOf("type" to "arSessionFailed", "error" to "Failed to load 3D model"))
        }
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
