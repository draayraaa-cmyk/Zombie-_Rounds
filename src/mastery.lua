-- mastery.lua
-- Weapon mastery: kills with a weapon (tracked in weaponKills, see state.lua/save.lua)
-- unlock small permanent-feeling bonuses for that weapon, for that weapon only.
-- Tiers are cumulative in name but not in bonus -- each tier's numbers are the
-- weapon's full bonus at that tier, not an addition to the previous one.

MASTERY_TIERS = {
    {kills=100,  dmg=0.08, rate=0.00, label="Tier I"},
    {kills=500,  dmg=0.16, rate=0.10, label="Tier II"},
    {kills=1000, dmg=0.25, rate=0.20, label="Tier III"},
}

-- 0 = no tier reached yet, 1..#MASTERY_TIERS = highest tier reached
function masteryTierOf(key)
    local k = (weaponKills and weaponKills[key]) or 0
    local t = 0
    for i, def in ipairs(MASTERY_TIERS) do
        if k >= def.kills then t = i else break end
    end
    return t
end

function masteryDmgBonus(key)
    local t = masteryTierOf(key)
    return t > 0 and MASTERY_TIERS[t].dmg or 0
end

function masteryRateBonus(key)
    local t = masteryTierOf(key)
    return t > 0 and MASTERY_TIERS[t].rate or 0
end

-- Everything the UI needs in one call: current tier index/label, kills so far,
-- the next tier's threshold (nil if maxed), and progress 0..1 toward it.
function masteryInfo(key)
    local k = (weaponKills and weaponKills[key]) or 0
    local t = masteryTierOf(key)
    local nextDef = MASTERY_TIERS[t + 1]
    local prevThreshold = t > 0 and MASTERY_TIERS[t].kills or 0
    local frac = 1
    if nextDef then
        frac = (k - prevThreshold) / (nextDef.kills - prevThreshold)
    end
    return {
        tier = t,
        label = t > 0 and MASTERY_TIERS[t].label or "Unranked",
        kills = k,
        nextThreshold = nextDef and nextDef.kills or nil,
        maxed = (nextDef == nil),
        progress = math.max(0, math.min(1, frac)),
    }
end
