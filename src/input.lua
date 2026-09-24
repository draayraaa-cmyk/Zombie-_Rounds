-- input.lua
-- Button hit-testing and actions, joystick, and LÖVE input callbacks
-- (mouse, touch, wheel, keyboard).

function pointInButton(x, y, b)
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

-- Buttons are registered in draw order, so scan backwards: whatever was drawn
-- last (an overlay panel) is on top and gets the click, not the HUD beneath it.
function hitButton(x, y)
    for i = #buttons, 1, -1 do
        local b = buttons[i]
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

-- ---------- unified pointer handlers (x,y already in Codea coords: y up) ----------

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

-- ---------- LÖVE callbacks ----------

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
