-- stats.lua
-- Upgrade levels/costs, derived player stats, and small gameplay helpers.

function levelOf(key) return upgrades[key] or 0 end
function permLevelOf(key) return permUpgrades[key] or 0 end

function costOf(def) return math.floor(def.base * (def.growth ^ levelOf(def.key)) + 0.5) end
function permCostOf(def) return math.floor(def.base * (def.growth ^ permLevelOf(def.key)) + 0.5) end

function joySensValue()
    local vals = {0.8, 1.0, 1.3}
    return vals[joySensIndex] or 1.0
end
function joySensLabel()
    local labels = {"LOW", "NORMAL", "HIGH"}
    return labels[joySensIndex] or "NORMAL"
end

function skinColorFor(key)
    for _, d in ipairs(skinDefs) do if d.key == key then return d.col end end
    return color(61,220,132)
end

function comboMultFor()
    local rate = relicEnabled.combomaster and 0.04 or 0.02
    local cap = relicEnabled.combomaster and 50 or 25
    return 1 + math.min(combo, cap) * rate
end

function baseStats()
    local coinMult = 1 + levelOf("coinBoost") * 0.15 + permLevelOf("permCoins") * 0.10
    local dmg = 10 + levelOf("damage") * 3 + permLevelOf("permDamage") * 1
    local maxHp = 100 + levelOf("maxHp") * 20 + permLevelOf("permHp") * 15
    local spd = 240 + levelOf("speed") * 18 + permLevelOf("permSpeed") * 10
    local multishot = 1 + levelOf("multishot") + permLevelOf("permMultishot")
    local pierce = 1 + levelOf("pierce") + permLevelOf("permPierce")
    local fireRate = 1.6 + levelOf("fireRate") * 0.18 + permLevelOf("permFireRate") * 0.08
    local gemPerKill = 1 + permLevelOf("permGems")

    if relicEnabled.warmup then dmg = dmg * 1.10 end
    if relicEnabled.glasscannon then dmg = dmg * 1.40; maxHp = maxHp * 0.75 end
    if relicEnabled.overcharge then fireRate = fireRate * 1.30 end
    if relicEnabled.sprinter then spd = spd * 1.15 end
    if relicEnabled.juggernaut then maxHp = maxHp * 1.50; spd = spd * 0.90 end
    if relicEnabled.luckycharm then coinMult = coinMult * 1.20 end
    if relicEnabled.midas then coinMult = coinMult * 1.50; gemPerKill = gemPerKill * 1.5 end

    if buffSpeedTimeLeft > 0 then spd = spd * 1.40 end
    if buffDamageTimeLeft > 0 then dmg = dmg * 1.50 end

    return {
        damage = dmg, fireRate = fireRate, maxHp = maxHp, speed = spd,
        multishot = multishot, pierce = pierce, coinMult = coinMult, gemPerKill = gemPerKill,
    }
end

function arenaBounds()
    local top = HEIGHT - S(90) - SAFE.t
    local bottom = S(90) + SAFE.b
    return bottom, top
end

function shake(amount) shakeAmount = math.max(shakeAmount, amount) end

function currentWeaponDef()
    for _, d in ipairs(weaponDefs) do if d.key == player.weapon then return d end end
    return weaponDefs[1]
end

function cycleWeapon()
    local idx = 1
    for k, d in ipairs(weaponDefs) do if d.key == player.weapon then idx = k end end
    for step = 1, #weaponDefs do
        idx = idx % #weaponDefs + 1
        local d = weaponDefs[idx]
        if unlockedWeapons[d.key] then player.weapon = d.key; return end
    end
end
