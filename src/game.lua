-- game.lua
-- Run lifecycle: starting a run, starting waves, banners, ending the run.

function newGame()
    coins = 0
    upgrades = {}
    runDiff = difficultyDefs[difficultyIndex]
    pendingDeath = false
    usedSecondWind = false
    vampKillCounter = 0
    powerups = {}
    mines = {}
    arcs = {}
    bladeAngle = 0
    freezeTimeLeft = 0
    magnetTimeLeft = 0
    rouletteTimer = 30
    buffSpeedTimeLeft = 0
    buffDamageTimeLeft = 0
    shieldTimeLeft = 0

    local s = baseStats()
    player = {
        x = WIDTH/2, y = HEIGHT/2, r = S(24),
        hp = s.maxHp, maxHp = s.maxHp, fireCd = 0,
        facing = -math.pi/2, weapon = (unlockedWeapons[startWeapon] and startWeapon) or "pistol",
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
    bladeSoundTimer = 0
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
    if wave % 5 == 0 then table.insert(spawnQueue, rollBossType(wave)) end
    spawnTimer = 0
    waveActive = true
    showWaveBanner("Wave " .. wave)
end

function showWaveBanner(txt)
    waveBannerText = txt
    waveBannerAlpha = 1.0
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
