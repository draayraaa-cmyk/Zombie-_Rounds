if os.getenv("LOVE2D_TOOLS") then pcall(require, "_love2d_tools_bridge") end
-- Zombie Siege  (LÖVE 11.x port of the Codea version)
-- Game logic keeps Codea's coordinate system (origin bottom-left, y up).
-- All drawing/input goes through small helpers that flip y for LÖVE.
-- No image/audio assets: sounds are synthesized at startup.
--
-- Desktop extras: WASD / arrows to move, Tab = cycle weapon, B = shop,
-- Esc / P = pause, mouse wheel / drag scrolls long lists.
-- Debug: F1 overlay, F2-F9 cheats (see debugKey). Set DEBUG = false to disable.

-- ============================================================
-- COMPAT / DRAWING HELPERS
-- ============================================================

atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
WIDTH, HEIGHT = 1024, 768
DEBUG = true          -- set false to disable debug keys (F1-F9)
debugOverlay, debugGod = false, false

function color(r, g, b, a) return {r = r, g = g, b = b, a = a or 255} end

-- set draw color: fc(colorTable [,alpha]) or fc(r,g,b [,a])   (0-255)
function fc(r, g, b, a)
    if type(r) == "table" then
        love.graphics.setColor(r.r / 255, r.g / 255, r.b / 255, (g or r.a or 255) / 255)
    else
        love.graphics.setColor(r / 255, g / 255, b / 255, (a or 255) / 255)
    end
end

function SC()
    local m = math.min(WIDTH, HEIGHT)
    local s = m / 768
    if s < 0.55 then s = 0.55 end
    if s > 1.5 then s = 1.5 end
    return s
end
function S(v) return v * SC() end

function randInt(a, b)
    a = math.floor(a); b = math.floor(b)
    if b < a then a, b = b, a end
    return math.random(a, b)
end

function rectF(x, y, w, h) love.graphics.rectangle("fill", x, HEIGHT - y - h, w, h) end
function rectL(x, y, w, h, lw)
    love.graphics.setLineWidth(lw or 1)
    love.graphics.rectangle("line", x, HEIGHT - y - h, w, h)
end
function circF(x, y, d) love.graphics.circle("fill", x, HEIGHT - y, d / 2) end
function circL(x, y, d, lw)
    love.graphics.setLineWidth(lw or 1)
    love.graphics.circle("line", x, HEIGHT - y, d / 2)
end
function lineF(x1, y1, x2, y2, lw)
    love.graphics.setLineWidth(lw or 1)
    love.graphics.line(x1, HEIGHT - y1, x2, HEIGHT - y2)
end

local fonts = {}
local function getFont(size)
    size = math.max(6, math.floor(size + 0.5))
    local f = fonts[size]
    if not f then f = love.graphics.newFont(size); fonts[size] = f end
    return f
end
-- centered on (x,y)
function txtC(str, x, y, size, c, a)
    local f = getFont(size)
    love.graphics.setFont(f)
    if c then fc(c, a) end
    str = tostring(str)
    love.graphics.print(str, math.floor(x - f:getWidth(str) / 2), math.floor(HEIGHT - y - f:getHeight() / 2))
end
-- bottom-left at (x,y)  (Codea CORNER mode)
function txtL(str, x, y, size, c, a)
    local f = getFont(size)
    love.graphics.setFont(f)
    if c then fc(c, a) end
    love.graphics.print(tostring(str), math.floor(x), math.floor(HEIGHT - y - f:getHeight()))
end

-- palette
local TXT   = color(232, 237, 245)
local MUTED = color(139, 150, 168)
local GOLD  = color(255, 207, 77)
local CYAN  = color(120, 220, 255)
local WHITE = color(255, 255, 255)
local PANEL = color(22, 29, 41)
local ROW   = color(19, 26, 36)
local BTN   = color(35, 44, 61)
local GREEN = color(61, 220, 132)
local DGREEN = color(6, 35, 15)
local BUYON = color(31, 122, 76)
local BUYOFF = color(42, 49, 64)

-- ============================================================
-- PERSISTENCE (replacement for readProjectData / saveProjectData)
-- ============================================================

local SAVE_FILE = "zombiesiege.sav"
local saveData, saveDirty = {}, false

local function loadSave()
    if love.filesystem.getInfo(SAVE_FILE) then
        for line in love.filesystem.lines(SAVE_FILE) do
            local k, t, v = line:match("^([^\t]+)\t(.)\t(.*)$")
            if k then
                if t == "n" then saveData[k] = tonumber(v) or 0 else saveData[k] = v end
            end
        end
    end
end

function readProjectData(k, default)
    local v = saveData[k]
    if v == nil then return default end
    return v
end
function saveProjectData(k, v) saveData[k] = v; saveDirty = true end

local function flushSave()
    if not saveDirty then return end
    local lines = {}
    for k, v in pairs(saveData) do
        if type(v) == "number" then
            table.insert(lines, k .. "\tn\t" .. tostring(v))
        else
            table.insert(lines, k .. "\ts\t" .. tostring(v))
        end
    end
    love.filesystem.write(SAVE_FILE, table.concat(lines, "\n"))
    saveDirty = false
end

-- ============================================================
-- PROCEDURAL SOUND
-- ============================================================

local sounds, lastPlayed = {}, {}

local function makeSound(f0, f1, dur, wave, vol)
    local rate = 22050
    local n = math.floor(rate * dur)
    local sd = love.sound.newSoundData(n, rate, 16, 1)
    local phase = 0
    for i = 0, n - 1 do
        local t = i / n
        phase = phase + (f0 + (f1 - f0) * t) / rate
        local v
        if wave == "noise" then v = math.random() * 2 - 1
        elseif wave == "square" then v = ((phase % 1) < 0.5) and 1 or -1
        else v = math.sin(phase * 2 * math.pi) end
        sd:setSample(i, v * ((1 - t) ^ 2) * vol)
    end
    return love.audio.newSource(sd, "static")
end

local function initSounds()
    local ok = pcall(function()
        sounds.shoot   = makeSound(900, 300, 0.08, "square", 0.12)
        sounds.hit     = makeSound(0, 0, 0.06, "noise", 0.18)
        sounds.hurt    = makeSound(220, 80, 0.18, "square", 0.25)
        sounds.coin    = makeSound(600, 1200, 0.12, "sine", 0.25)
        sounds.explode = makeSound(0, 0, 0.35, "noise", 0.35)
        sounds.click   = makeSound(500, 500, 0.04, "square", 0.12)
    end)
    if not ok then sounds = {} end
end

function playSound(kind)
    if not soundOn then return end
    local src = sounds[kind]
    if not src then return end
    local now = love.timer.getTime()
    if lastPlayed[kind] and now - lastPlayed[kind] < 0.04 then return end
    lastPlayed[kind] = now
    src:clone():play()
end

-- ============================================================
-- SETUP
-- ============================================================

function love.load()
    love.graphics.setBackgroundColor(13 / 255, 17 / 255, 23 / 255)
    love.graphics.setLineStyle("smooth")
    WIDTH, HEIGHT = love.graphics.getDimensions()
    math.randomseed(os.time())
    loadSave()
    initSounds()

    upgradeDefs = {
        {key="damage",    name="Bullet Damage", desc="+3 damage/shot",     base=20, growth=1.35, max=20},
        {key="fireRate",  name="Fire Rate",     desc="Shoot faster",       base=25, growth=1.40, max=15},
        {key="maxHp",     name="Max Health",    desc="+20 max HP, heal",   base=22, growth=1.30, max=15},
        {key="speed",     name="Move Speed",    desc="Move faster",        base=15, growth=1.30, max=10},
        {key="multishot", name="Multishot",     desc="+1 bullet/shot",     base=60, growth=1.90, max=6},
        {key="pierce",    name="Piercing Rounds",desc="Bullets pierce +1", base=50, growth=1.80, max=5},
        {key="coinBoost", name="Money Bags",    desc="+15% coins earned",  base=30, growth=1.45, max=10},
    }

    permDefs = {
        {key="permDamage",   name="Sharper Rounds",   desc="+1 starting damage, forever",   base=5,  growth=1.45, max=10},
        {key="permHp",       name="Iron Skin",        desc="+15 starting max HP, forever",  base=5,  growth=1.45, max=10},
        {key="permSpeed",    name="Fleet Feet",       desc="+10 starting speed, forever",   base=5,  growth=1.45, max=8},
        {key="permCoins",    name="Banker's Instinct",desc="+10% coin gain, forever",       base=6,  growth=1.50, max=10},
        {key="permGems",     name="Prospector",       desc="+1 gem per kill, forever",      base=15, growth=2.00, max=3},
        {key="permMultishot",name="Twin Barrel",      desc="+1 starting multishot, forever",base=20, growth=1.90, max=3},
        {key="permFireRate", name="Twitchy Trigger",  desc="+0.08 fire rate, forever",      base=6,  growth=1.45, max=8},
        {key="permPierce",   name="Deep Impact",      desc="+1 starting pierce, forever",   base=12, growth=1.70, max=3},
    }

    weaponDefs = {
        {key="pistol",      name="Pistol",           short="PISTOL",  desc="Balanced homing shot", cost=0},
        {key="shotgun",     name="Shotgun",          short="SHOTGUN", desc="Wide spread of pellets", cost=15},
        {key="laser",       name="Laser Rifle",      short="LASER",   desc="Thin beam, pierces everything", cost=25},
        {key="grenade",     name="Grenade Launcher", short="GRENADE", desc="Explodes in an area on impact", cost=35},
        {key="flamethrower",name="Flamethrower",     short="FLAME",   desc="Continuous short-range burn", cost=45},
    }

    skinDefs = {
        {key="green",  name="Forest Green", col=color(61,220,132),  cost=0},
        {key="blue",   name="Blue Steel",   col=color(80,160,255),  cost=10},
        {key="red",    name="Crimson",      col=color(255,90,90),   cost=10},
        {key="gold",   name="Gold Rush",    col=color(255,207,77),  cost=20},
        {key="purple", name="Void",         col=color(160,90,255),  cost=20},
        {key="white",  name="Ghost",        col=color(235,235,245), cost=15},
    }

    modeDefs = {
        {key="classic", name="CLASSIC", desc="Wave-based survival. Open the shop any time to spend coins."},
        {key="horde",   name="HORDE",   desc="Endless continuous horde -- survive as long as you can."},
    }
    difficultyDefs = {
        {key="easy",   name="EASY",   hpMult=0.75, dmgMult=0.70, speedMult=0.85, rewardMult=0.80},
        {key="normal", name="NORMAL", hpMult=1.00, dmgMult=1.00, speedMult=1.00, rewardMult=1.00},
        {key="hard",   name="HARD",   hpMult=1.35, dmgMult=1.30, speedMult=1.15, rewardMult=1.35},
    }

    relicDefs = {
        {key="warmup",     name="Warm-Up",         desc="+10% damage",
         hint="Reach wave 3 or survive 45s in Horde",
         unlock=function() return bestWave >= 3 or bestSurvivalTime >= 45 end},
        {key="sprinter",   name="Sprinter",        desc="+15% move speed",
         hint="50 lifetime kills",
         unlock=function() return lifetimeKills >= 50 end},
        {key="luckycharm", name="Lucky Charm",     desc="+20% coin gain",
         hint="Buy 3 permanent upgrades",
         unlock=function() return permPurchaseCount >= 3 end},
        {key="vampiric",   name="Vampiric Rounds", desc="Heal 2 HP every 15 kills",
         hint="Defeat a boss",
         unlock=function() return lifetimeBossKills >= 1 end},
        {key="glasscannon",name="Glass Cannon",    desc="+40% damage, -25% max HP",
         hint="Reach wave 15",
         unlock=function() return bestWave >= 15 end},
        {key="secondwind", name="Second Wind",     desc="Revive once per run at 50% HP",
         hint="Survive 5 minutes in Horde",
         unlock=function() return bestSurvivalTime >= 300 end},
        {key="overcharge", name="Overcharge",      desc="+30% fire rate",
         hint="Own every weapon",
         unlock=function()
             for _, d in ipairs(weaponDefs) do if not unlockedWeapons[d.key] then return false end end
             return true
         end},
        {key="juggernaut", name="Juggernaut",      desc="+50% max HP, -10% speed",
         hint="Reach wave 25",
         unlock=function() return bestWave >= 25 end},
        {key="midas",      name="Midas Touch",     desc="+50% coin & gem gain",
         hint="Earn 1000 lifetime gems",
         unlock=function() return lifetimeGemsEarned >= 1000 end},
        {key="combomaster",name="Combo Master",    desc="Doubles your combo coin bonus",
         hint="Reach a 15x combo in one run",
         unlock=function() return bestCombo >= 15 end},
        {key="pyromaniac", name="Pyromaniac",      desc="+25% Flamethrower damage",
         hint="200 kills with the Flamethrower equipped",
         unlock=function() return lifetimeFlameKills >= 200 end},
        {key="ironwill",   name="Iron Will",       desc="-20% incoming damage",
         hint="Clear a wave without taking damage (Classic mode)",
         unlock=function() return noHitWavesCleared >= 1 end},
        {key="godmode",    name="GODMODE",         desc="Total invincibility -- take no damage",
         hint="1000 kills, 10 bosses, wave 25, and 10-min Horde survival",
         unlock=function()
             return lifetimeKills >= 1000 and lifetimeBossKills >= 10 and bestWave >= 25 and bestSurvivalTime >= 600
         end},
    }

    achievementDefs = {
        {id="first_blood", name="First Blood",   desc="Get your first kill",     reward=3,  check=function() return lifetimeKills >= 1 end},
        {id="kills_100",   name="Centurion",      desc="100 lifetime kills",      reward=10, check=function() return lifetimeKills >= 100 end},
        {id="kills_500",   name="Exterminator",   desc="500 lifetime kills",      reward=25, check=function() return lifetimeKills >= 500 end},
        {id="wave_5",      name="Getting Started",desc="Reach wave 5",           reward=5,  check=function() return bestWave >= 5 end},
        {id="wave_10",     name="Survivor",       desc="Reach wave 10",          reward=15, check=function() return bestWave >= 10 end},
        {id="wave_20",     name="Veteran",        desc="Reach wave 20",          reward=40, check=function() return bestWave >= 20 end},
        {id="boss_1",      name="Boss Slayer",    desc="Defeat your first boss", reward=15, check=function() return lifetimeBossKills >= 1 end},
        {id="rich",        name="Big Spender",    desc="Buy a permanent upgrade",reward=5,  check=function() return permPurchaseCount >= 1 end},
        {id="arsenal",     name="Arsenal",        desc="Unlock every weapon",    reward=20, check=function()
            for _, d in ipairs(weaponDefs) do if not unlockedWeapons[d.key] then return false end end
            return true
        end},
        {id="fashionista", name="Fashionista",    desc="Unlock every skin",      reward=15, check=function()
            for _, d in ipairs(skinDefs) do if not (unlockedSkins[d.key] or d.cost == 0) then return false end end
            return true
        end},
        {id="horde_5m",  name="Horde Survivor", desc="Survive 5 minutes in Horde mode",  reward=20, check=function() return bestSurvivalTime >= 300 end},
        {id="horde_10m", name="Horde Legend",   desc="Survive 10 minutes in Horde mode", reward=50, check=function() return bestSurvivalTime >= 600 end},
        {id="completionist", name="Completionist", desc="Own every weapon & skin, max every permanent upgrade", reward=60, check=function()
            for _, d in ipairs(weaponDefs) do if not unlockedWeapons[d.key] then return false end end
            for _, d in ipairs(skinDefs) do if not (unlockedSkins[d.key] or d.cost == 0) then return false end end
            for _, d in ipairs(permDefs) do if permLevelOf(d.key) < d.max then return false end end
            return true
        end},
        {id="relic_5",   name="Relic Collector", desc="Unlock 5 relics",   reward=25, check=function()
            local c = 0
            for _, d in ipairs(relicDefs) do if relicUnlocked[d.key] then c = c + 1 end end
            return c >= 5
        end},
        {id="relic_all", name="Relic Master",    desc="Unlock every relic",reward=75, check=function()
            for _, d in ipairs(relicDefs) do if not relicUnlocked[d.key] then return false end end
            return true
        end},
        {id="gem_hoarder", name="Gem Hoarder",   desc="Earn 1000 lifetime gems", reward=30, check=function() return lifetimeGemsEarned >= 1000 end},
    }

    -- persistent (meta) data
    gems = readProjectData("gems", 0)
    permUpgrades = deserializeLevels(readProjectData("permUpgradesStr", ""))
    lifetimeKills = readProjectData("lifetimeKills", 0)
    lifetimeBossKills = readProjectData("lifetimeBossKills", 0)
    lifetimeGemsEarned = readProjectData("lifetimeGemsEarned", 0)
    lifetimeFlameKills = readProjectData("lifetimeFlameKills", 0)
    permPurchaseCount = readProjectData("permPurchaseCount", 0)
    bestWave = readProjectData("bestWave", 0)
    bestSurvivalTime = readProjectData("bestSurvivalTime", 0)
    bestCombo = readProjectData("bestCombo", 0)
    noHitWavesCleared = readProjectData("noHitWavesCleared", 0)
    soundOn = (readProjectData("soundOn", 1) == 1)
    joySensIndex = readProjectData("joySensIndex", 2)
    unlockedWeapons = deserializeSet(readProjectData("unlockedWeaponsStr", ""))
    unlockedWeapons["pistol"] = true
    unlockedSkins = deserializeSet(readProjectData("unlockedSkinsStr", ""))
    unlockedSkins["green"] = true
    activeSkin = readProjectData("activeSkin", "green")
    modeIndex = readProjectData("modeIndex", 1)
    difficultyIndex = readProjectData("difficultyIndex", 2)
    achieved = deserializeSet(readProjectData("achievedStr", ""))
    relicUnlocked = deserializeSet(readProjectData("relicUnlockedStr", ""))
    relicEnabled = deserializeSet(readProjectData("relicEnabledStr", ""))

    -- run-only (temp) data
    coins = 0
    upgrades = {}
    gameMode = "classic"
    runDiff = difficultyDefs[difficultyIndex]
    survivalTime = 0
    hordeSpawnTimer = 0
    lastBossTime = 0
    lastAnnouncedMinute = 0
    usedSecondWind = false
    vampKillCounter = 0
    tookDamageThisWave = false
    powerups = {}
    buffSpeedTimeLeft = 0
    buffDamageTimeLeft = 0
    shieldTimeLeft = 0
    flameSoundTimer = 0

    state = "start" -- start | modeSelect | metaShop | weaponShop | skinShop | relicMenu | settings | playing | shop | gameover | paused
    resetConfirm = false

    bullets = {}
    enemyBullets = {}
    zombies = {}
    particles = {}
    coinPops = {}

    wave = 1
    kills = 0
    combo = 0
    comboTimer = 0
    hitFlash = 0
    levelFlash = 0
    shakeAmount = 0

    spawnQueue = {}
    spawnTimer = 0
    waveActive = false
    waveClearDelay = 0

    joyTouchId = nil
    joyBaseX, joyBaseY = nil, nil
    joyThumbX, joyThumbY = nil, nil
    moveX, moveY = 0, 0

    waveBannerText = ""
    waveBannerAlpha = 0

    listScroll, listMaxScroll = 0, 0
    dragId, dragLastY = nil, 0

    buttons = {}
end

function love.resize(w, h) WIDTH, HEIGHT = love.graphics.getDimensions() end

function love.quit() persistMeta(); flushSave() end

function love.focus(f)
    if not f and state == "playing" then state = "paused" end
end

-- ============================================================
-- HELPERS: upgrades / persistence
-- ============================================================

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

function serializeLevels(t, defs)
    local parts = {}
    for _, def in ipairs(defs) do table.insert(parts, def.key .. "=" .. tostring(t[def.key] or 0)) end
    return table.concat(parts, ",")
end
function deserializeLevels(s)
    local t = {}
    if s and s ~= "" then
        for pair in s:gmatch("[^,]+") do
            local k, v = pair:match("([^=]+)=([^=]+)")
            if k then t[k] = tonumber(v) or 0 end
        end
    end
    return t
end

function serializeSet(t, defs)
    local parts = {}
    for _, def in ipairs(defs) do
        local key = def.key or def.id
        if t[key] then table.insert(parts, key) end
    end
    return table.concat(parts, ",")
end
function deserializeSet(s)
    local t = {}
    if s and s ~= "" then for k in s:gmatch("[^,]+") do t[k] = true end end
    return t
end

function persistMeta()
    saveProjectData("gems", gems)
    saveProjectData("permUpgradesStr", serializeLevels(permUpgrades, permDefs))
    saveProjectData("lifetimeKills", lifetimeKills)
    saveProjectData("lifetimeBossKills", lifetimeBossKills)
    saveProjectData("lifetimeGemsEarned", lifetimeGemsEarned)
    saveProjectData("lifetimeFlameKills", lifetimeFlameKills)
    saveProjectData("permPurchaseCount", permPurchaseCount)
    saveProjectData("bestWave", bestWave)
    saveProjectData("bestSurvivalTime", bestSurvivalTime)
    saveProjectData("bestCombo", bestCombo)
    saveProjectData("noHitWavesCleared", noHitWavesCleared)
    saveProjectData("soundOn", soundOn and 1 or 0)
    saveProjectData("joySensIndex", joySensIndex)
    saveProjectData("unlockedWeaponsStr", serializeSet(unlockedWeapons, weaponDefs))
    saveProjectData("unlockedSkinsStr", serializeSet(unlockedSkins, skinDefs))
    saveProjectData("activeSkin", activeSkin)
    saveProjectData("modeIndex", modeIndex)
    saveProjectData("difficultyIndex", difficultyIndex)
    saveProjectData("achievedStr", serializeSet(achieved, achievementDefs))
    saveProjectData("relicUnlockedStr", serializeSet(relicUnlocked, relicDefs))
    saveProjectData("relicEnabledStr", serializeSet(relicEnabled, relicDefs))
end

function resetProgress()
    gems = 0
    permUpgrades = {}
    lifetimeKills = 0
    lifetimeBossKills = 0
    lifetimeGemsEarned = 0
    lifetimeFlameKills = 0
    permPurchaseCount = 0
    bestWave = 0
    bestSurvivalTime = 0
    bestCombo = 0
    noHitWavesCleared = 0
    soundOn = true
    joySensIndex = 2
    unlockedWeapons = {pistol = true}
    unlockedSkins = {green = true}
    activeSkin = "green"
    modeIndex = 1
    difficultyIndex = 2
    achieved = {}
    relicUnlocked = {}
    relicEnabled = {}
    persistMeta()
end

function touchBestWave()
    if wave > bestWave then bestWave = wave end
end

function checkAchievements()
    local changed = false
    for _, d in ipairs(achievementDefs) do
        if not achieved[d.id] and d.check() then
            achieved[d.id] = true
            gems = gems + d.reward
            lifetimeGemsEarned = lifetimeGemsEarned + d.reward
            showWaveBanner("Achievement: " .. d.name .. " (+" .. d.reward .. "g)")
            levelFlash = 1.0
            changed = true
        end
    end
    if changed then persistMeta() end
end

function checkRelics()
    local changed = false
    for _, d in ipairs(relicDefs) do
        if not relicUnlocked[d.key] and d.unlock() then
            relicUnlocked[d.key] = true
            showWaveBanner("Relic Unlocked: " .. d.name .. "!")
            levelFlash = 1.0
            changed = true
        end
    end
    if changed then persistMeta() end
end

function checkProgress()
    checkAchievements()
    checkRelics()
end

function arenaBounds()
    local top = HEIGHT - S(90)
    local bottom = S(90)
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

-- ============================================================
-- GAME LIFECYCLE
-- ============================================================

function newGame()
    coins = 0
    upgrades = {}
    runDiff = difficultyDefs[difficultyIndex]
    pendingDeath = false
    usedSecondWind = false
    vampKillCounter = 0
    powerups = {}
    buffSpeedTimeLeft = 0
    buffDamageTimeLeft = 0
    shieldTimeLeft = 0

    local s = baseStats()
    player = {
        x = WIDTH/2, y = HEIGHT/2, r = S(24),
        hp = s.maxHp, maxHp = s.maxHp, fireCd = 0,
        facing = -math.pi/2, weapon = "pistol",
        col = skinColorFor(activeSkin),
    }
    bullets = {}
    enemyBullets = {}
    zombies = {}
    particles = {}
    coinPops = {}
    kills = 0
    combo = 0
    comboTimer = 0
    flameSoundTimer = 0
    joyTouchId = nil
    joyBaseX, joyBaseY = nil, nil
    moveX, moveY = 0, 0

    if gameMode == "horde" then
        wave = 0
        survivalTime = 0
        hordeSpawnTimer = 0.6
        lastBossTime = 0
        lastAnnouncedMinute = 0
        tookDamageThisWave = false
    else
        wave = 1
        touchBestWave()
        startWave()
    end
end

function startWave()
    tookDamageThisWave = false
    local s = baseStats()
    player.hp = math.min(player.hp, s.maxHp)
    local count = 4 + math.floor(wave * 1.6)
    spawnQueue = {}
    for i = 1, count do
        table.insert(spawnQueue, rollZombieType(wave))
    end
    if wave % 5 == 0 then table.insert(spawnQueue, "boss") end
    spawnTimer = 0
    waveActive = true
    showWaveBanner("Wave " .. wave)
end

function rollZombieType(lvl)
    local roll = math.random()
    if lvl >= 3 and roll < 0.13 then return "fast"
    elseif lvl >= 4 and roll < 0.28 then return "shooter"
    elseif lvl >= 5 and roll < 0.38 then return "exploder"
    elseif lvl >= 6 and roll < 0.48 then return "shielded"
    elseif lvl >= 7 and roll < 0.56 then return "splitter"
    elseif lvl >= 6 and roll > 0.85 then return "tank"
    end
    return "normal"
end

function showWaveBanner(txt)
    waveBannerText = txt
    waveBannerAlpha = 1.0
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
    elseif t == "boss" then
        return { hp=260*scale, speed=45+levelN*1, r=S(46), col=color(255,90,140), coin=30, dmg=28,
                 preferredRange=S(170), shotCount=3, shotDmg=12 }
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

function spawnZombie(t, levelOverride)
    local lvl = levelOverride or wave
    local st = zombieStats(t, lvl)
    st.hp = st.hp * runDiff.hpMult
    st.dmg = st.dmg * runDiff.dmgMult
    st.speed = st.speed * runDiff.speedMult
    -- mild per-level scaling so damage keeps pace with healing, and coins keep pace with upgrade costs
    st.dmg = st.dmg * (1 + (lvl - 1) * 0.03)
    st.coin = st.coin * (1 + (lvl - 1) * 0.06)
    if st.shield then st.shield = st.shield * runDiff.hpMult end
    local ex, ey = randomEdgePoint()
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

function checkDeath()
    if pendingDeath then
        pendingDeath = false
        endGame()
        return true
    end
    return false
end

function endGame()
    state = "gameover"
    if gameMode == "horde" and survivalTime > bestSurvivalTime then
        bestSurvivalTime = survivalTime
    end
    persistMeta()
    checkProgress()
end

-- ============================================================
-- COMBAT
-- ============================================================

function nearestZombie()
    local target, bestD = nil, math.huge
    local bottom, top = arenaBounds()
    for _, z in ipairs(zombies) do
        -- ignore zombies that haven't walked into the arena yet
        if z.x >= 0 and z.x <= WIDTH and z.y >= bottom and z.y <= top then
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

-- ============================================================
-- UPDATE
-- ============================================================

function love.update(dt)
    dt = math.min(dt, 1/20)
    if state ~= prevState then listScroll = 0; dragId = nil; prevState = state end
    update(dt)
    flushSave()
end

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

function update(dt)
    if shakeAmount > 0 then shakeAmount = math.max(0, shakeAmount - dt * S(240)) end
    if levelFlash > 0 then levelFlash = math.max(0, levelFlash - dt * 2.2) end

    if state ~= "playing" then return end
    local s = baseStats()

    if buffSpeedTimeLeft > 0 then buffSpeedTimeLeft = math.max(0, buffSpeedTimeLeft - dt) end
    if buffDamageTimeLeft > 0 then buffDamageTimeLeft = math.max(0, buffDamageTimeLeft - dt) end
    if shieldTimeLeft > 0 then shieldTimeLeft = math.max(0, shieldTimeLeft - dt) end

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

    local target = nearestZombie()
    if target then
        player.facing = atan2(target.y - player.y, target.x - player.x)
    elseif mx ~= 0 or my ~= 0 then
        player.facing = atan2(my, mx)
    end

    player.fireCd = player.fireCd - dt
    if player.weapon == "flamethrower" then
        tickFlamethrower(dt, s)
    elseif player.fireCd <= 0 and target then
        fireBullet()
        player.fireCd = 1 / s.fireRate
    end

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx*dt
        b.y = b.y + b.vy*dt
        if b.kind == "grenade" then b.timer = b.timer - dt end
        if b.x < -40 or b.x > WIDTH+40 or b.y < -40 or b.y > HEIGHT+40 then
            table.remove(bullets, i)
        end
    end

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
                        applyDamageToZombie(j, z, b.damage)
                        b.pierce = b.pierce - 1
                        if b.pierce <= 0 then table.remove(bullets, i); break end
                    end
                end
            end
        end
    end

    if checkDeath() then return end

    if gameMode == "classic" then
        if waveActive and #spawnQueue > 0 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                spawnZombie(table.remove(spawnQueue, 1))
                spawnTimer = math.max(0.25, 0.85 - wave*0.02)
            end
        end
    elseif gameMode == "horde" then
        survivalTime = survivalTime + dt
        hordeSpawnTimer = hordeSpawnTimer - dt
        if hordeSpawnTimer <= 0 then
            local lvl = 1 + math.floor(survivalTime/20)
            spawnZombie(rollZombieType(lvl), lvl)
            hordeSpawnTimer = math.max(0.22, 0.9 - survivalTime*0.006)
        end
        if survivalTime - lastBossTime >= 60 then
            local lvl = 1 + math.floor(survivalTime/20)
            spawnZombie("boss", lvl)
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

    for i = #zombies, 1, -1 do
        local z = zombies[i]
        z.wob = z.wob + dt*4
        local distToPlayer = math.sqrt((z.x-player.x)^2 + (z.y-player.y)^2)

        if z.preferredRange and distToPlayer <= z.preferredRange then
            z.shootCd = z.shootCd - dt
            if z.shootCd <= 0 then
                fireEnemyBullet(z)
                z.shootCd = (z.t == "boss" and 1.4 or 1.7) + math.random()*0.6
            end
            z.x = z.x + math.cos(z.wob) * 20 * dt
        else
            local ang = atan2(player.y - z.y, player.x - z.x)
            z.x = z.x + math.cos(ang) * z.speed * dt
            z.y = z.y + math.sin(ang) * z.speed * dt + math.sin(z.wob)*0.15
        end

        if distToPlayer < z.r + player.r then
            damagePlayer(z.dmg)
            spawnParticles(z.x, z.y, z.col, 10)
            table.remove(zombies, i)
        end
    end

    if checkDeath() then return end

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

    if checkDeath() then return end

    for i = #powerups, 1, -1 do
        local p = powerups[i]
        p.life = p.life - dt
        local d = math.sqrt((p.x-player.x)^2 + (p.y-player.y)^2)
        if d < p.r + player.r then
            applyPowerup(p.t)
            table.remove(powerups, i)
        elseif p.life <= 0 then
            table.remove(powerups, i)
        end
    end

    if gameMode == "classic" then
        if waveActive and #spawnQueue == 0 and #zombies == 0 then
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

    if hitFlash > 0 then hitFlash = hitFlash - dt end
    if waveBannerAlpha > 0 then waveBannerAlpha = math.max(0, waveBannerAlpha - dt/1.6) end
end

-- ============================================================
-- DRAW
-- ============================================================

function love.draw()
    love.graphics.clear(13/255, 17/255, 23/255)
    buttons = {}

    if state == "start" then
        drawStartScreen()
    elseif state == "modeSelect" then
        drawModeSelect()
    elseif state == "metaShop" then
        drawMetaShop()
    elseif state == "weaponShop" then
        drawWeaponShop()
    elseif state == "skinShop" then
        drawSkinShop()
    elseif state == "relicMenu" then
        drawRelicMenu()
    elseif state == "settings" then
        drawSettings()
    elseif state == "gameover" then
        drawWorldShaken()
        drawHud()
        drawGameOverScreen()
    else
        drawWorldShaken()
        drawHud()
        if state == "playing" then drawJoystick() end
        if state == "shop" then drawShop() end
        if state == "paused" then drawPauseOverlay() end
    end

    if DEBUG and debugOverlay then drawDebug() end
end

function drawWorldShaken()
    love.graphics.push()
    if shakeAmount > 0 then
        love.graphics.translate((math.random()*2-1)*shakeAmount, (math.random()*2-1)*shakeAmount)
    end
    drawWorld()
    love.graphics.pop()
end

function drawGrid()
    local step = S(70)
    local bottom, top = arenaBounds()
    fc(255, 255, 255, 14)
    local x = 0
    while x <= WIDTH do lineF(x, bottom, x, top, 1); x = x + step end
    local y = bottom
    while y <= top do lineF(0, y, WIDTH, y, 1); y = y + step end
    fc(61, 220, 132, 50)
    rectL(2, bottom, WIDTH-4, top-bottom, 2)
end

function powerupColor(t)
    if t == "speed" then return color(120,220,255)
    elseif t == "damage" then return color(255,120,120)
    elseif t == "shield" then return color(255,255,255)
    elseif t == "health" then return color(255,90,120)
    else return color(255,207,77)
    end
end

function drawWorld()
    if not player then return end
    drawGrid()

    for _, p in ipairs(particles) do
        local a = math.max(0, p.life / p.maxLife)
        fc(p.col, 255*a)
        circF(p.x, p.y, S(6))
    end

    for _, p in ipairs(powerups) do
      if p.t == "health" then
        if p.life > 3 or math.floor(p.life * 6) % 2 == 0 then
            fc(255, 90, 120, 230)
            circF(p.x, p.y, p.r * 2.2)
            fc(255, 255, 255)
            rectF(p.x - p.r*0.7, p.y - p.r*0.2, p.r*1.4, p.r*0.4)
            rectF(p.x - p.r*0.2, p.y - p.r*0.7, p.r*0.4, p.r*1.4)
        end
      else
        fc(powerupColor(p.t), 220)
        love.graphics.push()
        love.graphics.translate(p.x, HEIGHT - p.y)
        love.graphics.rotate(math.rad(p.life * 50))
        love.graphics.rectangle("fill", -p.r, -p.r, p.r*2, p.r*2)
        love.graphics.pop()
      end
    end

    for _, z in ipairs(zombies) do
        fc(z.col)
        circF(z.x, z.y, z.r*2)
        fc(22, 29, 41)
        circF(z.x - z.r*0.32, z.y + z.r*0.1, z.r*0.32)
        circF(z.x + z.r*0.32, z.y + z.r*0.1, z.r*0.32)
        if z.t == "boss" then
            fc(255, 255, 255, 160)
            circL(z.x, z.y, z.r*2 + S(14), S(3))
        elseif z.t == "shooter" then
            fc(255, 255, 255, 200)
            circF(z.x, z.y + z.r + S(6), S(8))
        elseif z.t == "exploder" then
            fc(255, 140, 40, 60)
            circF(z.x, z.y, z.r*2 + S(16))
        elseif z.t == "shielded" and z.shield and z.shield > 0 then
            fc(90, 200, 220, 200)
            circL(z.x, z.y, z.r*2 + S(10), S(3))
        end
        if z.shield and z.maxShield and z.maxShield > 0 then
            local w = z.r*2
            fc(0, 0, 0, 140)
            rectF(z.x - w/2, z.y + z.r + S(14), w, S(5))
            fc(90, 200, 220)
            rectF(z.x - w/2, z.y + z.r + S(14), w * math.max(0, z.shield/z.maxShield), S(5))
        end
        if z.hp < z.maxHp then
            local w = z.r*2
            fc(0, 0, 0, 140)
            rectF(z.x - w/2, z.y + z.r + S(6), w, S(6))
            fc(255, 93, 93)
            rectF(z.x - w/2, z.y + z.r + S(6), w * math.max(0, z.hp/z.maxHp), S(6))
        end
    end

    for _, b in ipairs(bullets) do
        if b.kind == "laser" then
            love.graphics.push()
            love.graphics.translate(b.x, HEIGHT - b.y)
            love.graphics.rotate(-atan2(b.vy, b.vx))
            fc(120, 220, 255)
            love.graphics.rectangle("fill", -S(14), -S(2), S(28), S(4))
            love.graphics.pop()
        elseif b.kind == "grenade" then
            fc(255, 160, 60)
            circF(b.x, b.y, b.r*2)
        else
            fc(255, 229, 138)
            circF(b.x, b.y, b.r*2)
        end
    end

    fc(255, 120, 120)
    for _, b in ipairs(enemyBullets) do circF(b.x, b.y, b.r*2) end

    if player.weapon == "flamethrower" then drawFlameCone() end

    if relicEnabled.godmode or debugGod or shieldTimeLeft > 0 then
        fc(255, 255, 255, 120)
        circL(player.x, player.y, player.r*2 + S(18), S(3))
    end

    fc(player.col)
    circF(player.x, player.y, player.r*2)
    love.graphics.push()
    love.graphics.translate(player.x, HEIGHT - player.y)
    love.graphics.rotate(-player.facing)
    fc(6, 35, 15)
    love.graphics.rectangle("fill", 0, -S(3), S(18), S(6))
    love.graphics.pop()

    for _, c in ipairs(coinPops) do
        txtC(c.txt, c.x, c.y, S(18), c.col, 255*math.max(0, c.life))
    end

    if hitFlash > 0 then fc(255, 0, 0, 90*hitFlash); rectF(0, 0, WIDTH, HEIGHT) end
    if levelFlash > 0 then fc(255, 255, 255, 140*levelFlash); rectF(0, 0, WIDTH, HEIGHT) end

    if waveBannerAlpha > 0 then
        txtC(waveBannerText, WIDTH/2, HEIGHT - S(120), S(24), WHITE, 255*waveBannerAlpha)
    end

    if combo >= 3 then
        local pct = math.floor((comboMultFor()-1)*100 + 0.5)
        txtC(combo .. "x combo! (+" .. pct .. "%)", WIDTH/2, HEIGHT - S(150), S(20), GOLD)
    end
end

function drawFlameCone()
    local s = baseStats()
    local range = S(150)
    local halfAngle = 0.45 + (s.multishot - 1) * 0.10
    local ang = player.facing
    local segments = 12
    fc(255, 140, 60, 45)
    for i = 0, segments - 1 do
        local a = ang - halfAngle + (i/segments) * halfAngle * 2
        love.graphics.push()
        love.graphics.translate(player.x, HEIGHT - player.y)
        love.graphics.rotate(-a)
        love.graphics.rectangle("fill", 0, -S(4), range, S(8))
        love.graphics.pop()
    end
end

function drawJoystick()
    if not joyBaseX then return end
    fc(255, 255, 255, 90)
    circL(joyBaseX, joyBaseY, S(140), S(3))
    fc(255, 255, 255, 140)
    circF(joyThumbX, joyThumbY, S(60))
end

function drawHud()
    local pad = S(16)
    local chipH = S(40)
    local chipW = S(130)
    local gap = S(14)
    local chipY = HEIGHT - chipH - pad

    fc(22, 29, 41, 230)
    rectF(pad, chipY, chipW, chipH)
    txtL("coins " .. coins, pad + S(12), chipY + S(10), S(20), GOLD)
    txtL("gems " .. gems, pad + S(12), chipY - S(16), S(13), CYAN)

    local buffParts = {}
    if buffSpeedTimeLeft > 0 then table.insert(buffParts, "SPD " .. math.ceil(buffSpeedTimeLeft) .. "s") end
    if buffDamageTimeLeft > 0 then table.insert(buffParts, "DMG " .. math.ceil(buffDamageTimeLeft) .. "s") end
    if shieldTimeLeft > 0 then table.insert(buffParts, "SHIELD " .. math.ceil(shieldTimeLeft) .. "s") end
    if #buffParts > 0 then
        txtL(table.concat(buffParts, "  "), pad + S(12), chipY - S(32), S(11), WHITE)
    end

    fc(22, 29, 41, 230)
    rectF(WIDTH - pad - chipW, chipY, chipW, chipH)
    if gameMode == "classic" then
        txtL("wave " .. wave, WIDTH - pad - chipW + S(12), chipY + S(10), S(20), WHITE)
    else
        local mm = math.floor(survivalTime/60)
        local ss = math.floor(survivalTime % 60)
        txtL(string.format("%d:%02d", mm, ss), WIDTH - pad - chipW + S(12), chipY + S(10), S(20), WHITE)
    end

    local barX = pad + chipW + gap
    local barW = math.max(S(60), WIDTH - pad*2 - chipW*2 - gap*2)
    fc(22, 29, 41, 230)
    rectF(barX, chipY, barW, chipH)
    if player then
        local pct = math.max(0, player.hp / player.maxHp)
        fc(255, 93, 93)
        rectF(barX + S(4), chipY + S(4), (barW - S(8)) * pct, chipH - S(8))
        txtC(math.ceil(player.hp) .. " / " .. math.floor(player.maxHp + 0.5), barX + barW/2, chipY + chipH/2, S(16), WHITE)
    end

    local btnH = S(56)
    local shopW, weapW, pauseW = S(140), S(140), S(120)
    local btnGap = S(10)
    local totalW = shopW + btnGap + weapW + btnGap + pauseW
    local startX = WIDTH/2 - totalW/2
    local btnY = S(16)
    drawButton("shopBtn", "SHOP", startX, btnY, shopW, btnH, GREEN, DGREEN)
    drawButton("cycleWeaponBtn", currentWeaponDef().short, startX + shopW + btnGap, btnY, weapW, btnH, color(120,109,241), color(240,235,255))
    drawButton("pauseBtn", state == "paused" and "RESUME" or "PAUSE", startX + shopW + btnGap + weapW + btnGap, btnY, pauseW, btnH, BTN, TXT)
end

function drawButton(id, label, x, y, w, h, bgcol, txtcol)
    fc(bgcol)
    rectF(x, y, w, h)
    txtC(label, x + w/2, y + h/2, S(18), txtcol)
    table.insert(buttons, {id=id, x=x, y=y, w=w, h=h})
end

function drawStartScreen()
    txtC("ZOMBIE SIEGE", WIDTH/2, HEIGHT - S(62), S(38), TXT)
    txtC("Drag / WASD to move. Auto-fires at the nearest zombie.", WIDTH/2, HEIGHT - S(90), S(13), MUTED)
    local mm = math.floor(bestSurvivalTime/60)
    local ss = math.floor(bestSurvivalTime % 60)
    txtC("gems " .. gems .. "    best wave " .. bestWave .. "    best horde " .. string.format("%d:%02d", mm, ss),
         WIDTH/2, HEIGHT - S(114), S(15), CYAN)
    local achCount = 0
    for _, d in ipairs(achievementDefs) do if achieved[d.id] then achCount = achCount + 1 end end
    local relicCount = 0
    for _, d in ipairs(relicDefs) do if relicUnlocked[d.key] then relicCount = relicCount + 1 end end
    txtC("achievements " .. achCount .. "/" .. #achievementDefs .. "    relics " .. relicCount .. "/" .. #relicDefs,
         WIDTH/2, HEIGHT - S(134), S(12), GOLD)

    local bY = S(20)
    local bx = WIDTH/2 - S(130)
    drawButton("startBtn", "START GAME", bx, bY, S(260), S(56), GREEN, DGREEN)
    bY = bY + S(56) + S(10)
    drawButton("weaponBtn", "WEAPONS", bx, bY, S(260), S(44), color(255,160,60), color(35,20,0))
    bY = bY + S(44) + S(8)
    drawButton("skinBtn", "SKINS", bx, bY, S(260), S(44), color(80,160,255), color(10,25,45))
    bY = bY + S(44) + S(8)
    drawButton("relicBtn", "RELICS", bx, bY, S(260), S(44), color(160,90,255), color(30,10,45))
    bY = bY + S(44) + S(8)
    drawButton("metaBtn", "PERMANENT UPGRADES", bx, bY, S(260), S(44), color(120,109,241), color(240,235,255))
    bY = bY + S(44) + S(8)
    drawButton("settingsBtn", "SETTINGS", bx, bY, S(260), S(40), BTN, TXT)
end

function drawModeSelect()
    fc(6, 9, 14, 200); rectF(0, 0, WIDTH, HEIGHT)
    local panelW = math.min(WIDTH - S(80), S(560))
    local panelX = (WIDTH - panelW)/2
    local panelH = S(420)
    local panelY = math.max(S(20), (HEIGHT - panelH)/2)
    fc(PANEL); rectF(panelX, panelY, panelW, panelH)

    local top = panelY + panelH - S(20)
    txtL("START RUN", panelX + S(20), top - S(30), S(24), TXT)

    local y = top - S(70)
    txtL("MODE", panelX + S(20), y, S(14), MUTED)
    y = y - S(38)
    local mw = (panelW - S(56))/2
    for i, m in ipairs(modeDefs) do
        local bx = panelX + S(20) + (i-1)*(mw+S(16))
        local sel = (i == modeIndex)
        fc(sel and GREEN or BTN)
        rectF(bx, y-S(46), mw, S(46))
        txtC(m.name, bx+mw/2, y-S(23), S(15), sel and DGREEN or color(200,205,215))
        table.insert(buttons, {id="mode_"..i, x=bx, y=y-S(46), w=mw, h=S(46)})
    end
    y = y - S(46) - S(14)
    txtL(modeDefs[modeIndex].desc, panelX + S(20), y, S(12), MUTED)
    y = y - S(34)

    txtL("DIFFICULTY", panelX + S(20), y, S(14), MUTED)
    y = y - S(38)
    local dw = (panelW - S(56) - S(32))/3
    for i, d in ipairs(difficultyDefs) do
        local bx = panelX + S(20) + (i-1)*(dw+S(16))
        local sel = (i == difficultyIndex)
        fc(sel and color(255,160,60) or BTN)
        rectF(bx, y-S(46), dw, S(46))
        txtC(d.name, bx+dw/2, y-S(23), S(14), sel and color(35,20,0) or color(200,205,215))
        table.insert(buttons, {id="diff_"..i, x=bx, y=y-S(46), w=dw, h=S(46)})
    end
    y = y - S(46) - S(20)

    drawButton("beginBtn", "BEGIN RUN", panelX + (panelW-S(240))/2, y-S(60), S(240), S(60), GREEN, DGREEN)
    y = y - S(60) - S(14)
    drawButton("backModeBtn", "BACK", panelX + (panelW-S(200))/2, y-S(48), S(200), S(48), BTN, TXT)
end

function drawGameOverScreen()
    fc(6, 9, 14, 210); rectF(0, 0, WIDTH, HEIGHT)
    txtC("YOU FELL", WIDTH/2, HEIGHT/2 + S(110), S(40), color(255,93,93))
    if gameMode == "classic" then
        txtC("Wave " .. wave .. "    Kills " .. kills .. "    Coins " .. coins, WIDTH/2, HEIGHT/2 + S(72), S(17), TXT)
    else
        local mm = math.floor(survivalTime/60)
        local ss = math.floor(survivalTime % 60)
        txtC(string.format("Survived %d:%02d    Kills %d    Coins %d", mm, ss, kills, coins), WIDTH/2, HEIGHT/2 + S(72), S(17), TXT)
    end
    txtC("Gems banked: " .. gems, WIDTH/2, HEIGHT/2 + S(46), S(17), CYAN)
    drawButton("retryBtn", "PLAY AGAIN", WIDTH/2 - S(120), HEIGHT/2 - S(50), S(240), S(60), GREEN, DGREEN)
    drawButton("menuBtn", "MAIN MENU", WIDTH/2 - S(120), HEIGHT/2 - S(120), S(240), S(50), BTN, TXT)
end

function drawPauseOverlay()
    fc(6, 9, 14, 180); rectF(0, 0, WIDTH, HEIGHT)
    txtC("PAUSED", WIDTH/2, HEIGHT/2 + S(80), S(36), TXT)
    drawButton("resumeBtn2", "RESUME", WIDTH/2-S(120), HEIGHT/2-S(10), S(240), S(60), GREEN, DGREEN)
    drawButton("quitBtn", "QUIT TO MENU", WIDTH/2-S(120), HEIGHT/2-S(80), S(240), S(54), color(200,50,50), color(255,235,235))
end

-- ---------- menu panel helpers ----------

local function backdrop() fc(6, 9, 14, 200); rectF(0, 0, WIDTH, HEIGHT) end

local function closeButton(id, label, panelX, panelY, panelW)
    local closeW, closeH = S(200), S(50)
    local closeX, closeY = panelX + (panelW-closeW)/2, panelY + S(12)
    fc(BTN); rectF(closeX, closeY, closeW, closeH)
    txtC(label, closeX + closeW/2, closeY + closeH/2, S(18), TXT)
    table.insert(buttons, {id=id, x=closeX, y=closeY, w=closeW, h=closeH})
end

local function panelBox(rowH, rows, extraTop, maxW)
    local panelW = math.min(WIDTH - S(80), S(maxW or 640))
    local panelX = (WIDTH - panelW)/2
    local panelH = math.min(HEIGHT - S(40), S(extraTop or 90) + rowH * rows + S(70))
    local panelY = math.max(S(20), (HEIGHT - panelH)/2)
    fc(PANEL); rectF(panelX, panelY, panelW, panelH)
    return panelX, panelY, panelW, panelH
end

-- ---------- scrollable list helpers (shops + relics) ----------
listScroll, listMaxScroll = 0, 0

local function beginScrollList(panelX, panelW, viewTop, viewBottom, contentH, topPad)
    local y0 = viewTop - topPad
    listMaxScroll = math.max(0, contentH - (y0 - viewBottom))
    listScroll = math.max(0, math.min(listMaxScroll, listScroll))
    love.graphics.setScissor(panelX, HEIGHT - viewTop, panelW, viewTop - viewBottom)
    return y0 + listScroll
end

local function endScrollList(panelX, panelW, viewTop, viewBottom, contentH)
    love.graphics.setScissor()
    if listMaxScroll > 0 then
        local viewH = viewTop - viewBottom
        local barH = math.max(S(30), viewH * viewH / (contentH + S(16)))
        local barY = viewTop - barH - (viewH - barH) * (listScroll / listMaxScroll)
        fc(255, 255, 255, 60)
        rectF(panelX + panelW - S(8), barY, S(4), barH)
    end
end

function drawUpgradePanel(title, currencyLabel, currencyVal, defs, levelFn, costFn, buyPrefix, closeId, closeLabel)
    backdrop()
    local rowH = S(76)
    local panelX, panelY, panelW, panelH = panelBox(rowH, #defs, 90)

    txtL(title, panelX + S(20), panelY + panelH - S(38), S(24), TXT)
    txtL(currencyLabel .. ": " .. currencyVal, panelX + S(20), panelY + panelH - S(64), S(17), GOLD)

    local viewTop = panelY + panelH - S(80)
    local viewBottom = panelY + S(70)
    local contentH = #defs * rowH - S(12)
    local y = beginScrollList(panelX, panelW, viewTop, viewBottom, contentH, S(16))
    for _, def in ipairs(defs) do
        local lvl = levelFn(def.key)
        local maxed = lvl >= def.max
        local cost = costFn(def)

        fc(ROW)
        rectF(panelX + S(16), y - rowH + S(12), panelW - S(32), rowH - S(12))
        txtL(def.name, panelX + S(32), y - S(22), S(18), TXT)
        txtL(def.desc .. "   (Lv " .. lvl .. (maxed and "/MAX" or "/"..def.max) .. ")", panelX + S(32), y - S(44), S(13), MUTED)

        local btnW, btnH = S(110), S(44)
        local btnX = panelX + panelW - btnW - S(28)
        local btnY = y - rowH + S(24)
        local canBuy = (not maxed) and currencyVal >= cost
        fc(canBuy and BUYON or BUYOFF)
        rectF(btnX, btnY, btnW, btnH)
        txtC(maxed and "MAX" or ("$" .. cost), btnX + btnW/2, btnY + btnH/2, S(18),
             canBuy and color(215,255,232) or MUTED)

        if btnY >= viewBottom and btnY + btnH <= viewTop then
            table.insert(buttons, {id=buyPrefix..def.key, x=btnX, y=btnY, w=btnW, h=btnH})
        end
        y = y - rowH
    end
    endScrollList(panelX, panelW, viewTop, viewBottom, contentH)

    closeButton(closeId, closeLabel, panelX, panelY, panelW)
end

function drawShop()
    drawUpgradePanel("RUN UPGRADES", "coins", coins, upgradeDefs, levelOf, costOf, "buy_", "closeShop", "CLOSE")
end
function drawMetaShop()
    drawUpgradePanel("PERMANENT UPGRADES", "gems", gems, permDefs, permLevelOf, permCostOf, "permbuy_", "closeMeta", "BACK")
end

function drawWeaponShop()
    backdrop()
    local rowH = S(80)
    local panelX, panelY, panelW, panelH = panelBox(rowH, #weaponDefs, 90)
    txtL("WEAPONS", panelX + S(20), panelY + panelH - S(38), S(24), TXT)
    txtL("gems: " .. gems, panelX + S(20), panelY + panelH - S(64), S(17), GOLD)

    local y = panelY + panelH - S(96)
    for _, def in ipairs(weaponDefs) do
        local owned = unlockedWeapons[def.key] or def.cost == 0

        fc(ROW)
        rectF(panelX + S(16), y - rowH + S(12), panelW - S(32), rowH - S(12))
        txtL(def.name, panelX + S(32), y - S(24), S(18), TXT)
        txtL(def.desc, panelX + S(32), y - S(46), S(13), MUTED)

        local btnW, btnH = S(110), S(44)
        local btnX = panelX + panelW - btnW - S(28)
        local btnY = y - rowH + S(28)
        local canBuy = (not owned) and gems >= def.cost
        fc((not owned and canBuy) and BUYON or BUYOFF)
        rectF(btnX, btnY, btnW, btnH)
        txtC(owned and "OWNED" or ("$" .. def.cost), btnX + btnW/2, btnY + btnH/2, S(16),
             (not owned and canBuy) and color(215,255,232) or MUTED)

        if not owned then
            table.insert(buttons, {id="buyweapon_"..def.key, x=btnX, y=btnY, w=btnW, h=btnH})
        end
        y = y - rowH
    end

    closeButton("closeWeaponShop", "BACK", panelX, panelY, panelW)
end

function drawSkinShop()
    backdrop()
    local rowH = S(76)
    local panelX, panelY, panelW, panelH = panelBox(rowH, #skinDefs, 90)
    txtL("SKINS", panelX + S(20), panelY + panelH - S(38), S(24), TXT)
    txtL("gems: " .. gems, panelX + S(20), panelY + panelH - S(64), S(17), GOLD)

    local y = panelY + panelH - S(96)
    for _, def in ipairs(skinDefs) do
        local owned = unlockedSkins[def.key] or def.cost == 0
        local equipped = (activeSkin == def.key)

        fc(ROW)
        rectF(panelX + S(16), y - rowH + S(12), panelW - S(32), rowH - S(12))
        fc(def.col)
        circF(panelX + S(40), y - S(34), S(28))

        txtL(def.name, panelX + S(64), y - S(24), S(17), TXT)
        txtL(equipped and "Equipped" or (owned and "Owned -- click to equip" or ("Cost: " .. def.cost .. " gems")),
             panelX + S(64), y - S(44), S(12), MUTED)

        local btnW, btnH = S(110), S(44)
        local btnX = panelX + panelW - btnW - S(28)
        local btnY = y - rowH + S(24)
        local label, bg
        if equipped then
            label = "EQUIPPED"; bg = BUYON
        elseif owned then
            label = "EQUIP"; bg = BTN
        else
            label = "$" .. def.cost
            bg = (gems >= def.cost) and BUYON or BUYOFF
        end
        fc(bg); rectF(btnX, btnY, btnW, btnH)
        txtC(label, btnX + btnW/2, btnY + btnH/2, S(16), WHITE)

        if not equipped then
            table.insert(buttons, {id="skin_"..def.key, x=btnX, y=btnY, w=btnW, h=btnH})
        end
        y = y - rowH
    end

    closeButton("closeSkinShop", "BACK", panelX, panelY, panelW)
end

-- Relic list scrolls (13 rows don't fit on most screens)
function drawRelicMenu()
    backdrop()
    local rowH = S(82)
    local panelX, panelY, panelW, panelH = panelBox(rowH, #relicDefs, 100)
    txtL("RELICS", panelX + S(20), panelY + panelH - S(38), S(24), TXT)

    local unlockedCount = 0
    for _, d in ipairs(relicDefs) do if relicUnlocked[d.key] then unlockedCount = unlockedCount + 1 end end
    txtL(unlockedCount .. "/" .. #relicDefs .. " unlocked -- toggle any on or off", panelX + S(20), panelY + panelH - S(62), S(14), color(160,90,255))

    local viewTop = panelY + panelH - S(76)
    local viewBottom = panelY + S(68)
    local contentH = #relicDefs * rowH - S(12)
    local y = beginScrollList(panelX, panelW, viewTop, viewBottom, contentH, S(8))
    for _, def in ipairs(relicDefs) do
        local unlocked = relicUnlocked[def.key]
        local enabled = relicEnabled[def.key]

        fc(ROW)
        rectF(panelX + S(16), y - rowH + S(12), panelW - S(32), rowH - S(12))

        txtL(def.name, panelX + S(32), y - S(24), S(17), unlocked and TXT or color(90,96,108))
        if unlocked then
            txtL(def.desc, panelX + S(32), y - S(46), S(12), MUTED)
        else
            txtL("Locked -- " .. def.hint, panelX + S(32), y - S(46), S(12), color(80,84,92))
        end

        local btnW, btnH = S(100), S(44)
        local btnX = panelX + panelW - btnW - S(28)
        local btnY = y - rowH + S(24)
        local visible = (btnY >= viewBottom and btnY + btnH <= viewTop)
        if unlocked then
            fc(enabled and color(160,90,255) or BUYOFF)
            rectF(btnX, btnY, btnW, btnH)
            txtC(enabled and "ON" or "OFF", btnX + btnW/2, btnY + btnH/2, S(15), WHITE)
            if visible then
                table.insert(buttons, {id="relic_"..def.key, x=btnX, y=btnY, w=btnW, h=btnH})
            end
        else
            fc(35, 40, 50)
            rectF(btnX, btnY, btnW, btnH)
            txtC("LOCKED", btnX + btnW/2, btnY + btnH/2, S(14), color(70,76,86))
        end
        y = y - rowH
    end
    endScrollList(panelX, panelW, viewTop, viewBottom, contentH)

    closeButton("closeRelicMenu", "BACK", panelX, panelY, panelW)
end

function drawSettings()
    backdrop()
    local panelW = math.min(WIDTH - S(80), S(560))
    local panelX = (WIDTH - panelW)/2
    local panelH = S(340)
    local panelY = math.max(S(20), (HEIGHT - panelH)/2)
    fc(PANEL); rectF(panelX, panelY, panelW, panelH)
    txtL("SETTINGS", panelX + S(20), panelY + panelH - S(38), S(24), TXT)

    local rowH = S(64)
    local y = panelY + panelH - S(76)
    local btnW, btnH = S(120), S(44)
    local btnX = panelX + panelW - btnW - S(20)

    txtL("Sound", panelX + S(20), y - S(18), S(17), TXT)
    fc(soundOn and BUYON or BUYOFF)
    rectF(btnX, y - rowH + S(10), btnW, btnH)
    txtC(soundOn and "ON" or "OFF", btnX + btnW/2, y - rowH + S(10) + btnH/2, S(16), WHITE)
    table.insert(buttons, {id="toggleSound", x=btnX, y=y-rowH+S(10), w=btnW, h=btnH})
    y = y - rowH

    txtL("Joystick Sensitivity", panelX + S(20), y - S(18), S(17), TXT)
    fc(BTN)
    rectF(btnX, y - rowH + S(10), btnW, btnH)
    txtC(joySensLabel(), btnX + btnW/2, y - rowH + S(10) + btnH/2, S(16), WHITE)
    table.insert(buttons, {id="cycleSens", x=btnX, y=y-rowH+S(10), w=btnW, h=btnH})
    y = y - rowH

    local achCount = 0
    for _, d in ipairs(achievementDefs) do if achieved[d.id] then achCount = achCount + 1 end end
    txtL("Achievements unlocked: " .. achCount .. "/" .. #achievementDefs, panelX + S(20), y - S(10), S(15), GOLD)
    y = y - S(38)

    local resetW = panelW - S(40)
    fc(resetConfirm and color(200,50,50) or color(80,30,30))
    rectF(panelX + S(20), y - S(50), resetW, S(44))
    txtC(resetConfirm and "CLICK AGAIN TO CONFIRM RESET" or "RESET ALL PROGRESS",
         panelX + S(20) + resetW/2, y - S(28), S(16), color(255,235,235))
    table.insert(buttons, {id="resetBtn", x=panelX+S(20), y=y-S(50), w=resetW, h=S(44)})

    closeButton("closeSettings", "BACK", panelX, panelY, panelW)
end

-- ============================================================
-- INPUT
-- ============================================================

function pointInButton(x, y, b)
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function hitButton(x, y)
    for _, b in ipairs(buttons) do
        if pointInButton(x, y, b) then return b.id end
    end
    return nil
end

function handleButton(id)
    playSound("click")

    if id == "startBtn" then
        state = "modeSelect"
    elseif id == "beginBtn" then
        gameMode = modeDefs[modeIndex].key
        state = "playing"
        newGame()
    elseif id == "backModeBtn" then
        state = "start"
    elseif id and id:sub(1,5) == "mode_" then
        local idx = tonumber(id:sub(6))
        if idx then modeIndex = idx; saveProjectData("modeIndex", modeIndex) end
    elseif id and id:sub(1,5) == "diff_" then
        local idx = tonumber(id:sub(6))
        if idx then difficultyIndex = idx; saveProjectData("difficultyIndex", difficultyIndex) end
    elseif id == "metaBtn" then
        state = "metaShop"
    elseif id == "closeMeta" then
        state = "start"
    elseif id == "weaponBtn" then
        state = "weaponShop"
    elseif id == "closeWeaponShop" then
        state = "start"
    elseif id == "skinBtn" then
        state = "skinShop"
    elseif id == "closeSkinShop" then
        state = "start"
    elseif id == "relicBtn" then
        state = "relicMenu"; listScroll = 0
    elseif id == "closeRelicMenu" then
        state = "start"
    elseif id and id:sub(1,6) == "relic_" then
        local key = id:sub(7)
        if relicUnlocked[key] then
            relicEnabled[key] = not relicEnabled[key]
            persistMeta()
        end
    elseif id == "settingsBtn" then
        state = "settings"; resetConfirm = false
    elseif id == "closeSettings" then
        state = "start"; resetConfirm = false
    elseif id == "toggleSound" then
        soundOn = not soundOn; persistMeta()
    elseif id == "cycleSens" then
        joySensIndex = joySensIndex % 3 + 1; persistMeta()
    elseif id == "resetBtn" then
        if resetConfirm then resetProgress(); resetConfirm = false
        else resetConfirm = true end
    elseif id == "retryBtn" then
        state = "playing"; newGame()
    elseif id == "menuBtn" then
        state = "start"
    elseif id == "shopBtn" then
        state = (state == "shop") and "playing" or "shop"
    elseif id == "closeShop" then
        state = "playing"
    elseif id == "pauseBtn" then
        state = (state == "paused") and "playing" or "paused"
    elseif id == "resumeBtn2" then
        state = "playing"
    elseif id == "quitBtn" then
        if gameMode == "horde" and survivalTime > bestSurvivalTime then
            bestSurvivalTime = survivalTime
        end
        persistMeta()
        state = "start"
    elseif id == "cycleWeaponBtn" then
        cycleWeapon()
    elseif id and id:sub(1,4) == "buy_" then
        local key = id:sub(5)
        local def
        for _, d in ipairs(upgradeDefs) do if d.key == key then def = d end end
        if def then
            local cost = costOf(def)
            if coins >= cost and levelOf(key) < def.max then
                coins = coins - cost
                upgrades[key] = levelOf(key) + 1
                if key == "maxHp" and player then
                    local s = baseStats()
                    player.maxHp = s.maxHp
                    player.hp = s.maxHp
                end
            end
        end
    elseif id and id:sub(1,8) == "permbuy_" then
        local key = id:sub(9)
        local def
        for _, d in ipairs(permDefs) do if d.key == key then def = d end end
        if def then
            local cost = permCostOf(def)
            if gems >= cost and permLevelOf(key) < def.max then
                gems = gems - cost
                permUpgrades[key] = permLevelOf(key) + 1
                permPurchaseCount = permPurchaseCount + 1
                persistMeta()
                checkProgress()
            end
        end
    elseif id and id:sub(1,10) == "buyweapon_" then
        local key = id:sub(11)
        local def
        for _, d in ipairs(weaponDefs) do if d.key == key then def = d end end
        if def and not unlockedWeapons[key] then
            if gems >= def.cost then
                gems = gems - def.cost
                unlockedWeapons[key] = true
                persistMeta()
                checkProgress()
            end
        end
    elseif id and id:sub(1,5) == "skin_" then
        local key = id:sub(6)
        local def
        for _, d in ipairs(skinDefs) do if d.key == key then def = d end end
        if def then
            if unlockedSkins[key] or def.cost == 0 then
                activeSkin = key
                persistMeta()
            elseif gems >= def.cost then
                gems = gems - def.cost
                unlockedSkins[key] = true
                activeSkin = key
                persistMeta()
                checkProgress()
            end
        end
    end
end

function updateJoystickFromTouch(tx, ty)
    local dx, dy = tx - joyBaseX, ty - joyBaseY
    local maxR = S(70)
    local len = math.sqrt(dx*dx + dy*dy)
    if len > maxR then
        dx = dx / len * maxR
        dy = dy / len * maxR
        len = maxR
    end
    joyThumbX = joyBaseX + dx
    joyThumbY = joyBaseY + dy
    if len < S(10) then
        moveX, moveY = 0, 0
    else
        moveX, moveY = dx / maxR, dy / maxR
    end
end

function isListState() return state == "relicMenu" or state == "shop" or state == "metaShop" end

-- unified pointer handlers (x,y already in Codea coords: y up)
local function pointerBegan(id, x, y)
    local hitId = hitButton(x, y)
    if hitId then
        handleButton(hitId)
        return
    end
    if state == "playing" and not joyTouchId then
        joyTouchId = id
        joyBaseX, joyBaseY = x, y
        joyThumbX, joyThumbY = x, y
        moveX, moveY = 0, 0
    elseif isListState() and not dragId then
        dragId, dragLastY = id, y
    end
end

local function pointerMoved(id, x, y)
    if state == "playing" and id == joyTouchId then
        updateJoystickFromTouch(x, y)
    elseif isListState() and id == dragId then
        listScroll = math.max(0, math.min(listMaxScroll, listScroll + (y - dragLastY)))
        dragLastY = y
    end
end

local function pointerEnded(id)
    if id == joyTouchId then
        joyTouchId = nil
        joyBaseX, joyBaseY = nil, nil
        moveX, moveY = 0, 0
    end
    if id == dragId then dragId = nil end
end

-- mouse (touch-generated mouse events are ignored; touch callbacks handle those)
function love.mousepressed(x, y, button, istouch)
    if istouch or button ~= 1 then return end
    pointerBegan("mouse", x, HEIGHT - y)
end
function love.mousemoved(x, y, dx, dy, istouch)
    if istouch then return end
    pointerMoved("mouse", x, HEIGHT - y)
end
function love.mousereleased(x, y, button, istouch)
    if istouch or button ~= 1 then return end
    pointerEnded("mouse")
end

local function touchPos(x, y)
    if x <= 1 and y <= 1 then x, y = x * WIDTH, y * HEIGHT end  -- normalized -> pixels
    return x, HEIGHT - y
end
function love.touchpressed(id, x, y) pointerBegan(id, touchPos(x, y)) end
function love.touchmoved(id, x, y) pointerMoved(id, touchPos(x, y)) end
function love.touchreleased(id) pointerEnded(id) end

function love.wheelmoved(wx, wy)
    if isListState() then
        listScroll = math.max(0, math.min(listMaxScroll, listScroll - wy * S(40)))
    end
end

function debugKey(key)
    local shift = love.keyboard.isDown("lshift", "rshift")
    local inRun = player and (state == "playing" or state == "paused" or state == "shop")
    local msg
    if key == "f1" then
        debugOverlay = not debugOverlay
    elseif key == "f2" then
        gems = gems + 100; persistMeta(); msg = "+100 gems"
    elseif key == "f3" then
        coins = coins + 500; msg = "+500 coins"
    elseif key == "f4" and inRun then
        if gameMode == "classic" then
            zombies, enemyBullets, spawnQueue = {}, {}, {}
            wave = wave + (shift and 5 or 1)
            waveClearDelay = 0
            touchBestWave(); startWave(); checkProgress(); persistMeta()
            msg = "jumped to wave " .. wave
        else
            survivalTime = survivalTime + (shift and 300 or 60)
            msg = "+" .. (shift and "5 min" or "1 min")
        end
    elseif key == "f5" and inRun then
        spawnZombie("boss", (gameMode == "classic") and math.max(1, wave) or (1 + math.floor(survivalTime / 20)))
        msg = "boss spawned"
    elseif key == "f6" then
        for _, d in ipairs(weaponDefs) do unlockedWeapons[d.key] = true end
        for _, d in ipairs(skinDefs) do unlockedSkins[d.key] = true end
        for _, d in ipairs(relicDefs) do relicUnlocked[d.key] = true end
        persistMeta(); msg = "unlocked all weapons, skins, relics"
    elseif key == "f7" and inRun then
        player.hp = player.maxHp; msg = "full heal"
    elseif key == "f8" and inRun then
        zombies, enemyBullets = {}, {}; msg = "enemies cleared"
    elseif key == "f9" then
        debugGod = not debugGod; msg = "invincible " .. (debugGod and "ON" or "OFF")
    else
        return false
    end
    if msg and inRun then showWaveBanner("[debug] " .. msg) end
    return true
end

function drawDebug()
    local lines = {
        "DEBUG   " .. love.timer.getFPS() .. " fps",
        "enemies " .. #zombies .. "   shots " .. (#bullets + #enemyBullets) .. "   fx " .. #particles,
        (gameMode == "classic") and ("wave " .. wave .. "   queue " .. #spawnQueue)
                                or ("horde time " .. math.floor(survivalTime) .. "s"),
        "F2 +100 gems    F3 +500 coins",
        "F4 next wave (Shift: +5 / +5min)",
        "F5 spawn boss   F6 unlock all",
        "F7 full heal    F8 clear enemies",
        "F9 invincible: " .. (debugGod and "ON" or "OFF"),
        "F1 hide this panel",
    }
    local w, h = S(260), #lines * S(16) + S(12)
    local x, y = WIDTH - w - S(10), HEIGHT - S(70) - h
    fc(0, 0, 0, 170); rectF(x, y, w, h)
    for i, l in ipairs(lines) do
        txtL(l, x + S(8), y + h - S(6) - i * S(16), S(12), i == 1 and GOLD or TXT)
    end
end

function love.keypressed(key)
    if DEBUG and debugKey(key) then return end
    if key == "escape" or key == "p" then
        if state == "playing" then state = "paused"
        elseif state == "paused" or state == "shop" then state = "playing" end
    elseif state == "playing" then
        if key == "tab" then cycleWeapon()
        elseif key == "b" then state = "shop" end
    elseif state == "shop" and key == "b" then
        state = "playing"
    end
end