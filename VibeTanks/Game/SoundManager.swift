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

    /// Mute all sound. Saved to settings; silences sounds that are already playing.
    var isMuted: Bool = GameSettings.shared.isMuted {
        didSet {
            GameSettings.shared.isMuted = isMuted
            applyVolume()
        }
    }

    // Each player's own (relative) volume; the actual volume is base * masterVolume
    private var baseVolumes: [ObjectIdentifier: Float] = [:]
    private let musicBaseVolume: Float = 0.3

    /// Master volume 0...1, derived from the saved volume level (0 when muted)
    private var masterVolume: Float {
        guard !isMuted else { return 0 }
        return Float(volumeLevel) / Float(GameSettings.maxVolumeLevel)
    }

    /// Volume level 0...GameSettings.maxVolumeLevel. Saved to settings and applied immediately.
    var volumeLevel: Int = GameSettings.shared.volumeLevel {
        didSet {
            GameSettings.shared.volumeLevel = volumeLevel
            applyVolume()
        }
    }

    /// No sound should be played (muted or volume at 0)
    private var isSilent: Bool {
        isMuted || volumeLevel <= 0
    }

    private init() {
        setupAudioSession()
        preloadSounds()
        applyVolume()
    }

    /// Re-apply master volume to every loaded player
    private func applyVolume() {
        let master = masterVolume
        for player in allEffectPlayers {
            player.volume = (baseVolumes[ObjectIdentifier(player)] ?? 1.0) * master
        }
        musicPlayer?.volume = musicBaseVolume * master
    }

    private var allEffectPlayers: [AVAudioPlayer] {
        let singles: [AVAudioPlayer?] = [
            introPlayer, sadPlayer, victoryPlayer, playerDeathPlayer,
            baseDestroyedPlayer, treeBurnPlayer, laserPlayer, powerUpSpawnPlayer
        ]
        return shootPlayers + explosionPlayers + singles.compactMap { $0 }
    }

    private func setBaseVolume(_ volume: Float, for player: AVAudioPlayer) {
        baseVolumes[ObjectIdentifier(player)] = volume
        player.volume = volume * masterVolume
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
                    setBaseVolume(0.4, for: player)
                    player.prepareToPlay()
                    shootPlayers.append(player)
                }
            }
        }

        // Pre-load explosion sounds (pool)
        if let url = Bundle.main.url(forResource: "explosion", withExtension: "wav") {
            for _ in 0..<explosionPoolSize {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    setBaseVolume(0.5, for: player)
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
        setBaseVolume(volume, for: player)
        player.prepareToPlay()
        return player
    }

    // MARK: - Sound Effects

    func playShoot() {
        guard !isSilent, !shootPlayers.isEmpty else { return }

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
        guard !isSilent, !explosionPlayers.isEmpty else { return }

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
        guard !isSilent else { return }
        introPlayer?.currentTime = 0
        introPlayer?.play()
    }

    func playSad() {
        guard !isSilent else { return }
        sadPlayer?.currentTime = 0
        sadPlayer?.play()
    }

    func playVictory() {
        guard !isSilent else { return }
        victoryPlayer?.currentTime = 0
        victoryPlayer?.play()
    }

    func playPlayerDeath() {
        guard !isSilent else { return }
        playerDeathPlayer?.currentTime = 0
        playerDeathPlayer?.play()
    }

    func playBaseDestroyed() {
        guard !isSilent else { return }
        baseDestroyedPlayer?.currentTime = 0
        baseDestroyedPlayer?.play()
    }

    func playTreeBurn() {
        guard !isSilent else { return }
        treeBurnPlayer?.currentTime = 0
        treeBurnPlayer?.play()
    }

    func playLaser() {
        guard !isSilent else { return }
        laserPlayer?.currentTime = 0
        laserPlayer?.play()
    }

    func playPowerUpSpawn() {
        guard !isSilent else { return }
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
        guard !isSilent else { return }

        if let url = Bundle.main.url(forResource: "explanation_music", withExtension: "wav") {
            do {
                musicPlayer = try AVAudioPlayer(contentsOf: url)
                musicPlayer?.numberOfLoops = -1
                musicPlayer?.volume = musicBaseVolume * masterVolume
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
