-- state.lua
-- Initial values for every global the game uses. Called once from love.load,
-- after the save file has been read.

function initState()
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
