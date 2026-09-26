-- update.lua
-- Per-frame simulation. love.update (in main.lua) calls update(dt).
-- update() is a short pipeline of small steps; the order matters:
--   timers -> player -> bullets -> (death?) -> spawning -> zombies -> (death?)
--   -> enemy bullets -> (death?) -> powerups -> wave clear -> effects

function keyboardDir()
    local kx, ky = 0, 0
    local kd = love.keyboard.isDown
    if kd("a", "left") then kx = kx - 1 end
    if kd("d", "right") then kx = kx + 1 end
    if kd("s", "down") then ky = ky - 1 end
    if kd("w", "up") then ky = ky + 1 end
    if kx ~= 0 or ky ~= 0 then
        local len = math.sqrt(kx*kx + ky*ky)
        return kx/len, ky/len
    end
    return 0, 0
end

-- ---------- timers ----------

local function updateBuffs(dt)
    if buffSpeedTimeLeft > 0 then buffSpeedTimeLeft = math.max(0, buffSpeedTimeLeft - dt) end
    if buffDamageTimeLeft > 0 then buffDamageTimeLeft = math.max(0, buffDamageTimeLeft - dt) end
    if shieldTimeLeft > 0 then shieldTimeLeft = math.max(0, shieldTimeLeft - dt) end
    if freezeTimeLeft > 0 then freezeTimeLeft = math.max(0, freezeTimeLeft - dt) end
    if magnetTimeLeft > 0 then magnetTimeLeft = math.max(0, magnetTimeLeft - dt) end
end

-- global movement multiplier while a Freeze pickup is active. Exempt from a
-- charger's telegraph/dash timers -- those are fixed-duration state changes,
-- not ongoing movement, so freezing them would just pause the fight oddly.
local function freezeFactor()
    return (freezeTimeLeft > 0) and 0.15 or 1.0
end

-- passive HP regen from the Regeneration upgrades
local function updateRegen(dt, s)
    if s.regenPerSec > 0 and player.hp < player.maxHp then
        player.hp = math.min(player.maxHp, player.hp + s.regenPerSec * dt)
    end
end

-- Roulette mode: force a random unlocked weapon every 30 seconds
local function randomUnlockedWeapon(exclude)
    local pool = {}
    for _, d in ipairs(weaponDefs) do
        if unlockedWeapons[d.key] and d.key ~= exclude then pool[#pool+1] = d.key end
    end
    if #pool == 0 then return exclude end
    return pool[math.random(#pool)]
end

local function updateRoulette(dt)
    if gameMode ~= "roulette" then return end
    rouletteTimer = rouletteTimer - dt
    if rouletteTimer <= 0 then
        player.weapon = randomUnlockedWeapon(player.weapon)
        rouletteTimer = 30
        playSound("click")
        showWaveBanner("New weapon: " .. currentWeaponDef().name .. "!")
    end
end

-- ---------- player ----------

-- joystick / keyboard movement, clamped to the arena. Returns the move vector used.
local function movePlayer(dt, s)
    local mx, my, sens = moveX, moveY, joySensValue()
    local kx, ky = keyboardDir()
    if kx ~= 0 or ky ~= 0 then mx, my, sens = kx, ky, 1.0 end

    if mx ~= 0 or my ~= 0 then
        player.x = player.x + mx * s.speed * dt * sens
        player.y = player.y + my * s.speed * dt * sens
    end
    local bottom, top = arenaBounds()
    player.x = math.max(player.r+4, math.min(WIDTH - player.r-4, player.x))
    player.y = math.max(bottom + player.r+4, math.min(top - player.r-4, player.y))
    return mx, my
end

local function updatePlayer(dt, s)
    local mx, my = movePlayer(dt, s)

    local target = nearestZombie()
    if target then
        player.facing = atan2(target.y - player.y, target.x - player.x)
    elseif mx ~= 0 or my ~= 0 then
        player.facing = atan2(my, mx)
    end

    player.fireCd = player.fireCd - dt
    local w = player.weapon
    if w == "flamethrower" then
        tickFlamethrower(dt, s)
    elseif w == "blades" then
        tickBlades(dt, s)
    elseif player.fireCd <= 0 and target then
        fireBullet()
        player.fireCd = 1 / (s.fireRate * (weaponRateMult[w] or 1))
    end
end

-- ---------- player bullets ----------

local function moveBullets(dt)
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        if b.kind == "boomerang" then
            if not updateBoomerang(b, dt) then table.remove(bullets, i) end
        else
            b.x = b.x + b.vx*dt
            b.y = b.y + b.vy*dt
            if b.kind == "grenade" then b.timer = b.timer - dt end
            if b.x < -40 or b.x > WIDTH+40 or b.y < -40 or b.y > HEIGHT+40 then
                table.remove(bullets, i)
            end
        end
    end
end

local function resolveBulletHits()
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        if b.kind == "grenade" then
            local exploded = (b.timer <= 0)
            if not exploded then
                for _, z in ipairs(zombies) do
                    local d = math.sqrt((b.x-z.x)^2 + (b.y-z.y)^2)
                    if d < z.r + b.r then exploded = true; break end
                end
            end
            if exploded then
                explodeGrenade(b.x, b.y)
                table.remove(bullets, i)
            end
        else
            b.hit = b.hit or {}      -- zombies this bullet already passed through
            for j = #zombies, 1, -1 do
                local z = zombies[j]
                if not b.hit[z] then
                    local d = math.sqrt((b.x-z.x)^2 + (b.y-z.y)^2)
                    if d < z.r + b.r then
                        b.hit[z] = true
                        applyDamageToZombie(j, z, b.damage, b.src)
                        if b.kind == "bolt" and z.hp > 0 then
                            local sp = math.sqrt(b.vx*b.vx + b.vy*b.vy)
                            local kb = S(26) * (relicEnabled.heavybolts and 1.6 or 1)
                            z.x = z.x + b.vx / sp * kb
                            z.y = z.y + b.vy / sp * kb
                        end
                        b.pierce = b.pierce - 1
                        if b.pierce <= 0 then table.remove(bullets, i); break end
                    end
                end
            end
        end
    end
end

local function updateBullets(dt)
    moveBullets(dt)
    resolveBulletHits()
end

-- ---------- spawning ----------

local function updateClassicSpawning(dt)
    if waveActive and #spawnQueue > 0 then
        spawnTimer = spawnTimer - dt
        if spawnTimer <= 0 then
            spawnZombie(table.remove(spawnQueue, 1))
            spawnTimer = math.max(0.25, 0.85 - wave*0.02)
        end
    end
end

local function updateHordeSpawning(dt)
    survivalTime = survivalTime + dt
    hordeSpawnTimer = hordeSpawnTimer - dt
    if hordeSpawnTimer <= 0 then
        local lvl = 1 + math.floor(survivalTime/20)
        spawnZombie(rollZombieType(lvl), lvl)
        hordeSpawnTimer = math.max(0.22, 0.9 - survivalTime*0.006)
    end
    if survivalTime - lastBossTime >= 60 then
        local lvl = 1 + math.floor(survivalTime/20)
        spawnZombie(rollBossType(lvl), lvl)
        lastBossTime = survivalTime
    end
    local minute = math.floor(survivalTime/60)
    if minute > lastAnnouncedMinute and minute > 0 then
        lastAnnouncedMinute = minute
        showWaveBanner(minute .. " minute" .. (minute > 1 and "s" or "") .. " survived!")
        levelFlash = 1.0
    end
    if survivalTime > bestSurvivalTime then bestSurvivalTime = survivalTime end
end

local function updateSpawning(dt)
    if gameMode == "classic" or gameMode == "roulette" then
        updateClassicSpawning(dt)
    elseif gameMode == "horde" then
        updateHordeSpawning(dt)
    end
end

-- ---------- enemies ----------

-- Charger / boss-charger: walk normally until in range and off cooldown, then
-- stand still and telegraph (so the player gets a fair chance to dodge),
-- then commit to a straight-line dash in the locked direction, then recover.
local function updateCharger(z, dt, distToPlayer)
    if z.chargeState == "walk" then
        z.chargeTimer = math.max(0, z.chargeTimer - dt)
        if z.chargeTimer <= 0 and distToPlayer <= z.chargeRange then
            z.chargeState = "telegraph"
            z.chargeTimer = z.telegraphDuration
            local ang = atan2(player.y - z.y, player.x - z.x)
            z.dashDX, z.dashDY = math.cos(ang), math.sin(ang)
        else
            local ang = atan2(player.y - z.y, player.x - z.x)
            z.x = z.x + math.cos(ang) * z.speed * freezeFactor() * dt
            z.y = z.y + math.sin(ang) * z.speed * freezeFactor() * dt + math.sin(z.wob)*0.15
        end
    elseif z.chargeState == "telegraph" then
        z.chargeTimer = z.chargeTimer - dt
        if z.chargeTimer <= 0 then
            z.chargeState = "dash"
            z.chargeTimer = z.dashDuration
        end
    elseif z.chargeState == "dash" then
        z.chargeTimer = z.chargeTimer - dt
        z.x = z.x + z.dashDX * z.dashSpeed * dt
        z.y = z.y + z.dashDY * z.dashSpeed * dt
        if z.chargeTimer <= 0 then
            z.chargeState = "recover"
            z.chargeTimer = 0.45
        end
    elseif z.chargeState == "recover" then
        z.chargeTimer = z.chargeTimer - dt
        if z.chargeTimer <= 0 then
            z.chargeState = "walk"
            z.chargeTimer = z.chargeCdMin + math.random() * (z.chargeCdMax - z.chargeCdMin)
        end
    end
end

-- Necromancer: holds at range like a shooter, but casts a heal pulse on a
-- cooldown instead of firing.
local function updateNecromancer(z, dt, distToPlayer, bottom, top)
    if zombieInArena(z, bottom, top) and distToPlayer <= z.preferredRange then
        z.healCd = z.healCd - dt
        if z.healCd <= 0 then
            castHealPulse(z)
            z.healCd = z.healCdMin + math.random() * (z.healCdMax - z.healCdMin)
        end
        z.x = z.x + math.cos(z.wob) * 20 * freezeFactor() * dt
    else
        local ang = atan2(player.y - z.y, player.x - z.x)
        z.x = z.x + math.cos(ang) * z.speed * freezeFactor() * dt
        z.y = z.y + math.sin(ang) * z.speed * freezeFactor() * dt + math.sin(z.wob)*0.15
    end
    if z.healPulse > 0 then z.healPulse = math.max(0, z.healPulse - dt) end
end

local function updateZombies(dt)
    local bottom, top = arenaBounds()
    for i = #zombies, 1, -1 do
        local z = zombies[i]
        z.wob = z.wob + dt*4
        local distToPlayer = math.sqrt((z.x-player.x)^2 + (z.y-player.y)^2)

        if z.charge then
            updateCharger(z, dt, distToPlayer)
        elseif z.t == "necromancer" then
            updateNecromancer(z, dt, distToPlayer, bottom, top)
        -- ranged zombies only stop and shoot once they are inside the arena;
        -- until then they keep walking in, so nothing fires from off-screen
        elseif z.preferredRange and zombieInArena(z, bottom, top) and distToPlayer <= z.preferredRange then
            z.shootCd = z.shootCd - dt
            if z.shootCd <= 0 then
                fireEnemyBullet(z)
                z.shootCd = (isBossType(z.t) and 1.4 or 1.7) + math.random()*0.6
            end
            z.x = z.x + math.cos(z.wob) * 20 * freezeFactor() * dt
        else
            local ang = atan2(player.y - z.y, player.x - z.x)
            z.x = z.x + math.cos(ang) * z.speed * freezeFactor() * dt
            z.y = z.y + math.sin(ang) * z.speed * freezeFactor() * dt + math.sin(z.wob)*0.15
        end

        if z.t == "bosssummoner" then
            z.summonCd = z.summonCd - dt
            if z.summonCd <= 0 then
                summonMinions(z)
                z.summonCd = z.summonCdMin + math.random() * (z.summonCdMax - z.summonCdMin)
            end
        end

        if distToPlayer < z.r + player.r then
            if z.t == "exploder" then
                -- detonates on contact: blast damage + effects come from onZombieDeath,
                -- so skip the separate contact hit (would double-damage the player)
                onZombieDeath(z)
            else
                damagePlayer(z.dmg)
            end
            spawnParticles(z.x, z.y, z.col, 10)
            table.remove(zombies, i)
        end
    end
end

local function updateEnemyBullets(dt)
    for i = #enemyBullets, 1, -1 do
        local b = enemyBullets[i]
        b.x = b.x + b.vx*dt
        b.y = b.y + b.vy*dt
        if b.x < -40 or b.x > WIDTH+40 or b.y < -40 or b.y > HEIGHT+40 then
            table.remove(enemyBullets, i)
        else
            local d = math.sqrt((b.x-player.x)^2 + (b.y-player.y)^2)
            if d < b.r + player.r then
                damagePlayer(b.dmg)
                spawnParticles(b.x, b.y, color(255,120,120), 6)
                table.remove(enemyBullets, i)
            end
        end
    end
end

-- ---------- pickups ----------

local function updatePowerups(dt)
    for i = #powerups, 1, -1 do
        local p = powerups[i]
        p.life = p.life - dt
        if magnetTimeLeft > 0 then
            local dx, dy = player.x - p.x, player.y - p.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 1 then
                local pull = math.min(dist, 260 * dt)
                p.x = p.x + dx / dist * pull
                p.y = p.y + dy / dist * pull
            end
        end
        local d = math.sqrt((p.x-player.x)^2 + (p.y-player.y)^2)
        if d < p.r + player.r then
            applyPowerup(p.t)
            table.remove(powerups, i)
        elseif p.life <= 0 then
            table.remove(powerups, i)
        end
    end
end

-- ---------- classic-mode wave flow ----------

local function onWaveCleared(s)
    waveActive = false
    waveClearDelay = 1.6
    local bonus = math.floor((10 + wave*3) * s.coinMult * runDiff.rewardMult + 0.5)
    local gemBonus = math.floor((1 + wave/4) + 0.5)
    coins = coins + bonus
    gems = gems + gemBonus
    lifetimeGemsEarned = lifetimeGemsEarned + gemBonus
    local hpBefore = player.hp
    player.hp = math.min(player.maxHp, player.hp + math.ceil(player.maxHp * 0.10))
    if player.hp > hpBefore then
        popText(player.x, player.y + S(50), "+" .. math.ceil(player.hp - hpBefore) .. " HP", color(255,120,190))
    end
    popText(player.x, player.y + S(70), "+" .. bonus, color(255,207,77))
    popText(player.x, player.y + S(90), "+" .. gemBonus .. "g", color(120,220,255))
    showWaveBanner("Wave " .. wave .. " Cleared! +" .. bonus)
    levelFlash = 1.0
    playSound("coin")
    if not tookDamageThisWave then
        noHitWavesCleared = noHitWavesCleared + 1
    end
    persistMeta()
end

local function updateWaveFlow(dt, s)
    if gameMode ~= "classic" and gameMode ~= "roulette" then return end

    if waveActive and #spawnQueue == 0 and #zombies == 0 then
        onWaveCleared(s)
    end
    if (not waveActive) and waveClearDelay > 0 then
        waveClearDelay = waveClearDelay - dt
        if waveClearDelay <= 0 then
            wave = wave + 1
            touchBestWave()
            startWave()
            checkProgress()
        end
    end
end

-- ---------- cosmetic timers / effects ----------

local function updateEffects(dt)
    if comboTimer > 0 then
        comboTimer = comboTimer - dt
        if comboTimer <= 0 then combo = 0 end
    end

    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i)
        else
            p.x = p.x + p.vx*dt
            p.y = p.y + p.vy*dt
            p.vx = p.vx * 0.92
            p.vy = p.vy * 0.92
        end
    end

    for i = #coinPops, 1, -1 do
        local c = coinPops[i]
        c.life = c.life - dt
        c.y = c.y + c.vy*dt
        c.vy = c.vy * 0.95
        if c.life <= 0 then table.remove(coinPops, i) end
    end

    for i = #arcs, 1, -1 do
        arcs[i].life = arcs[i].life - dt
        if arcs[i].life <= 0 then table.remove(arcs, i) end
    end

    if hitFlash > 0 then hitFlash = hitFlash - dt end
    if waveBannerAlpha > 0 then waveBannerAlpha = math.max(0, waveBannerAlpha - dt/1.6) end
end

-- ---------- main entry ----------

function update(dt)
    -- screen effects keep decaying even when not playing (menus, paused, game over)
    if shakeAmount > 0 then shakeAmount = math.max(0, shakeAmount - dt * S(240)) end
    if levelFlash > 0 then levelFlash = math.max(0, levelFlash - dt * 2.2) end

    if state ~= "playing" then return end
    local s = baseStats()

    updateBuffs(dt)
    updateRegen(dt, s)
    updateRoulette(dt)
    updatePlayer(dt, s)
    updateBullets(dt)
    updateMines(dt)
    if checkDeath() then return end

    updateSpawning(dt)
    updateZombies(dt)
    if checkDeath() then return end

    updateEnemyBullets(dt)
    if checkDeath() then return end

    updatePowerups(dt)
    updateWaveFlow(dt, s)
    updateEffects(dt)
end
