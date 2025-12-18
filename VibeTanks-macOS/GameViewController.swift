import Cocoa
import SpriteKit

class GameViewController: NSViewController {

    private var skView: SKView!

    override func loadView() {
        // Create SKView as the main view
        skView = SKView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        self.view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup SpriteKit view
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Present menu scene
        let scene = MenuScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)

        // Make window key to receive keyboard events
        view.window?.makeFirstResponder(skView)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // Update scene size if window is resized
        if let scene = skView.scene {
            scene.size = skView.bounds.size
        }
    }
}
