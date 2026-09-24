-- debug_tools.lua
-- F1 overlay and F2-F9 cheats. Set DEBUG = false to disable everything here.

DEBUG = false         -- set true to enable debug keys (F1-F9); keep false for release builds
debugOverlay, debugGod = false, false

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
