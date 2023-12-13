/*
 Copyright © 2023 Gunnar Beutner,
 Copyright © 2022 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI
import NearbyInteraction
import ARKit
import RealityKit
import os
import Combine
import OpenUWB

let useCameraAssistance = true
var updateTimer: Timer?

// The main view for the Camera Assistance feature.
struct CameraAssistanceView: View {
    @StateObject var sessionManager = UWBManager()
    @StateObject var floorplanManager = FloorplanManager()
    @State var closestNearbyObject: NINearbyObject?
    @State var distances: [String: Float] = [:]
    @State var distanceInfo = ""
    var espresenseManager = ESPresenseManager(host: "mqtt.beutner.name", port: 1883, identifier: "OpenUWB", username: "uwb", password: "z0LKmHX74QjA")

    var body: some View {
        GeometryReader { reader in
            VStack {
                Spacer()
                if useCameraAssistance {
                    NIARView(sessionManager: sessionManager, floorplanManager: floorplanManager)
                        .frame(width: reader.size.width, height: reader.size.height * 0.35,
                               alignment: .center)
                        .overlay(NICoachingOverlay(horizontalAngle: closestNearbyObject?.horizontalAngle,
                                                   distance: closestNearbyObject?.distance,
                                                   convergenceContext: sessionManager.convergenceContext), alignment: .center)
                }
                FloorplanView(floorplanManager: floorplanManager)
                Text(distanceInfo)
                    .lineLimit(10, reservesSpace: true)
                Spacer()
            }
            .onAppear(perform: {
                espresenseManager.delegate = self
                Task {
                    await espresenseManager.run(accessoryName: "gunnar_iphone")
                }
                
                sessionManager.delegate = self
                if !useCameraAssistance {
                    sessionManager.run()
                }
            })
            .gesture(
                TapGesture().onEnded({ recognizer in
                    /*let sceneView = recognizer.view as! SCNView
                    //  Set the recognizer's location as anywhere in the sceneView and register when our location is tapped.
                    let touchLocation = recognizer.location(in: sceneView)
                    let hitResults = sceneView.hitTest(touchLocation, options: [:])
                    //  If there is a result in hitResults, do something!
                    if !hitResults.isEmpty {
                        addSphere(position: hitResults[0].worldCoordinates)
                    }*/
                    
                    if let closestNode = self.floorplanManager.floorplan.accessories.first(where: { $0.id == floorplanManager.closestNode }) {
                        floorplanManager.locationOffset = simd_float3(Float(closestNode.location[0]) - floorplanManager.rawLocation.x, Float(closestNode.location[1]) - floorplanManager.rawLocation.y, 0)
                        floorplanManager.locationOffsetValid = true
                    }
                })
            )
        }
    }
    
    private func updateDistanceInfo() {
        self.closestNearbyObject = sessionManager.accessories.values.min(by: {
            return $0.nearbyObject?.distance ?? Float.infinity < $1.nearbyObject?.distance ?? Float.infinity
        })?.nearbyObject

        self.distanceInfo = sessionManager.accessories.map {
            if let distance = $0.value.nearbyObject?.distance, $0.value.lastSeen > Date.now - TimeInterval(5) {
                distances[$0.key] = distance
                return String(format: "%@: %0.2fm\n", $0.key, distance)
            } else {
                distances.removeValue(forKey: $0.key)
                return String(format: "%@: ?\n", $0.key)
            }
        }.joined()
    }
}

extension CameraAssistanceView: UWBManagerDelegate {
    func didUpdateAccessory(accessory: UWBAccessory) {
        if accessory.id == "afb69914c8527424b06698fd34227" {
            print("uwb: \(accessory.nearbyObject!.distance!)")
        }
        updateDistanceInfo()
    }
    
    func didConnect(accessory: BluetoothAccessory) {
        updateDistanceInfo()
    }
    
    func didFailToConnect(accessory: BluetoothAccessory) {
        updateDistanceInfo()
    }

    func didDisconnect(accessory: BluetoothAccessory) {
        updateDistanceInfo()
    }

    
    func log(_ message: String) {
        print(message)
    }
}

struct CalibrationDatapoint : Encodable {
    var rxX: Double
    var rxY: Double
    var rxZ: Double
    var txX: Double
    var txY: Double
    var txZ: Double
    var refRssi: Float
    var absorption: Float
    var node: String
    var deltaRssi: Float
}

extension CameraAssistanceView: ESPresenseManagerDelegate {
    func didUpdateAccessory(node: String, measurement: OpenUWB.Measurement) {
        let closestNode = self.espresenseManager.measurements.min(by: { $0.value.rssi > $1.value.rssi })?.key
        DispatchQueue.main.async {
            self.floorplanManager.closestNode = closestNode
        }

        var uwbDistances = [String: Float]()
        for uwbAccessory in sessionManager.accessories.values {
            if let distance = uwbAccessory.nearbyObject?.distance {
                uwbDistances[uwbAccessory.id] = distance
            }
        }

        guard let currentConvergenceContext = sessionManager.convergenceContext else { return }
        guard floorplanManager.locationOffsetValid, currentConvergenceContext.status == .converged else { return }
        print(node, floorplanManager.location.x, floorplanManager.location.y, floorplanManager.location.z, measurement.rssi)
    }
}

// Previews the view.
struct NICameraAssistanceView_Previews: PreviewProvider {
    static var previews: some View {
        CameraAssistanceView()
    }
}

#if !os(watchOS)
private class NIARSessionDelegate : NSObject, ARSessionDelegate {
    var minObservedHeight: Float = 0
    var floorplanManager: FloorplanManager!

    init(floorplanManager: FloorplanManager) {
        self.floorplanManager = floorplanManager
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return false
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        //let angle = (360 - 231) * Float.pi / 180
        let node = SCNNode()
        let cam = SCNMatrix4(frame.camera.transform)
        //let rotation = SCNMatrix4Rotate(SCNMatrix4Identity, -angle, 0, 1, 0)
        node.transform = cam //SCNMatrix4Mult(cam, rotation)
        if node.position.y < minObservedHeight {
            minObservedHeight = node.position.y
        }
        
        floorplanManager.rawLocation = simd_float3(node.position.x, -node.position.z, node.position.y)
        floorplanManager.location = floorplanManager.rawLocation + floorplanManager.locationOffset - simd_float3(0, 0, minObservedHeight)
    }
}
#endif

// A subview with the AR view.
struct NIARView: UIViewRepresentable {
    var sessionManager: UWBManager
    private var arSessionDelegate: NIARSessionDelegate

    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

    init(sessionManager: UWBManager, floorplanManager: FloorplanManager) {
        self.sessionManager = sessionManager
        self.arSessionDelegate = NIARSessionDelegate(floorplanManager: floorplanManager)
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Monitor ARKit session events.
        arView.session.delegate = arSessionDelegate

        // Create a world-tracking configuration to Nearby Interaction's
        // AR session requirements. For more information,
        // see the `setARSession` function of `NISession`.
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isCollaborationEnabled = false
        configuration.userFaceTrackingEnabled = false
        configuration.initialWorldMap = nil
        configuration.environmentTexturing = .automatic

        // Run the view's AR session.
        arView.session.run(configuration)

        // Add the blurred view by default at the start when creating the view.
        blurView.frame = arView.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(blurView)

        // Set the AR session into the interaction session prior to
        // running the interaction session so that the framework doesn't
        // create its own AR session.
        sessionManager.setARSession(arView.session)
            
        var uwbManagerOptions = UWBManagerOptions()
        if #available(iOS 16.0, *) {
            uwbManagerOptions.useCameraAssistance = true
        }
        sessionManager.run(options: uwbManagerOptions)
        
        // Return the AR view.
        return arView
    }

    // A coordinator for updating AR content.
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    // A coordinator class.
    @MainActor
    class Coordinator: NSObject {
        // A parent Nearby Interaction AR view.
        var parent: NIARView
        // Anchor entities for placing AR content in the AR world.
        var peerAnchors: [String: AnchorEntity] = [:]

        init( _ parent: NIARView) {
            self.parent = parent
        }

        func placeSpheresInView(_ arView: ARView, _ accessory: UWBAccessory, _ worldTransform: simd_float4x4) {
            // Create or update the anchor entity.
            if let peerAnchor = self.peerAnchors[accessory.publicIdentifier] {
                // Update the world transform.
                peerAnchor.transform.matrix = worldTransform
            } else {
                // Create the peer anchor only once.
                let peerAnchor = AnchorEntity(.world(transform: worldTransform))
                peerAnchors[accessory.publicIdentifier] = peerAnchor

                let sphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.05),
                                         materials: [SimpleMaterial(color: .systemPink,
                                                                     isMetallic: true)])

                // Add the model entity to the anchor entity.
                peerAnchor.addChild(sphere)

                // Add the anchor entity to the AR world.
                arView.scene.addAnchor(peerAnchor)
            }
        }

        // Updates the peer anchor.
        func updatePeerAnchor(arView: ARView, accessory: UWBAccessory, currentConvergenceContext: NIAlgorithmConvergence) {
            // Check whether the framework fully resolves the world transform.
            if currentConvergenceContext.status == .converged {
                // Hide the blur view.
                parent.blurView.isHidden = true

                // Compute the world transform and ensure it's present.
                guard let worldTransform = parent.sessionManager.worldTransform(for: accessory) else { return }
                
                // Place spheres into the view.
                placeSpheresInView(arView, accessory, worldTransform)

            } else {
                // Show the blur view when the status isn't fully converged.
                parent.blurView.isHidden = false

                // Remove any previously shown spheres.
                for peerAnchor in self.peerAnchors.values {
                    // Remove the peer anchor.
                    arView.scene.removeAnchor(peerAnchor)
                }

                // Reset the peer anchors.
                peerAnchors.removeAll()

                return
            }

        }
    }

    // Updates the AR view.
    func updateUIView(_ uiView: ARView, context: Context) {
        // Ensure the session manager has the latest convergence status.
        guard let currentConvergenceContext = sessionManager.convergenceContext else { return }

        for accessory in sessionManager.accessories.values {
            // Use the coordinator to update the AR view as needed based on the updated nearby object and convergence context.
            context.coordinator.updatePeerAnchor(arView: uiView,
                                                 accessory: accessory,
                                                 currentConvergenceContext: currentConvergenceContext)
        }
    }
}

// An overlay view for coaching or directing the user.
struct NICoachingOverlay: View {
    // Variables for horizontal angle, distance, and convergence.
    var horizontalAngle: Float?
    var distance: Float?
    var convergenceContext: NIAlgorithmConvergence?

    var body: some View {
        VStack {
            // Scale the image based on distance, if available.
            let distanceScale = distance == nil ? 0.5 : distance!.scale(minRange: 0.15, maxRange: 1.0, minDomain: 0.5, maxDomain: 2.0)
            let imageScale = (horizontalAngle == nil) ? 0.5 : distanceScale
            // Text to display that guides the user to move the phone up and down.
            let message = "Move phone up and down to see beacon location"
            let upDownText = (convergenceContext != nil && convergenceContext!.status != .converged) ? message : ""
            // The final guidance text.
            let guidanceText = distance == nil ? "Finding next beacon ..." : (horizontalAngle == nil ? "Move side to side" : "Head to the beacon")

            // Display an image to help guide the user.
            Image(systemName: distance == nil ? "sparkle.magnifyingglass" : (horizontalAngle == nil ? "move.3d" : "arrow.up.circle"))
                    .resizable()
                    .frame(width: 200 * CGFloat(imageScale), height: 200 * CGFloat(imageScale), alignment: .center)
            // Rotate the image by the horizontal angle, when available.
                .rotationEffect(.init(radians: Double(horizontalAngle ?? 0.0)))
            Text(guidanceText).frame(alignment: .center)
            Text(upDownText).frame(alignment: .center).opacity(
                horizontalAngle != nil && (convergenceContext != nil && convergenceContext!.status != .converged) ? 0.85 : 0)
        }
        // Remove the overlay if the status is converged.
        .opacity(convergenceContext != nil && convergenceContext!.status == .converged ? 0 : 1)
        .foregroundColor(.white)
    }
}
