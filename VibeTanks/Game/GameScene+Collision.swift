import SpriteKit

// MARK: - Collision Detection
extension GameScene {

    /// Main collision check entry point - called from update loop
    func checkAllCollisions() {
        checkBulletTankCollisions()
        checkBulletBulletCollisions()
        checkBulletBaseCollision()
        checkBulletUFOCollisions()
    }

    /// Check bullets hitting tanks (player bullets vs enemies, enemy bullets vs player)
    func checkBulletTankCollisions() {
        var bulletsToRemove: [Bullet] = []
        var enemiesToRemove: [Tank] = []

        for bullet in bullets where !isBulletRemoved(bullet) {
            // The friend (Gzhel tank) stops everyone else's bullets; only enemy bullets hurt it
            if let friend = gzhelTank, friend.isAlive, !bullet.isFromGzhel, bullet.collidesWith(friend) {
                bulletsToRemove.append(bullet)
                if bullet.isFromEnemy {
                    friend.damage()
                    if friend.isAlive {
                        flashFriendHit(friend)
                    } else {
                        SoundManager.shared.playExplosion()
                        dismissGzhelTank(killed: true)
                    }
                }
                continue
            }

            // Gzhel bullets destroy enemies (no score for the player) and can't hurt the player
            if bullet.isFromGzhel {
                if playerTank.isAlive && bullet.collidesWith(playerTank) {
                    bulletsToRemove.append(bullet)  // Absorbed harmlessly
                    continue
                }
                for enemy in enemyTanks where enemy.isAlive && bullet.collidesWith(enemy) {
                    enemy.damage()
                    bulletsToRemove.append(bullet)
                    if !enemy.isAlive {
                        enemiesToRemove.append(enemy)
                        SoundManager.shared.playExplosion()
                    }
                    break
                }
                continue
            }

            // Player bullets hit enemies
            if !bullet.isFromEnemy {
                for enemy in enemyTanks {
                    if enemy.isAlive && bullet.collidesWith(enemy) {
                        let wasPowerTank = enemy.enemyType == .power
                        if bullet.isLaser {
                            enemy.destroyInstantly()  // Laser kills any enemy with one shot
                        } else {
                            enemy.damage()
                        }
                        bulletsToRemove.append(bullet)

                        // Power tanks drop power-up every time they are shot
                        if wasPowerTank {
                            spawnPowerUp(at: enemy.position)
                        }

                        if !enemy.isAlive {
                            enemiesToRemove.append(enemy)
                            // scoreType survives the heavy→armored→regular visual downgrade
                            let killedType = enemy.scoreType
                            addScore(GameConstants.scoreForEnemyType(killedType))
                            playerKills += 1
                            killsByType[killedType, default: 0] += 1
                            SoundManager.shared.playExplosion()

                            if killedType == .alien {
                                // The alien always drops the LASER (its only source)
                                spawnPowerUp(at: enemy.position, type: .laser)
                                showEffect(text: "ALIEN DOWN!", color: .green)
                            } else if !wasPowerTank && Int.random(in: 1...5) == 1 {
                                // Other enemies have 20% chance to drop power-up when killed
                                spawnPowerUp(at: enemy.position)
                            }
                        }
                        break
                    }
                }
            }
            // Enemy bullets hit player
            else {
                if playerTank.isAlive && bullet.collidesWith(playerTank) {
                    if playerTank.hasShield {
                        // Bullet hits shield - destroy bullet but don't damage player
                        bulletsToRemove.append(bullet)
                    } else {
                        // No shield - damage player
                        playerTank.damage()
                        bulletsToRemove.append(bullet)

                        if !playerTank.isAlive {
                            handlePlayerKilled()
                        }
                    }
                }
            }
        }

        // Remove destroyed bullets
        for bullet in bulletsToRemove {
            removeBullet(bullet)
        }

        // Remove destroyed enemies
        if !enemiesToRemove.isEmpty {
            for enemy in enemiesToRemove {
                enemy.removeFromParent()
                enemyTanks.removeAll { $0 === enemy }
            }
            invalidateAllTanksCache()
        }
    }

    /// Shared cleanup when the player tank dies (bullet, bomb, etc.).
    /// Respawn itself is started from updatePlayer().
    func handlePlayerKilled() {
        SoundManager.shared.playPlayerDeath()
        playerFreezeTimer = 0
        playerTank.childNode(withName: "freezeEffect")?.removeFromParent()
    }

    /// Check bullets colliding with each other
    func checkBulletBulletCollisions() {
        guard bullets.count >= 2 else { return }

        var bulletsToRemove: Set<Bullet> = []

        for i in 0..<bullets.count {
            let a = bullets[i]
            guard !isBulletRemoved(a), !bulletsToRemove.contains(a) else { continue }
            for j in (i+1)..<bullets.count {
                let b = bullets[j]
                guard !isBulletRemoved(b), !bulletsToRemove.contains(b) else { continue }
                if a.isLaser || b.isLaser {
                    // Laser light burns through enemy bullets and keeps going;
                    // it passes through friendly bullets (and other lasers)
                    let laser = a.isLaser ? a : b
                    let other = a.isLaser ? b : a
                    if !other.isLaser && other.isFromEnemy && laser.collidesWith(other) {
                        bulletsToRemove.insert(other)
                    }
                    continue
                }
                if a.collidesWith(b) {
                    bulletsToRemove.insert(a)
                    bulletsToRemove.insert(b)
                    break
                }
            }
        }

        // Bullet vs bullet collision counts as obstacle
        for bullet in bulletsToRemove {
            removeBullet(bullet, hitObstacle: true)
        }
    }

    /// Check bullets hitting the base
    func checkBulletBaseCollision() {
        // Laser light passes the cat harmlessly (it also goes through the base walls)
        for bullet in bullets where !isBulletRemoved(bullet) && !bullet.isLaser {
            if base.checkCollision(bulletPosition: bullet.position) {
                base.destroy()
                removeBullet(bullet)
                SoundManager.shared.playBaseDestroyed()
                gameOver(won: false)
                break
            }
        }
    }

    /// Check bullets hitting UFO
    func checkBulletUFOCollisions() {
        guard let currentUFO = ufo, currentUFO.isAlive else { return }

        for bullet in bullets where !isBulletRemoved(bullet) {
            if currentUFO.collidesWith(bullet) {
                removeBullet(bullet)

                if currentUFO.damage() {
                    // UFO destroyed - spawn easter egg at random empty position
                    ufoWasKilled = true
                    currentUFO.createDestroyEffect()
                    currentUFO.removeFromParent()

                    // Spawn easter egg at random empty position
                    let eggPosition = findRandomEmptyPosition()
                    easterEgg = EasterEgg(x: eggPosition.x, y: eggPosition.y)
                    gameLayer.addChild(easterEgg!)

                    showUFOMessage("UFO DESTROYED!", color: .green)
                    ufo = nil
                }
                break
            }
        }
    }
}
