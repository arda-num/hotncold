import Flutter
import UIKit
import ARKit
import SceneKit
import CoreLocation

/// Shared event stream handler for AR events
public class AREventStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    public func send(event: [String: Any]) {
        eventSink?(event)
    }
}

/// Factory for creating ARKit platform views
public class ARKitViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private var eventHandler: AREventStreamHandler
    
    public init(messenger: FlutterBinaryMessenger, eventHandler: AREventStreamHandler) {
        self.messenger = messenger
        self.eventHandler = eventHandler
        super.init()
    }
    
    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return ARKitView(
            frame: frame,
            viewIdentifier: viewId,
            messenger: messenger,
            eventHandler: eventHandler
        )
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// ARKit platform view that renders 3D rewards in augmented reality
class ARKitView: NSObject, FlutterPlatformView {
    private var arView: ARSCNView
    private var eventHandler: AREventStreamHandler
    
    // AR session state
    private var rewardNode: SCNNode?
    private var rewardAnchor: ARAnchor?
    private var rewardBearing: Double = 0
    private var rewardDistance: Double = 0
    private var rewardElevation: Double = 0
    private var rewardType: String = "points"
    private var userLocation: CLLocationCoordinate2D?
    
    init(frame: CGRect, viewIdentifier viewId: Int64, messenger: FlutterBinaryMessenger, eventHandler: AREventStreamHandler) {
        arView = ARSCNView(frame: frame)
        self.eventHandler = eventHandler
        
        super.init()
        
        // Register this as the active AR view
        AppDelegate.activeARView = self
        print("[ARKit] ARKitView initialized and registered as active view")
        
        // Setup AR view
        arView.delegate = self
        arView.session.delegate = self
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true
        
        // Add tap gesture recognizer for collecting rewards
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    deinit {
        // Clean up the active reference
        if AppDelegate.activeARView === self {
            AppDelegate.activeARView = nil
        }
    }
    
    func view() -> UIView {
        return arView
    }
    
    // Method called from AppDelegate method channel
    func startARSessionFromChannel(args: [String: Any], result: @escaping FlutterResult) {
        print("[ARKit] startARSessionFromChannel called with args: \(args)")
        
        // Parse arguments
        guard let bearing = args["rewardBearing"] as? Double,
              let distance = args["rewardDistance"] as? Double,
              let elevation = args["rewardElevation"] as? Double,
              let type = args["rewardType"] as? String,
              let lat = args["userLatitude"] as? Double,
              let lon = args["userLongitude"] as? Double else {
            print("[ARKit] ERROR: Missing required parameters")
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required parameters", details: nil))
            return
        }
        
        print("[ARKit] Starting AR session: bearing=\(bearing)°, distance=\(distance)m, elevation=\(elevation)°")
        
        rewardBearing = bearing
        rewardDistance = distance
        rewardElevation = elevation
        rewardType = type
        userLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = []
        
        // Run session
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Place reward after a short delay to ensure tracking is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.placeRewardAnchor()
        }
        
        sendEvent(type: "arSessionStarted", data: [:])
        result(true)
    }
    
    // Method called from AppDelegate method channel
    func stopARSessionFromChannel(result: @escaping FlutterResult) {
        arView.session.pause()
        rewardNode?.removeFromParentNode()
        rewardNode = nil
        if let anchor = rewardAnchor {
            arView.session.remove(anchor: anchor)
        }
        rewardAnchor = nil
        result(true)
    }
    
    // Method called from AppDelegate method channel
    func collectRewardFromChannel(result: @escaping FlutterResult) {
        collectReward(result: result)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        let hitResults = arView.hitTest(location, options: [:])
        
        print("[ARKit] Tap detected at location: \(location)")
        
        // Check if we tapped the reward
        for result in hitResults {
            var node = result.node
            
            // Traverse up the node hierarchy to find the reward
            while let parent = node.parent {
                if node.name == "reward" || node == rewardNode {
                    print("[ARKit] Reward tapped! Triggering collection")
                    sendEvent(type: "rewardCollected", data: [:])
                    return
                }
                node = parent
            }
        }
        
        print("[ARKit] Tap did not hit reward. Hit \(hitResults.count) nodes")
    }
    
    private func placeRewardAnchor() {
        // Convert bearing and distance to AR world coordinates
        // ARKit uses: +X = East, +Y = Up, +Z = South (when facing north)
        
        print("[ARKit] Placing reward anchor: bearing=\(rewardBearing)°, distance=\(rewardDistance)m, elevation=\(rewardElevation)°")
        
        // Convert bearing from degrees to radians
        let bearingRadians = rewardBearing * .pi / 180.0
        
        // Calculate position relative to user's initial position
        // x = east-west (positive = east)
        // z = north-south (positive = south, negative = north)
        let x = Float(rewardDistance * sin(bearingRadians))
        let z = Float(-rewardDistance * cos(bearingRadians)) // Negative because north is -Z
        
        // Use elevation angle to calculate y position (height)
        // If elevation is 0, place at eye level (camera starts at 0)
        let elevationRadians = rewardElevation * .pi / 180.0
        let y = Float(rewardDistance * sin(elevationRadians))
        
        let position = simd_float3(x, y, z)
        
        print("[ARKit] Calculated position: x=\(x), y=\(y), z=\(z)")
        print("[ARKit] Distance from origin: \(sqrt(x*x + y*y + z*z))m")
        
        // Create anchor at calculated position
        let transform = simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(position.x, position.y, position.z, 1)
        )
        
        let anchor = ARAnchor(transform: transform)
        arView.session.add(anchor: anchor)
        rewardAnchor = anchor
        
        print("[ARKit] Reward anchor placed successfully")
    }
    
    private func create3DRewardNode(type: String) -> SCNNode {
        let containerNode = SCNNode()
        
        print("[ARKit] Creating 3D reward node of type: \(type)")
        
        // Small, compact size
        let scaleFactor: Float = 1.0
        
        let geometry: SCNGeometry
        let color: UIColor
        
        switch type {
        case "points":
            // Gold coin
            geometry = SCNCylinder(radius: 0.15, height: 0.04)
            color = .systemYellow
        case "coupon":
            // Green ticket
            geometry = SCNBox(width: 0.2, height: 0.3, length: 0.02, chamferRadius: 0.01)
            color = .systemGreen
        case "raffle":
            // Purple sphere
            geometry = SCNSphere(radius: 0.12)
            color = .systemPurple
        case "product":
            // Red box
            geometry = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0.02)
            color = .systemRed
        default:
            // Orange sphere
            geometry = SCNSphere(radius: 0.12)
            color = .systemOrange
        }
        
        print("[ARKit] Creating \(color) object with scale \(scaleFactor)x")
        
        let node = SCNNode(geometry: geometry)
        
        // Apply bright material for visibility
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color.withAlphaComponent(0.5)
        material.specular.contents = UIColor.white
        material.shininess = 1.0
        geometry.materials = [material]
        
        // Apply scale
        node.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        
        print("[ARKit] Node created with scale: \(scaleFactor)")
        
        // Add floating animation
        let floatAction = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 1.5),
            SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 1.5)
        ])
        node.runAction(SCNAction.repeatForever(floatAction))
        
        // Add rotation animation
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 3.0)
        node.runAction(SCNAction.repeatForever(rotateAction))
        
        // Make it tappable
        node.name = "reward"
        
        containerNode.addChildNode(node)
        
        // Add a glowing ring around it
        let ringGeometry = SCNTorus(ringRadius: 0.25 * CGFloat(scaleFactor), pipeRadius: 0.03 * CGFloat(scaleFactor))
        let ringNode = SCNNode(geometry: ringGeometry)
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = UIColor.white
        ringMaterial.emission.contents = UIColor.white.withAlphaComponent(0.7)
        ringGeometry.materials = [ringMaterial]
        ringNode.position = SCNVector3(0, 0, 0)
        ringNode.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
        containerNode.addChildNode(ringNode)
        
        // Rotate the ring
        let ringRotateAction = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 2.0)
        ringNode.runAction(SCNAction.repeatForever(ringRotateAction))
        
        print("[ARKit] Created reward node with ring")
        
        return containerNode
    }
    
    private func collectReward(result: @escaping FlutterResult) {
        // Remove reward node with animation
        guard let node = rewardNode else {
            result(FlutterError(code: "NO_REWARD", message: "No reward to collect", details: nil))
            return
        }
        
        // Scale down and fade out
        let scaleAction = SCNAction.scale(to: 0.01, duration: 0.3)
        let fadeAction = SCNAction.fadeOut(duration: 0.3)
        let group = SCNAction.group([scaleAction, fadeAction])
        
        node.runAction(group) { [weak self] in
            node.removeFromParentNode()
            self?.rewardNode = nil
            if let anchor = self?.rewardAnchor {
                self?.arView.session.remove(anchor: anchor)
            }
            self?.rewardAnchor = nil
        }
        
        result(true)
    }
    
    private func sendEvent(type: String, data: [String: Any]) {
        var event = data
        event["type"] = type
        eventHandler.send(event: event)
    }
}

// MARK: - ARSCNViewDelegate
extension ARKitView: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("[ARKit] Renderer didAdd node for anchor: \(anchor)")
        
        // Check if this is our reward anchor
        guard anchor == rewardAnchor else {
            print("[ARKit] Not our reward anchor, ignoring")
            return
        }
        
        print("[ARKit] Adding reward node to scene")
        
        // Create and add reward 3D model
        let rewardNode = create3DRewardNode(type: rewardType)
        node.addChildNode(rewardNode)
        self.rewardNode = rewardNode
        
        print("[ARKit] Reward node added successfully to scene graph")
        print("[ARKit] Node world position: \(node.worldPosition)")
        
        // Notify Flutter that reward is visible
        DispatchQueue.main.async { [weak self] in
            print("[ARKit] Sending rewardInView event to Flutter")
            self?.sendEvent(type: "rewardInView", data: [:])
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Debug: Log reward node visibility occasionally
        if let rewardNode = rewardNode, Int(time) % 5 == 0 {
            let isVisible = renderer.isNode(rewardNode, insideFrustumOf: arView.pointOfView ?? SCNNode())
            if !isVisible {
                print("[ARKit] Warning: Reward node is not currently visible in camera frustum")
            }
        }
    }
}

// MARK: - ARSessionDelegate
extension ARKitView: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        sendEvent(type: "arSessionFailed", data: ["error": error.localizedDescription])
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        sendEvent(type: "arSessionFailed", data: ["error": "AR session interrupted"])
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let quality: String
        switch camera.trackingState {
        case .normal:
            quality = "good"
        case .limited(let reason):
            switch reason {
            case .initializing:
                quality = "initializing"
            case .relocalizing:
                quality = "relocalizing"
            case .excessiveMotion:
                quality = "excessiveMotion"
            case .insufficientFeatures:
                quality = "insufficientFeatures"
            @unknown default:
                quality = "unknown"
            }
        case .notAvailable:
            quality = "notAvailable"
        }
        
        sendEvent(type: "arTrackingQualityChanged", data: ["quality": quality])
    }
}
