-- zombies.lua
-- Zombie type rolling, stats, spawning, death effects, and powerup drops.

-- true once a zombie has walked into the playable arena (not still at the spawn edge)
function zombieInArena(z, bottom, top)
    return z.x >= 0 and z.x <= WIDTH and z.y >= bottom and z.y <= top
end

function rollZombieType(lvl)
    local roll = math.random()
    if lvl >= 3 and roll < 0.13 then return "fast"
    elseif lvl >= 4 and roll < 0.28 then return "shooter"
    elseif lvl >= 5 and roll < 0.38 then return "exploder"
    elseif lvl >= 6 and roll < 0.48 then return "shielded"
    elseif lvl >= 7 and roll < 0.56 then return "splitter"
    elseif lvl >= 5 and roll < 0.66 then return "charger"
    elseif lvl >= 8 and roll < 0.76 then return "necromancer"
    elseif lvl >= 6 and roll > 0.85 then return "tank"
    end
    return "normal"
end

-- true for every boss variant (see rollBossType) -- used anywhere code used to
-- check z.t == "boss" so the new boss types get the same treatment
function isBossType(t)
    return t == "boss" or t == "bosssummoner" or t == "bosscharger"
end

-- which boss shows up on a boss wave. The two new bosses unlock at higher
-- levels so early bosses stay simple and predictable.
function rollBossType(lvl)
    local options = {"boss"}
    if lvl >= 8 then table.insert(options, "bosssummoner") end
    if lvl >= 10 then table.insert(options, "bosscharger") end
    return options[math.random(#options)]
end

function zombieStats(t, levelN)
    local scale = 1 + (levelN - 1) * 0.13
    if t == "fast" then
        return { hp=18*scale, speed=130+levelN*4, r=S(20), col=color(120,224,138), coin=3, dmg=8 }
    elseif t == "tank" then
        return { hp=70*scale, speed=55+levelN*1.5, r=S(34), col=color(138,109,241), coin=8, dmg=20 }
    elseif t == "shooter" then
        return { hp=22*scale, speed=70+levelN*2, r=S(22), col=color(255,196,86), coin=6, dmg=10,
                 preferredRange=S(220), shotCount=1, shotDmg=8 }
    elseif t == "exploder" then
        return { hp=20*scale, speed=75+levelN*2, r=S(24), col=color(255,140,40), coin=7, dmg=10,
                 explodeDmg=25, explodeRadius=S(70) }
    elseif t == "shielded" then
        return { hp=20*scale, speed=70+levelN*2, r=S(24), col=color(90,200,220), coin=7, dmg=12,
                 shield=15*scale }
    elseif t == "splitter" then
        return { hp=30*scale, speed=65+levelN*2, r=S(28), col=color(180,220,90), coin=6, dmg=10,
                 splits=2 }
    elseif t == "charger" then
        return { hp=24*scale, speed=95+levelN*2, r=S(23), col=color(255,120,60), coin=6, dmg=16,
                 charge=true, dashSpeed=780, dashDuration=0.32, telegraphDuration=0.55,
                 chargeRange=S(260), chargeCdMin=1.4, chargeCdMax=2.6 }
    elseif t == "necromancer" then
        return { hp=34*scale, speed=55+levelN*1, r=S(24), col=color(160,70,200), coin=9, dmg=8,
                 preferredRange=S(260), healRadius=S(150), healPct=0.22, healCdMin=3.5, healCdMax=5.5 }
    elseif t == "boss" then
        return { hp=260*scale, speed=45+levelN*1, r=S(46), col=color(255,90,140), coin=30, dmg=28,
                 preferredRange=S(170), shotCount=3, shotDmg=12 }
    elseif t == "bosssummoner" then
        return { hp=230*scale, speed=48+levelN*1, r=S(46), col=color(120,200,90), coin=32, dmg=24,
                 preferredRange=S(190), shotCount=2, shotDmg=10,
                 summonCdMin=5, summonCdMax=8, summonCount=2 }
    elseif t == "bosscharger" then
        return { hp=300*scale, speed=52+levelN*1, r=S(46), col=color(255,70,70), coin=34, dmg=26,
                 charge=true, dashSpeed=680, dashDuration=0.40, telegraphDuration=0.60,
                 chargeRange=S(340), chargeCdMin=1.0, chargeCdMax=1.8 }
    else
        return { hp=26*scale, speed=85+levelN*2.2, r=S(26), col=color(224,93,93), coin=4, dmg=12 }
    end
end

function randomEdgePoint()
    local margin = S(40)
    local bottom, top = arenaBounds()
    local side = math.random(4)
    if side == 1 then return randInt(0, WIDTH), top + margin
    elseif side == 2 then return randInt(0, WIDTH), bottom - margin
    elseif side == 3 then return -margin, randInt(bottom, top)
    else return WIDTH + margin, randInt(bottom, top)
    end
end

-- posOverride = {x=, y=}, optional: spawn at a specific point instead of an
-- arena edge (used by boss-summoned minions)
function spawnZombie(t, levelOverride, posOverride)
    local lvl = levelOverride or wave
    local st = zombieStats(t, lvl)
    st.hp = st.hp * runDiff.hpMult
    st.dmg = st.dmg * runDiff.dmgMult
    st.speed = st.speed * runDiff.speedMult
    -- mild per-level scaling so damage keeps pace with healing, and coins keep pace with upgrade costs
    st.dmg = st.dmg * (1 + (lvl - 1) * 0.03)
    st.coin = st.coin * (1 + (lvl - 1) * 0.06)
    if st.shield then st.shield = st.shield * runDiff.hpMult end
    local ex, ey
    if posOverride then ex, ey = posOverride.x, posOverride.y
    else ex, ey = randomEdgePoint() end
    table.insert(zombies, {
        x=ex, y=ey, r=st.r, hp=st.hp, maxHp=st.hp,
        speed=st.speed, col=st.col, coin=st.coin, dmg=st.dmg,
        wob=math.random()*math.pi*2, t=t,
        preferredRange=st.preferredRange,
        shotCount=st.shotCount, shotDmg=st.shotDmg,
        shootCd = 0.8 + math.random(),
        shield = st.shield, maxShield = st.shield,
        explodeDmg = st.explodeDmg, explodeRadius = st.explodeRadius,
        splits = st.splits,
        -- charger / boss-charger: dash state machine (see updateCharger in update.lua)
        charge = st.charge, chargeState = st.charge and "walk" or nil,
        chargeTimer = st.charge and (0.4 + math.random()) or nil,
        dashSpeed = st.dashSpeed, dashDuration = st.dashDuration,
        telegraphDuration = st.telegraphDuration, chargeRange = st.chargeRange,
        chargeCdMin = st.chargeCdMin, chargeCdMax = st.chargeCdMax,
        dashDX = 0, dashDY = 0,
        -- necromancer: periodic heal pulse
        healRadius = st.healRadius, healPct = st.healPct,
        healCdMin = st.healCdMin, healCdMax = st.healCdMax,
        healCd = st.healCdMin and (1 + math.random() * 2) or nil,
        healPulse = 0,
        -- summoner boss: periodic reinforcements
        summonCdMin = st.summonCdMin, summonCdMax = st.summonCdMax, summonCount = st.summonCount,
        summonCd = st.summonCdMin and (2 + math.random() * 2) or nil,
    })
end

function spawnSplitBabies(z)
    for i = 1, 2 do
        local ang = math.random() * math.pi * 2
        local dist = S(20)
        table.insert(zombies, {
            x = z.x + math.cos(ang)*dist, y = z.y + math.sin(ang)*dist,
            r = z.r*0.6, hp = z.maxHp*0.35, maxHp = z.maxHp*0.35,
            speed = z.speed*1.15, col = z.col,
            coin = math.max(1, math.floor(z.coin*0.4)),
            dmg = math.max(4, math.floor(z.dmg*0.5)),
            wob = math.random()*math.pi*2, t = "splitterbaby",
            shootCd = 1, splits = 0,
        })
    end
end

-- necromancer: heals every zombie within healRadius by healPct of their max HP
function castHealPulse(caster)
    caster.healPulse = 0.35   -- visual ring duration, see drawWorld
    for _, z in ipairs(zombies) do
        if z ~= caster and z.hp < z.maxHp then
            local d = math.sqrt((z.x-caster.x)^2 + (z.y-caster.y)^2)
            if d <= caster.healRadius then
                local before = z.hp
                z.hp = math.min(z.maxHp, z.hp + z.maxHp * caster.healPct)
                if z.hp > before then spawnParticles(z.x, z.y, color(160,70,200), 6) end
            end
        end
    end
end

-- summoner boss: calls in a couple of ordinary zombies next to itself
function summonMinions(boss)
    if #zombies >= 40 then return end   -- avoid a runaway zombie count in long runs
    local lvl = (gameMode == "horde") and (1 + math.floor(survivalTime/20)) or wave
    shake(S(6))
    spawnParticles(boss.x, boss.y, boss.col, 14)
    for i = 1, boss.summonCount do
        local ang = math.random() * math.pi * 2
        local dist = boss.r + S(24)
        spawnZombie("normal", lvl, {x = boss.x + math.cos(ang)*dist, y = boss.y + math.sin(ang)*dist})
    end
end

function onZombieDeath(z)
    if z.t == "exploder" then
        local d = math.sqrt((z.x-player.x)^2 + (z.y-player.y)^2)
        spawnParticles(z.x, z.y, color(255,140,40), 20)
        shake(S(14))
        playSound("explode")
        if d <= (z.explodeRadius or S(70)) + player.r then
            damagePlayer(z.explodeDmg or 20)
        end
    elseif z.t == "splitter" and (z.splits or 0) > 0 then
        spawnSplitBabies(z)
    end
end

function maybeDropPowerup(x, y, guaranteed)
    -- health pickup: likelier the more hurt you are, always from bosses, max 2 on the field
    local onField = 0
    for _, p in ipairs(powerups) do if p.t == "health" then onField = onField + 1 end end
    local missing = 1 - math.max(0, player.hp) / player.maxHp
    healthPity = (healthPity or 0) + 1                 -- kills since last health drop
    local hpChance = 0
    if missing >= 0.05 then                            -- no point dropping when you're at full HP
        hpChance = math.min(0.6, 0.06 + missing * 0.30 + healthPity * 0.008)
    end
    if guaranteed then hpChance = 1.0 end
    if onField < 2 and math.random() < hpChance then
        healthPity = 0
        table.insert(powerups, {x=x + S(12), y=y, t="health", r=S(14), life=14})
    end

    local chance = guaranteed and 1.0 or 0.08
    if math.random() < chance then
        local types = {"speed", "damage", "coinburst", "shield"}
        local t = types[math.random(#types)]
        table.insert(powerups, {x=x, y=y, t=t, r=S(14), life=12})
    end
end
