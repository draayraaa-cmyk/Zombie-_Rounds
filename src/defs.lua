-- defs.lua
-- Static game definitions (upgrades, weapons, skins, modes, relics, achievements).
-- Unlock/check closures read global progress variables at call time, so this
-- file can be loaded before the state is initialised.

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
    {key="arc",         name="Arc Gun",          short="ARC",     desc="Chain lightning jumps between zombies", cost=55},
    {key="crossbow",    name="Crossbow",         short="XBOW",    desc="Heavy piercing bolt with knockback", cost=60},
    {key="mines",       name="Mine Layer",       short="MINES",   desc="Drops mines that blow up near zombies", cost=70},
    {key="blades",      name="Orbital Blades",   short="BLADES",  desc="Blades orbit you and shred what's close", cost=80},
    {key="boomerang",   name="Boomerang",        short="BOOM",    desc="Flies out and back, hitting both ways", cost=90},
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
    {key="stormcaller",name="Storm Caller",    desc="Arc Gun chains 2 extra times",
     hint="150 kills with the Arc Gun",
     unlock=function() return (weaponKills.arc or 0) >= 150 end},
    {key="heavybolts", name="Heavy Bolts",     desc="Crossbow: +40% damage, more knockback",
     hint="150 kills with the Crossbow",
     unlock=function() return (weaponKills.crossbow or 0) >= 150 end},
    {key="demolitionist",name="Demolitionist", desc="Mine Layer: +40% blast size & damage",
     hint="150 kills with the Mine Layer",
     unlock=function() return (weaponKills.mines or 0) >= 150 end},
    {key="whirlwind",  name="Whirlwind",       desc="Orbital Blades: +1 blade, spin 25% faster",
     hint="150 kills with the Orbital Blades",
     unlock=function() return (weaponKills.blades or 0) >= 150 end},
    {key="razorwind",  name="Razor Wind",      desc="Boomerang: +35% damage, +25% range",
     hint="150 kills with the Boomerang",
     unlock=function() return (weaponKills.boomerang or 0) >= 150 end},
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
    {id="arc_100",    name="Static Charge", desc="100 kills with the Arc Gun",       reward=15, check=function() return (weaponKills.arc or 0) >= 100 end},
    {id="xbow_100",   name="Bolt Action",   desc="100 kills with the Crossbow",      reward=15, check=function() return (weaponKills.crossbow or 0) >= 100 end},
    {id="mines_100",  name="Minefield",     desc="100 kills with the Mine Layer",    reward=15, check=function() return (weaponKills.mines or 0) >= 100 end},
    {id="blades_100", name="Blender",       desc="100 kills with the Orbital Blades",reward=15, check=function() return (weaponKills.blades or 0) >= 100 end},
    {id="boom_100",   name="Full Circle",   desc="100 kills with the Boomerang",     reward=15, check=function() return (weaponKills.boomerang or 0) >= 100 end},
}
