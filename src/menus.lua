-- menus.lua
-- Top-level menu screens: start screen and run setup (mode / difficulty).

function drawStartScreen()
    txtC("ZOMBIE SIEGE", WIDTH/2, HEIGHT - S(62), S(38), TXT)
    txtC("Drag / WASD to move. Auto-fires at the nearest zombie.", WIDTH/2, HEIGHT - S(90), S(13), MUTED)
    local mm = math.floor(bestSurvivalTime/60)
    local ss = math.floor(bestSurvivalTime % 60)
    txtC("gems " .. gems .. "    best wave " .. bestWave .. "    best horde " .. string.format("%d:%02d", mm, ss),
         WIDTH/2, HEIGHT - S(114), S(15), CYAN)
    local achCount = 0
    for _, d in ipairs(achievementDefs) do if achieved[d.id] then achCount = achCount + 1 end end
    local relicCount = 0
    for _, d in ipairs(relicDefs) do if relicUnlocked[d.key] then relicCount = relicCount + 1 end end
    txtC("achievements " .. achCount .. "/" .. #achievementDefs .. "    relics " .. relicCount .. "/" .. #relicDefs,
         WIDTH/2, HEIGHT - S(134), S(12), GOLD)

    local bY = S(20)
    local bx = WIDTH/2 - S(130)
    drawButton("startBtn", "START GAME", bx, bY, S(260), S(56), GREEN, DGREEN)
    bY = bY + S(56) + S(10)
    drawButton("weaponBtn", "WEAPONS", bx, bY, S(260), S(44), color(255,160,60), color(35,20,0))
    bY = bY + S(44) + S(8)
    drawButton("skinBtn", "SKINS", bx, bY, S(260), S(44), color(80,160,255), color(10,25,45))
    bY = bY + S(44) + S(8)
    drawButton("relicBtn", "RELICS", bx, bY, S(260), S(44), color(160,90,255), color(30,10,45))
    bY = bY + S(44) + S(8)
    drawButton("metaBtn", "PERMANENT UPGRADES", bx, bY, S(260), S(44), color(120,109,241), color(240,235,255))
    bY = bY + S(44) + S(8)
    drawButton("settingsBtn", "SETTINGS", bx, bY, S(260), S(40), BTN, TXT)
end

function drawModeSelect()
    fc(6, 9, 14, 200); rectF(0, 0, WIDTH, HEIGHT)
    local panelW = math.min(WIDTH - S(80), S(560))
    local panelX = (WIDTH - panelW)/2
    local panelH = S(420)
    local panelY = math.max(S(20), (HEIGHT - panelH)/2)
    fc(PANEL); rectF(panelX, panelY, panelW, panelH)

    local top = panelY + panelH - S(20)
    txtL("START RUN", panelX + S(20), top - S(30), S(24), TXT)

    local y = top - S(70)
    txtL("MODE", panelX + S(20), y, S(14), MUTED)
    y = y - S(38)
    local mw = (panelW - S(56))/2
    for i, m in ipairs(modeDefs) do
        local bx = panelX + S(20) + (i-1)*(mw+S(16))
        local sel = (i == modeIndex)
        fc(sel and GREEN or BTN)
        rectF(bx, y-S(46), mw, S(46))
        txtC(m.name, bx+mw/2, y-S(23), S(15), sel and DGREEN or color(200,205,215))
        table.insert(buttons, {id="mode_"..i, x=bx, y=y-S(46), w=mw, h=S(46)})
    end
    y = y - S(46) - S(14)
    txtL(modeDefs[modeIndex].desc, panelX + S(20), y, S(12), MUTED)
    y = y - S(34)

    txtL("DIFFICULTY", panelX + S(20), y, S(14), MUTED)
    y = y - S(38)
    local dw = (panelW - S(56) - S(32))/3
    for i, d in ipairs(difficultyDefs) do
        local bx = panelX + S(20) + (i-1)*(dw+S(16))
        local sel = (i == difficultyIndex)
        fc(sel and color(255,160,60) or BTN)
        rectF(bx, y-S(46), dw, S(46))
        txtC(d.name, bx+dw/2, y-S(23), S(14), sel and color(35,20,0) or color(200,205,215))
        table.insert(buttons, {id="diff_"..i, x=bx, y=y-S(46), w=dw, h=S(46)})
    end
    y = y - S(46) - S(20)

    drawButton("beginBtn", "BEGIN RUN", panelX + (panelW-S(240))/2, y-S(60), S(240), S(60), GREEN, DGREEN)
    y = y - S(60) - S(14)
    drawButton("backModeBtn", "BACK", panelX + (panelW-S(200))/2, y-S(48), S(200), S(48), BTN, TXT)
end
