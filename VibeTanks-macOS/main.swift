import Cocoa

// Create application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Create window
let windowRect = NSRect(x: 100, y: 100, width: 960, height: 640)
let window = NSWindow(
    contentRect: windowRect,
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "VibeTanks"
window.minSize = NSSize(width: 800, height: 600)
window.center()

// Set content view controller
let viewController = GameViewController()
window.contentViewController = viewController
window.makeKeyAndOrderFront(nil)

// Run application
app.run()
