import QuickLookThumbnailing
import SceneKit
import GLTFKit2

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let maximumSize = request.maximumSize
        let scale = request.scale

        GLTFAsset.load(with: request.fileURL, options: [:]) { (_, status, maybeAsset, maybeError, _) in
            guard status == .complete, let asset = maybeAsset else {
                if let error = maybeError {
                    handler(nil, error)
                }
                return
            }

            let scene = SCNScene(gltfAsset: asset)

            // Add lighting
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light!.type = .ambient
            ambientLight.light!.intensity = 400
            scene.rootNode.addChildNode(ambientLight)

            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light!.type = .directional
            directionalLight.light!.intensity = 800
            directionalLight.position = SCNVector3(5, 10, 5)
            directionalLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(directionalLight)

            // Set up camera
            let cameraNode = self.makeCameraForScene(scene)
            scene.rootNode.addChildNode(cameraNode)

            // Render offscreen
            let pixelWidth = Int(maximumSize.width * scale)
            let pixelHeight = Int(maximumSize.height * scale)

            let renderer = SCNRenderer(device: nil, options: nil)
            renderer.scene = scene
            renderer.pointOfView = cameraNode

            let image = renderer.snapshot(
                atTime: 0,
                with: CGSize(width: pixelWidth, height: pixelHeight),
                antialiasingMode: .multisampling4X
            )

            let reply = QLThumbnailReply(contextSize: maximumSize) { context in
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
                image.draw(in: CGRect(origin: .zero, size: maximumSize))
                NSGraphicsContext.restoreGraphicsState()
                return true
            }
            handler(reply, nil)
        }
    }

    private func makeCameraForScene(_ scene: SCNScene) -> SCNNode {
        let (minBound, maxBound) = scene.rootNode.boundingBox
        let center = SCNVector3(
            (minBound.x + maxBound.x) / 2,
            (minBound.y + maxBound.y) / 2,
            (minBound.z + maxBound.z) / 2
        )
        let size = SCNVector3(
            maxBound.x - minBound.x,
            maxBound.y - minBound.y,
            maxBound.z - minBound.z
        )
        let maxDimension = max(size.x, size.y, size.z)
        let distance = CGFloat(maxDimension) * 2.0

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.automaticallyAdjustsZRange = true
        cameraNode.position = SCNVector3(
            center.x + distance * 0.7,
            center.y + distance * 0.5,
            center.z + distance * 0.7
        )
        cameraNode.look(at: center)

        return cameraNode
    }
}
