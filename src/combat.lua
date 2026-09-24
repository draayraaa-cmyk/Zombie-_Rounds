-- combat.lua
-- Targeting, weapon firing, damage, kill rewards, explosions, powerup effects.

function nearestZombie()
    local target, bestD = nil, math.huge
    local bottom, top = arenaBounds()
    for _, z in ipairs(zombies) do
        -- ignore zombies that haven't walked into the arena yet
        if zombieInArena(z, bottom, top) then
            local d = (z.x-player.x)^2 + (z.y-player.y)^2
            if d < bestD then bestD = d; target = z end
        end
    end
    return target
end

function aimAngle()
    local target = nearestZombie()
    if target then return atan2(target.y - player.y, target.x - player.x) end
    return player.facing
end

-- ---------- weapons ----------

function firePistol(s)
    local baseAngle = aimAngle()
    local spread = s.multishot
    for i = 1, spread do
        local offset = (i - (spread+1)/2) * 0.14
        local ang = baseAngle + offset
        table.insert(bullets, {
            x=player.x, y=player.y, vx=math.cos(ang)*620, vy=math.sin(ang)*620,
            r=S(6), damage=s.damage, pierce=s.pierce, kind="normal",
        })
    end
end

function fireShotgun(s)
    local baseAngle = aimAngle()
    local pellets = 4 + s.multishot
    local spreadTotal = 0.7
    local dmgEach = s.damage * 0.5
    for i = 1, pellets do
        local offset = (i - (pellets+1)/2) * (spreadTotal/pellets)
        local ang = baseAngle + offset
        table.insert(bullets, {
            x=player.x, y=player.y, vx=math.cos(ang)*560, vy=math.sin(ang)*560,
            r=S(4), damage=dmgEach, pierce=1, kind="normal",
        })
    end
end

function fireLaser(s)
    local baseAngle = aimAngle()
    local spread = s.multishot
    for i = 1, spread do
        local offset = (i - (spread+1)/2) * 0.06
        local ang = baseAngle + offset
        table.insert(bullets, {
            x=player.x, y=player.y, vx=math.cos(ang)*900, vy=math.sin(ang)*900,
            r=S(5), damage=s.damage*1.3, pierce=99, kind="laser",
        })
    end
end

function fireGrenade(s)
    local baseAngle = aimAngle()
    local spread = s.multishot
    for i = 1, spread do
        local offset = (i - (spread+1)/2) * 0.18
        local ang = baseAngle + offset
        table.insert(bullets, {
            x=player.x, y=player.y, vx=math.cos(ang)*360, vy=math.sin(ang)*360,
            r=S(9), damage=0, pierce=0, kind="grenade", timer=0.9,
        })
    end
end

function fireBullet()
    local s = baseStats()
    playSound("shoot")
    if player.weapon == "shotgun" then fireShotgun(s)
    elseif player.weapon == "laser" then fireLaser(s)
    elseif player.weapon == "grenade" then fireGrenade(s)
    else firePistol(s)
    end
end

function tickFlamethrower(dt, s)
    local range = S(150)
    local halfAngle = 0.45 + (s.multishot - 1) * 0.10
    local dps = s.damage * s.fireRate * 1.4   -- scales with fire-rate upgrades
    if relicEnabled.pyromaniac then dps = dps * 1.25 end
    local ang = player.facing
    for i = #zombies, 1, -1 do
        local z = zombies[i]
        local dx, dy = z.x-player.x, z.y-player.y
        local dist = math.sqrt(dx*dx+dy*dy)
        if dist <= range + z.r then
            local zAng = atan2(dy, dx)
            local diff = math.abs((zAng - ang + math.pi) % (2*math.pi) - math.pi)
            if diff <= halfAngle then
                applyDamageToZombie(i, z, dps*dt)
                if math.random() < 0.3 then spawnParticles(z.x, z.y, color(255,140,60), 1) end
            end
        end
    end
    flameSoundTimer = (flameSoundTimer or 0) - dt
    if flameSoundTimer <= 0 then playSound("shoot"); flameSoundTimer = 0.25 end
end

function fireEnemyBullet(z)
    local ang = atan2(player.y - z.y, player.x - z.x)
    local n = z.shotCount or 1
    for i = 1, n do
        local offset = (i - (n+1)/2) * 0.22
        local a = ang + offset
        table.insert(enemyBullets, {
            x=z.x, y=z.y, vx=math.cos(a)*300, vy=math.sin(a)*300, r=S(7), dmg=z.shotDmg or 8,
        })
    end
end

-- ---------- damage ----------

function damagePlayer(amount)
    if relicEnabled.godmode or debugGod then return end
    if shieldTimeLeft > 0 then return end
    if pendingDeath then return end          -- already dying this frame

    tookDamageThisWave = true
    if relicEnabled.ironwill then amount = amount * 0.80 end

    player.hp = player.hp - amount
    hitFlash = 0.25
    shake(S(8))
    playSound("hurt")

    if player.hp <= 0 then
        if relicEnabled.secondwind and not usedSecondWind then
            usedSecondWind = true
            player.hp = math.floor(player.maxHp * 0.5)
            shake(S(20))
            showWaveBanner("Second Wind!")
            levelFlash = 1.0
        else
            player.hp = 0
            pendingDeath = true              -- update() ends the run at a safe point
        end
    end
end

function spawnParticles(x, y, col, n)
    for i = 1, n do
        local ang = math.random() * math.pi * 2
        local spd = 60 + math.random() * 140
        table.insert(particles, {
            x=x, y=y, vx=math.cos(ang)*spd, vy=math.sin(ang)*spd,
            life=0.4+math.random()*0.3, maxLife=0.7, col=col,
        })
    end
end

function popText(x, y, txt, col)
    table.insert(coinPops, { x=x, y=y, txt=txt, life=0.9, vy=40, col=col })
end

function rewardKill(z)
    local s = baseStats()
    combo = combo + 1
    if combo > bestCombo then bestCombo = combo end
    comboTimer = 1.2
    local comboMult = comboMultFor()

    local coinGain = math.floor(z.coin * s.coinMult * runDiff.rewardMult * comboMult + 0.5)
    local gemGain = math.floor(s.gemPerKill + 0.5)   -- combo only boosts coins, not gems
    coins = coins + coinGain
    gems = gems + gemGain
    lifetimeGemsEarned = lifetimeGemsEarned + gemGain
    kills = kills + 1
    lifetimeKills = lifetimeKills + 1
    popText(z.x, z.y - S(4), "+" .. coinGain, color(255,207,77))
    popText(z.x, z.y + S(16), "+" .. gemGain .. "g", color(120,220,255))
    spawnParticles(z.x, z.y, z.col, 16)
    playSound("hit")

    if player.weapon == "flamethrower" then
        lifetimeFlameKills = lifetimeFlameKills + 1
    end

    if relicEnabled.vampiric then
        vampKillCounter = vampKillCounter + 1
        if vampKillCounter >= 15 then
            vampKillCounter = 0
            player.hp = math.min(player.maxHp, player.hp + 2)
            popText(player.x, player.y - S(30), "+2 HP", color(255,120,190))
        end
    end

    if z.t == "boss" then
        lifetimeBossKills = lifetimeBossKills + 1
        shake(S(20))
        playSound("explode")
    end

    maybeDropPowerup(z.x, z.y, z.t == "boss")
    checkProgress()
end

function applyDamageToZombie(idx, z, dmg)
    if z.shield and z.shield > 0 then
        if dmg <= z.shield then
            z.shield = z.shield - dmg
            spawnParticles(z.x, z.y, color(90,200,220), 4)
            return
        else
            dmg = dmg - z.shield
            z.shield = 0
        end
    end
    z.hp = z.hp - dmg
    spawnParticles(z.x, z.y, z.col, 4)
    if z.hp <= 0 then
        onZombieDeath(z)
        rewardKill(z)
        table.remove(zombies, idx)
    end
end

function explodeGrenade(x, y)
    shake(S(16))
    playSound("explode")
    spawnParticles(x, y, color(255,160,60), 24)
    local s = baseStats()
    local radius = S(90)
    local dmg = s.damage * 1.6
    for k = #zombies, 1, -1 do
        local z = zombies[k]
        local d = math.sqrt((z.x-x)^2 + (z.y-y)^2)
        if d <= radius then applyDamageToZombie(k, z, dmg) end
    end
end

function applyPowerup(t)
    playSound("coin")
    shake(S(6))
    if t == "speed" then
        buffSpeedTimeLeft = 8
        popText(player.x, player.y - S(30), "SPEED UP!", color(120,220,255))
    elseif t == "damage" then
        buffDamageTimeLeft = 8
        popText(player.x, player.y - S(30), "DAMAGE UP!", color(255,120,120))
    elseif t == "shield" then
        shieldTimeLeft = 3
        popText(player.x, player.y - S(30), "SHIELDED!", color(255,255,255))
    elseif t == "health" then
        local heal = math.max(15, math.floor(player.maxHp * 0.25))
        local before = player.hp
        player.hp = math.min(player.maxHp, player.hp + heal)
        popText(player.x, player.y - S(30), "+" .. math.ceil(player.hp - before) .. " HP", color(255,120,190))
    elseif t == "coinburst" then
        local burst = 15 + wave*2
        coins = coins + burst
        popText(player.x, player.y - S(30), "+" .. burst, color(255,207,77))
    end
end
