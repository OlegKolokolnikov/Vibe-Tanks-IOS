import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private var hasSetupScene = false

    override func loadView() {
        // Create SKView as the main view
        self.view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Only setup scene once and after we have valid bounds
        guard !hasSetupScene, let skView = self.view as? SKView, skView.bounds.size.width > 0 else { return }
        hasSetupScene = true

        let scene = MenuScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill

        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = true

        // Set to 60 FPS
        skView.preferredFramesPerSecond = 60

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // MARK: - Keyboard Support

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Forward to the current scene
        guard let skView = view as? SKView, let scene = skView.scene else {
            super.pressesBegan(presses, with: event)
            return
        }
        scene.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Forward to the current scene
        guard let skView = view as? SKView, let scene = skView.scene else {
            super.pressesEnded(presses, with: event)
            return
        }
        scene.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Forward to the current scene
        guard let skView = view as? SKView, let scene = skView.scene else {
            super.pressesCancelled(presses, with: event)
            return
        }
        scene.pressesCancelled(presses, with: event)
    }
}
