-- panels.lua
-- Panel-style screens: run shop, permanent shop, weapon/skin shops, relics, settings.
-- Includes the shared panel + scroll-list helpers they all use.

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
    local availW = WIDTH - SAFE.l - SAFE.r
    local availH = HEIGHT - SAFE.t - SAFE.b
    local panelW = math.min(availW - S(80), S(maxW or 640))
    local panelX = SAFE.l + (availW - panelW)/2
    local panelH = math.min(availH - S(40), S(extraTop or 90) + rowH * rows + S(70))
    local panelY = SAFE.b + math.max(S(20), (availH - panelH)/2)
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

-- ---------- upgrade shops (run + permanent) ----------

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

-- ---------- weapons / skins ----------

function drawWeaponShop()
    backdrop()
    -- taller rows than 1.0.x: an extra line for mastery progress, plus the
    -- "set as starting weapon" toggle for weapons you already own
    local rowH = S(100)
    local panelX, panelY, panelW, panelH = panelBox(rowH, #weaponDefs, 90)
    txtL("WEAPONS", panelX + S(20), panelY + panelH - S(38), S(24), TXT)
    txtL("gems: " .. gems, panelX + S(20), panelY + panelH - S(64), S(17), GOLD)

    local viewTop = panelY + panelH - S(80)
    local viewBottom = panelY + S(70)
    local contentH = #weaponDefs * rowH - S(12)
    local y = beginScrollList(panelX, panelW, viewTop, viewBottom, contentH, S(16))
    for _, def in ipairs(weaponDefs) do
        local owned = unlockedWeapons[def.key] or def.cost == 0
        local isStart = (startWeapon == def.key)

        fc(ROW)
        rectF(panelX + S(16), y - rowH + S(12), panelW - S(32), rowH - S(12))
        txtL(def.name, panelX + S(32), y - S(22), S(18), TXT)
        txtL(def.desc, panelX + S(32), y - S(42), S(13), MUTED)

        if owned then
            local info = masteryInfo(def.key)
            local label = info.maxed
                and ("MAX MASTERY -- " .. info.kills .. " kills")
                or  (info.label .. " -- " .. info.kills .. "/" .. info.nextThreshold .. " kills")
            txtL(label, panelX + S(32), y - S(60), S(12), info.tier > 0 and CYAN or MUTED)

            local barW = math.min(S(240), panelW - S(64))
            local barY = y - S(74)
            fc(0, 0, 0, 140)
            rectF(panelX + S(32), barY, barW, S(6))
            fc(info.maxed and GOLD or CYAN)
            rectF(panelX + S(32), barY, barW * info.progress, S(6))
        end

        local btnW, btnH = S(110), S(40)
        local btnX = panelX + panelW - btnW - S(28)
        local btnY = y - S(70)
        local visible = (btnY >= viewBottom and btnY + btnH <= viewTop)

        if owned then
            fc(BUYON)
            rectF(btnX, btnY, btnW, btnH)
            txtC("OWNED", btnX + btnW/2, btnY + btnH/2, S(15), color(215,255,232))

            local sBtnW = S(100)
            local sBtnX = btnX - sBtnW - S(10)
            fc(isStart and color(160,90,255) or BTN)
            rectF(sBtnX, btnY, sBtnW, btnH)
            txtC(isStart and "STARTING" or "SET START", sBtnX + sBtnW/2, btnY + btnH/2, S(13),
                 isStart and WHITE or color(200,205,215))
            if visible and not isStart then
                table.insert(buttons, {id="startweapon_"..def.key, x=sBtnX, y=btnY, w=sBtnW, h=btnH})
            end
        else
            local canBuy = gems >= def.cost
            fc(canBuy and BUYON or BUYOFF)
            rectF(btnX, btnY, btnW, btnH)
            txtC("$" .. def.cost, btnX + btnW/2, btnY + btnH/2, S(16),
                 canBuy and color(215,255,232) or MUTED)
            if visible then
                table.insert(buttons, {id="buyweapon_"..def.key, x=btnX, y=btnY, w=btnW, h=btnH})
            end
        end
        y = y - rowH
    end
    endScrollList(panelX, panelW, viewTop, viewBottom, contentH)

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

-- ---------- relics (scrolls: 13 rows don't fit on most screens) ----------

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

-- ---------- weapon mastery stats page ----------

function drawStatsScreen()
    backdrop()
    local rowH = S(92)
    local panelX, panelY, panelW, panelH = panelBox(rowH, #weaponDefs, 100)
    txtL("WEAPON STATS", panelX + S(20), panelY + panelH - S(38), S(24), TXT)

    local totalKills = 0
    for _, def in ipairs(weaponDefs) do totalKills = totalKills + ((weaponKills and weaponKills[def.key]) or 0) end
    txtL("lifetime kills: " .. totalKills, panelX + S(20), panelY + panelH - S(62), S(14), GOLD)

    local viewTop = panelY + panelH - S(76)
    local viewBottom = panelY + S(68)
    local contentH = #weaponDefs * rowH - S(12)
    local y = beginScrollList(panelX, panelW, viewTop, viewBottom, contentH, S(8))
    for _, def in ipairs(weaponDefs) do
        local owned = unlockedWeapons[def.key] or def.cost == 0
        local info = masteryInfo(def.key)

        fc(ROW)
        rectF(panelX + S(16), y - rowH + S(12), panelW - S(32), rowH - S(12))

        txtL(def.name, panelX + S(32), y - S(24), S(17), owned and TXT or color(90,96,108))
        if not owned then
            txtL("Not unlocked yet", panelX + S(32), y - S(46), S(12), color(80,84,92))
        else
            local label = info.maxed
                and ("MAX MASTERY -- " .. info.kills .. " kills")
                or  (info.label .. " -- " .. info.kills .. "/" .. info.nextThreshold .. " kills")
            txtL(label, panelX + S(32), y - S(46), S(13), info.tier > 0 and CYAN or MUTED)

            local bonus
            if info.tier == 0 then
                bonus = "No bonus yet"
            else
                local t = MASTERY_TIERS[info.tier]
                bonus = string.format("+%d%% damage", math.floor(t.dmg*100 + 0.5))
                if t.rate > 0 then bonus = bonus .. string.format(", +%d%% fire rate", math.floor(t.rate*100 + 0.5)) end
            end
            txtL(bonus, panelX + S(32), y - S(64), S(12), MUTED)

            local barW = math.min(S(260), panelW - S(64))
            local barY = y - S(78)
            fc(0, 0, 0, 140)
            rectF(panelX + S(32), barY, barW, S(6))
            fc(info.maxed and GOLD or CYAN)
            rectF(panelX + S(32), barY, barW * info.progress, S(6))
        end
        y = y - rowH
    end
    endScrollList(panelX, panelW, viewTop, viewBottom, contentH)

    closeButton("closeStats", "BACK", panelX, panelY, panelW)
end

-- ---------- settings ----------

function drawSettings()
    backdrop()
    local availW = WIDTH - SAFE.l - SAFE.r
    local availH = HEIGHT - SAFE.t - SAFE.b
    local panelW = math.min(availW - S(80), S(560))
    local panelX = SAFE.l + (availW - panelW)/2
    local panelH = math.min(availH - S(40), S(340))
    local panelY = SAFE.b + math.max(S(20), (availH - panelH)/2)
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
