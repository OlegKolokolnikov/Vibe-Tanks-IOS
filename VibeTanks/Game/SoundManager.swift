import SpriteKit
import AVFoundation

/// Manages game sound effects and music using pre-loaded AVAudioPlayers for performance
class SoundManager {

    static let shared = SoundManager()

    // Pre-loaded sound players (reusable)
    private var shootPlayers: [AVAudioPlayer] = []
    private var explosionPlayers: [AVAudioPlayer] = []
    private var introPlayer: AVAudioPlayer?
    private var sadPlayer: AVAudioPlayer?
    private var victoryPlayer: AVAudioPlayer?
    private var playerDeathPlayer: AVAudioPlayer?
    private var baseDestroyedPlayer: AVAudioPlayer?
    private var treeBurnPlayer: AVAudioPlayer?
    private var laserPlayer: AVAudioPlayer?
    private var powerUpSpawnPlayer: AVAudioPlayer?

    // Pool settings
    private let shootPoolSize = 3
    private let explosionPoolSize = 3
    private var shootIndex = 0
    private var explosionIndex = 0

    // Rate limiting for rapid sounds
    private var lastShootTime: TimeInterval = 0
    private var lastExplosionTime: TimeInterval = 0
    private let minSoundInterval: TimeInterval = 0.05  // 50ms minimum between same sounds

    // Music player
    private var musicPlayer: AVAudioPlayer?

    var isMuted: Bool = false

    private init() {
        setupAudioSession()
        preloadSounds()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session setup failed
        }
    }

    private func preloadSounds() {
        // Pre-load shoot sounds (pool for rapid fire)
        if let url = Bundle.main.url(forResource: "shoot", withExtension: "wav") {
            for _ in 0..<shootPoolSize {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = 0.4
                    player.prepareToPlay()
                    shootPlayers.append(player)
                }
            }
        }

        // Pre-load explosion sounds (pool)
        if let url = Bundle.main.url(forResource: "explosion", withExtension: "wav") {
            for _ in 0..<explosionPoolSize {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = 0.5
                    player.prepareToPlay()
                    explosionPlayers.append(player)
                }
            }
        }

        // Pre-load single-instance sounds
        introPlayer = loadPlayer("intro", volume: 0.6)
        sadPlayer = loadPlayer("sad", volume: 0.6)
        victoryPlayer = loadPlayer("victory", volume: 0.6)
        playerDeathPlayer = loadPlayer("player_death", volume: 0.6)
        baseDestroyedPlayer = loadPlayer("base_destroyed", volume: 0.7)
        treeBurnPlayer = loadPlayer("tree_burn", volume: 0.5)
        laserPlayer = loadPlayer("laser", volume: 0.4)
        powerUpSpawnPlayer = loadPlayer("powerup_spawn", volume: 0.5)

    }

    private func loadPlayer(_ name: String, volume: Float) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    // MARK: - Sound Effects

    func playShoot() {
        guard !isMuted, !shootPlayers.isEmpty else { return }

        // Rate limit rapid fire sounds
        let now = CACurrentMediaTime()
        guard now - lastShootTime >= minSoundInterval else { return }
        lastShootTime = now

        // Round-robin through the pool
        let player = shootPlayers[shootIndex]
        shootIndex = (shootIndex + 1) % shootPlayers.count

        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }

    func playExplosion() {
        guard !isMuted, !explosionPlayers.isEmpty else { return }

        // Rate limit
        let now = CACurrentMediaTime()
        guard now - lastExplosionTime >= minSoundInterval else { return }
        lastExplosionTime = now

        let player = explosionPlayers[explosionIndex]
        explosionIndex = (explosionIndex + 1) % explosionPlayers.count

        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }

    func playIntro() {
        guard !isMuted else { return }
        introPlayer?.currentTime = 0
        introPlayer?.play()
    }

    func playSad() {
        guard !isMuted else { return }
        sadPlayer?.currentTime = 0
        sadPlayer?.play()
    }

    func playVictory() {
        guard !isMuted else { return }
        victoryPlayer?.currentTime = 0
        victoryPlayer?.play()
    }

    func playPlayerDeath() {
        guard !isMuted else { return }
        playerDeathPlayer?.currentTime = 0
        playerDeathPlayer?.play()
    }

    func playBaseDestroyed() {
        guard !isMuted else { return }
        baseDestroyedPlayer?.currentTime = 0
        baseDestroyedPlayer?.play()
    }

    func playTreeBurn() {
        guard !isMuted else { return }
        treeBurnPlayer?.currentTime = 0
        treeBurnPlayer?.play()
    }

    func playLaser() {
        guard !isMuted else { return }
        laserPlayer?.currentTime = 0
        laserPlayer?.play()
    }

    func playPowerUpSpawn() {
        guard !isMuted else { return }
        powerUpSpawnPlayer?.currentTime = 0
        powerUpSpawnPlayer?.play()
    }

    func playPowerUp() {
        playPowerUpSpawn()
    }

    func playGameOver() {
        playSad()
    }

    // MARK: - Music

    func playExplanationMusic() {
        guard !isMuted else { return }

        if let url = Bundle.main.url(forResource: "explanation_music", withExtension: "wav") {
            do {
                musicPlayer = try AVAudioPlayer(contentsOf: url)
                musicPlayer?.numberOfLoops = -1
                musicPlayer?.volume = 0.3
                musicPlayer?.play()
            } catch {
                print("Failed to play explanation music: \(error)")
            }
        }
    }

    func playBackgroundMusic() {
        playExplanationMusic()
    }

    func stopBackgroundMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    func stopExplanationMusic() {
        stopBackgroundMusic()
    }

    func pauseBackgroundMusic() {
        musicPlayer?.pause()
    }

    func resumeBackgroundMusic() {
        musicPlayer?.play()
    }

    func stopGameplaySounds() {
        for player in shootPlayers {
            player.stop()
        }
        for player in explosionPlayers {
            player.stop()
        }
    }
}
