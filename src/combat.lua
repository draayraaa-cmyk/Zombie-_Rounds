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
    local w = player.weapon
    local n0 = #bullets
    if w == "shotgun" then fireShotgun(s)
    elseif w == "laser" then fireLaser(s)
    elseif w == "grenade" then fireGrenade(s)
    elseif w == "arc" then fireArc(s)
    elseif w == "crossbow" then fireCrossbow(s)
    elseif w == "mines" then fireMines(s)
    elseif w == "boomerang" then fireBoomerang(s)
    else firePistol(s)
    end
    -- credit kills to the weapon that fired the shot, even if you switch before it lands
    for i = n0 + 1, #bullets do bullets[i].src = w end
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
                applyDamageToZombie(i, z, dps*dt, "flamethrower")
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

function rewardKill(z, src)
    src = src or player.weapon
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

    weaponKills[src] = (weaponKills[src] or 0) + 1
    if src == "flamethrower" then
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

    if isBossType(z.t) then
        lifetimeBossKills = lifetimeBossKills + 1
        shake(S(20))
        playSound("explode")
    end

    maybeDropPowerup(z.x, z.y, isBossType(z.t))
    checkProgress()
end

function applyDamageToZombie(idx, z, dmg, src)
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
        rewardKill(z, src)
        table.remove(zombies, idx)
    end
end

function explodeAt(x, y, radius, dmg, src, shakeAmt)
    shake(S(shakeAmt or 16))
    playSound("explode")
    spawnParticles(x, y, color(255,160,60), 24)
    for k = #zombies, 1, -1 do
        local z = zombies[k]
        local d = math.sqrt((z.x-x)^2 + (z.y-y)^2)
        if d <= radius then applyDamageToZombie(k, z, dmg, src) end
    end
end

function explodeGrenade(x, y)
    local s = baseStats()
    explodeAt(x, y, S(90), s.damage * 1.6, "grenade", 16)
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

-- ============================================================
-- 1.1.0 ARSENAL: new weapons
-- ============================================================

-- fire-rate multiplier per weapon (1 = the stat's fire rate as-is)
weaponRateMult = {arc = 1.0, crossbow = 0.45, mines = 0.55, boomerang = 0.5}

-- damage a zombie by reference (safe when earlier hits in the same
-- effect already removed other zombies and shifted the indices)
function damageZombie(z, dmg, src)
    for i = #zombies, 1, -1 do
        if zombies[i] == z then applyDamageToZombie(i, z, dmg, src); return end
    end
end

-- ---------- Arc Gun: instant chain lightning ----------
function fireArc(s)
    local bottom, top = arenaBounds()
    local cands = {}
    for _, z in ipairs(zombies) do
        if zombieInArena(z, bottom, top) then cands[#cands + 1] = z end
    end
    if #cands == 0 then return end
    table.sort(cands, function(a, b)
        return (a.x-player.x)^2 + (a.y-player.y)^2 < (b.x-player.x)^2 + (b.y-player.y)^2
    end)

    local bolts = math.min(s.multishot, #cands)          -- multishot = extra bolts
    local jumps = 1 + s.pierce + (relicEnabled.stormcaller and 2 or 0)   -- pierce = extra jumps
    local range = S(170)
    local used = {}
    for i = 1, bolts do
        local cur
        for _, z in ipairs(cands) do if not used[z] then cur = z; break end end
        if not cur then break end

        local pts = {{x = player.x, y = player.y}}
        local chain = {}
        local hop = 0
        while cur and hop <= jumps do
            used[cur] = true
            chain[#chain + 1] = {z = cur, dmg = s.damage * 1.1 * (0.85 ^ hop)}
            pts[#pts + 1] = {x = cur.x, y = cur.y}
            local nxt, nd = nil, range * range
            for _, z in ipairs(cands) do
                if not used[z] then
                    local d = (z.x-cur.x)^2 + (z.y-cur.y)^2
                    if d < nd then nd = d; nxt = z end
                end
            end
            cur = nxt
            hop = hop + 1
        end
        table.insert(arcs, {pts = pts, life = 0.18})
        for _, c in ipairs(chain) do damageZombie(c.z, c.dmg, "arc") end
    end
end

-- ---------- Crossbow: slow, heavy, pierces everything, knocks back ----------
function fireCrossbow(s)
    local baseAngle = aimAngle()
    local n = s.multishot
    local dmg = s.damage * 3.2 * (relicEnabled.heavybolts and 1.4 or 1)
    for i = 1, n do
        local ang = baseAngle + (i - (n+1)/2) * 0.10
        table.insert(bullets, {
            x=player.x, y=player.y, vx=math.cos(ang)*700, vy=math.sin(ang)*700,
            r=S(6), damage=dmg, pierce=99, kind="bolt",
        })
    end
end

-- ---------- Mine Layer: drops mines that arm, then blow up near zombies ----------
function fireMines(s)
    local n = s.multishot
    local rel = relicEnabled.demolitionist and 1.4 or 1
    for i = 1, n do
        local ang = math.random() * math.pi * 2
        local off = (n > 1) and S(34) or 0
        table.insert(mines, {
            x = player.x + math.cos(ang) * off, y = player.y + math.sin(ang) * off,
            r = S(9), arm = 0.7, life = 14, trigger = S(34),
            radius = S(80) * rel, damage = s.damage * 2.4 * rel,
        })
    end
    local cap = 5 + n * 2
    while #mines > cap do table.remove(mines, 1) end
end

function updateMines(dt)
    for i = #mines, 1, -1 do
        local m = mines[i]
        m.life = m.life - dt
        if m.arm > 0 then m.arm = m.arm - dt end
        local trip = false
        if m.arm <= 0 then
            for _, z in ipairs(zombies) do
                local d = math.sqrt((m.x-z.x)^2 + (m.y-z.y)^2)
                if d < z.r + m.trigger then trip = true; break end
            end
        end
        if trip then
            table.remove(mines, i)
            explodeAt(m.x, m.y, m.radius, m.damage, "mines", 12)
        elseif m.life <= 0 then
            table.remove(mines, i)
        end
    end
end

-- ---------- Boomerang: out, then back to you; hits on both passes ----------
function fireBoomerang(s)
    local n = s.multishot
    local alive = 0
    for _, b in ipairs(bullets) do if b.kind == "boomerang" then alive = alive + 1 end end
    if alive >= n * 2 + 1 then return end
    local baseAngle = aimAngle()
    local rel = relicEnabled.razorwind
    local speed = 480
    for i = 1, n do
        local ang = baseAngle + (i - (n+1)/2) * 0.35
        table.insert(bullets, {
            x=player.x, y=player.y, vx=math.cos(ang)*speed, vy=math.sin(ang)*speed, speed=speed,
            r=S(12), damage=s.damage * 1.4 * (rel and 1.35 or 1), pierce=999999, kind="boomerang",
            phase="out", travel=0, maxDist=S(300) * (rel and 1.25 or 1), spin=0, life=6,
        })
    end
end

-- returns false when the boomerang should be removed
function updateBoomerang(b, dt)
    b.life = b.life - dt
    if b.life <= 0 then return false end
    b.spin = b.spin + dt * 14
    if b.phase == "out" then
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.travel = b.travel + b.speed * dt
        local outside = b.x < 0 or b.x > WIDTH or b.y < 0 or b.y > HEIGHT
        if b.travel >= b.maxDist or outside then
            b.phase = "back"
            b.hit = {}               -- can hit everything again on the way home
        end
    else
        local dx, dy = player.x - b.x, player.y - b.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < player.r + b.r then return false end
        local sp = b.speed * 1.15
        b.x = b.x + dx / dist * sp * dt
        b.y = b.y + dy / dist * sp * dt
    end
    return true
end

-- ---------- Orbital Blades: continuous, orbit the player ----------
function bladeCount(s)
    local n = 1 + s.multishot
    if relicEnabled.whirlwind then n = n + 1 end
    return math.min(n, 8)
end

function bladePositions(s)
    local n = bladeCount(s)
    local R = S(78)
    local out = {}
    for i = 1, n do
        local a = bladeAngle + (i - 1) * (2 * math.pi / n)
        out[i] = {x = player.x + math.cos(a) * R, y = player.y + math.sin(a) * R, a = a}
    end
    return out
end

function tickBlades(dt, s)
    local spin = 3.6 * (relicEnabled.whirlwind and 1.25 or 1)
    bladeAngle = (bladeAngle + spin * dt) % (2 * math.pi)
    local dmg = s.damage * s.fireRate * 0.7
    local now = love.timer.getTime()
    local pos = bladePositions(s)
    local bladeR = S(16)
    for zi = #zombies, 1, -1 do
        local z = zombies[zi]
        for bi, p in ipairs(pos) do
            if zombies[zi] ~= z then break end       -- z was killed by an earlier blade
            local d = math.sqrt((p.x-z.x)^2 + (p.y-z.y)^2)
            if d < z.r + bladeR then
                z.bladeAt = z.bladeAt or {}
                if now - (z.bladeAt[bi] or -1) >= 0.4 then
                    z.bladeAt[bi] = now
                    applyDamageToZombie(zi, z, dmg, "blades")
                end
            end
        end
    end
end
