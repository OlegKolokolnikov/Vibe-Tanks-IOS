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

        for bullet in bullets {
            // Player bullets hit enemies
            if !bullet.isFromEnemy {
                for enemy in enemyTanks {
                    if enemy.isAlive && bullet.collidesWith(enemy) {
                        let wasPowerTank = enemy.enemyType == .power
                        enemy.damage()
                        bulletsToRemove.append(bullet)

                        // Power tanks drop power-up every time they are shot
                        if wasPowerTank {
                            spawnPowerUp(at: enemy.position)
                        }

                        if !enemy.isAlive {
                            enemiesToRemove.append(enemy)
                            let killedType = wasPowerTank ? Tank.EnemyType.power : enemy.enemyType
                            addScore(GameConstants.scoreForEnemyType(killedType))
                            playerKills += 1
                            killsByType[killedType, default: 0] += 1
                            SoundManager.shared.playExplosion()

                            // Other enemies have 20% chance to drop power-up when killed
                            if !wasPowerTank && Int.random(in: 1...5) == 1 {
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
                            SoundManager.shared.playPlayerDeath()
                            // Reset player freeze when killed
                            playerFreezeTimer = 0
                            playerTank.childNode(withName: "freezeEffect")?.removeFromParent()
                        }

                        if !playerTank.isAlive && playerTank.lives > 0 {
                            playerTank.respawn(at: CGPoint(
                                x: GameConstants.tileSize * 8,
                                y: GameConstants.tileSize * 2
                            ))
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

    /// Check bullets colliding with each other
    func checkBulletBulletCollisions() {
        guard bullets.count >= 2 else { return }

        var bulletsToRemove: Set<Bullet> = []

        for i in 0..<bullets.count {
            for j in (i+1)..<bullets.count {
                if bullets[i].collidesWith(bullets[j]) {
                    bulletsToRemove.insert(bullets[i])
                    bulletsToRemove.insert(bullets[j])
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
        for bullet in bullets {
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

        for bullet in bullets {
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
