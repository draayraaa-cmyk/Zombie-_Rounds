-- save.lua
-- Persistence (replacement for Codea's readProjectData / saveProjectData),
-- serialization helpers, and meta-progress save/reset.

local SAVE_FILE = "zombiesiege.sav"
local saveData, saveDirty = {}, false

function loadSave()
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

function flushSave()
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

-- ---------- (de)serialization ----------

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

-- ---------- meta save / reset ----------

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
    saveProjectData("weaponKillsStr", serializeLevels(weaponKills, weaponDefs))
    saveProjectData("startWeapon", startWeapon)
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
    weaponKills = {}
    startWeapon = "pistol"
    unlockedSkins = {green = true}
    activeSkin = "green"
    modeIndex = 1
    difficultyIndex = 2
    achieved = {}
    relicUnlocked = {}
    relicEnabled = {}
    persistMeta()
end
