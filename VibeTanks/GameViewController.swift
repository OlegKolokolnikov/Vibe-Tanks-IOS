import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private var hasSetupScene = false

    #if targetEnvironment(macCatalyst)
    // Mac overlay UI elements (positioned in letterbox area)
    private var scoreLabel: UILabel?
    private var pauseButton: UIButton?
    #endif

    override func loadView() {
        // Create SKView as the main view
        self.view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        #if targetEnvironment(macCatalyst)
        setupMacOverlay()
        setupNotificationObservers()
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func setupMacOverlay() {
        // Score label - positioned at top left in letterbox area
        let score = UILabel()
        score.text = "Score: 0"
        score.font = UIFont.boldSystemFont(ofSize: 24)
        score.textColor = .white
        score.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(score)
        scoreLabel = score

        // Pause button - positioned at top right in letterbox area
        let pause = UIButton(type: .system)
        pause.setTitle("⏸ Pause", for: .normal)
        pause.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        pause.setTitleColor(.white, for: .normal)
        pause.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        pause.layer.cornerRadius = 8
        pause.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        pause.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        pause.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pause)
        pauseButton = pause

        NSLayoutConstraint.activate([
            score.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            score.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),

            pause.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            pause.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScoreChange(_:)),
            name: .gameScoreDidChange,
            object: nil
        )
    }

    @objc private func handleScoreChange(_ notification: Notification) {
        if let score = notification.userInfo?["score"] as? Int {
            DispatchQueue.main.async {
                self.scoreLabel?.text = "Score: \(score)"
            }
        }
    }

    @objc private func pauseButtonTapped() {
        NotificationCenter.default.post(name: .gamePauseRequested, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    #endif

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Only setup scene once and after we have valid bounds
        guard !hasSetupScene, let skView = self.view as? SKView, skView.bounds.size.width > 0 else { return }
        hasSetupScene = true

        let scene = MenuScene(size: skView.bounds.size)
        #if targetEnvironment(macCatalyst)
        scene.scaleMode = .aspectFit
        #else
        scene.scaleMode = .aspectFill
        #endif

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

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
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
