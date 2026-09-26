-- audio.lua
-- Procedural sound: no audio assets, everything is synthesized at startup.

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

function initSounds()
    local ok = pcall(function()
        sounds.shoot   = makeSound(900, 300, 0.08, "square", 0.12)
        sounds.hit     = makeSound(0, 0, 0.06, "noise", 0.18)
        sounds.hurt    = makeSound(220, 80, 0.18, "square", 0.25)
        sounds.coin    = makeSound(600, 1200, 0.12, "sine", 0.25)
        sounds.explode = makeSound(0, 0, 0.35, "noise", 0.35)
        sounds.click   = makeSound(500, 500, 0.04, "square", 0.12)
        -- 1.1.0 Arsenal weapons
        sounds.zap     = makeSound(2000, 350, 0.09, "square", 0.14)   -- Arc Gun
        sounds.thud    = makeSound(180, 50, 0.10, "square", 0.18)     -- Crossbow
        sounds.beep    = makeSound(900, 850, 0.06, "sine", 0.15)      -- Mine Layer (placing)
        sounds.whoosh  = makeSound(0, 0, 0.22, "noise", 0.10)         -- Boomerang (throw)
        sounds.whirr   = makeSound(260, 300, 0.08, "square", 0.08)    -- Orbital Blades (ticks while spinning)
        -- 1.1.0 pickups
        sounds.freeze  = makeSound(1200, 1800, 0.16, "sine", 0.18)    -- Freeze
        sounds.magnet  = makeSound(300, 900, 0.12, "square", 0.12)    -- Magnet
        sounds.alarm   = makeSound(300, 1200, 0.35, "square", 0.20)   -- Nuke (layered with explode)
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
