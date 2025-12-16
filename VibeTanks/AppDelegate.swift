import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Pause game when app becomes inactive
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save game state if needed
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Resume game
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any paused tasks
    }
}
