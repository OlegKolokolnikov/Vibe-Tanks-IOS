import AVFoundation

/// Manages game sound effects and music
class SoundManager {

    static let shared = SoundManager()

    private var soundEffects: [String: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?

    private init() {
        setupAudioSession()
        preloadSounds()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func preloadSounds() {
        // Sound effects would be loaded from bundle
        // For now, we'll generate simple sounds programmatically
    }

    // MARK: - Sound Effects

    func playShoot() {
        playSystemSound(id: 1104) // Keyboard tap
    }

    func playExplosion() {
        playSystemSound(id: 1105) // Delete
    }

    func playPowerUp() {
        playSystemSound(id: 1025) // New mail
    }

    func playPlayerDeath() {
        playSystemSound(id: 1073) // Low power
    }

    func playVictory() {
        playSystemSound(id: 1111) // Payment success
    }

    func playGameOver() {
        playSystemSound(id: 1112) // Payment failure
    }

    private func playSystemSound(id: UInt32) {
        AudioServicesPlaySystemSound(SystemSoundID(id))
    }

    // MARK: - Music

    func playBackgroundMusic() {
        // Would load from bundle
        // For now, no background music
    }

    func stopBackgroundMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    func pauseBackgroundMusic() {
        musicPlayer?.pause()
    }

    func resumeBackgroundMusic() {
        musicPlayer?.play()
    }

    // MARK: - Volume Control

    var isMuted: Bool = false {
        didSet {
            musicPlayer?.volume = isMuted ? 0 : 1
        }
    }
}
