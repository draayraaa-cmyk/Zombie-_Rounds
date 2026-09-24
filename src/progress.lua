-- progress.lua
-- Best-wave tracking and achievement / relic unlock checks.

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
