-- menus.lua
-- Top-level menu screens: start screen and run setup (mode / difficulty).

function drawStartScreen()
    -- everything is laid out inside the safe area, so it fits phones and desktops alike
    local cx = (SAFE.l + (WIDTH - SAFE.r)) / 2
    local topY = HEIGHT - SAFE.t

    txtC("ZOMBIE SIEGE", cx, topY - S(62), S(38), TXT)
    txtC(isTouchDevice() and "Drag to move. Auto-fires at the nearest zombie."
                          or "Drag / WASD to move. Auto-fires at the nearest zombie.",
         cx, topY - S(90), S(13), MUTED)
    local mm = math.floor(bestSurvivalTime/60)
    local ss = math.floor(bestSurvivalTime % 60)
    txtC("gems " .. gems .. "    best wave " .. bestWave .. "    best horde " .. string.format("%d:%02d", mm, ss),
         cx, topY - S(114), S(15), CYAN)
    local achCount = 0
    for _, d in ipairs(achievementDefs) do if achieved[d.id] then achCount = achCount + 1 end end
    local relicCount = 0
    for _, d in ipairs(relicDefs) do if relicUnlocked[d.key] then relicCount = relicCount + 1 end end
    txtC("achievements " .. achCount .. "/" .. #achievementDefs .. "    relics " .. relicCount .. "/" .. #relicDefs,
         cx, topY - S(134), S(12), GOLD)
    txtL("v" .. VERSION, WIDTH - SAFE.r - S(120), SAFE.b + S(8), S(12), MUTED)

    -- listed bottom-to-top (START sits lowest, within thumb reach); h = height weight
    local items = {
        {id="startBtn",    label="START GAME",         h=1.35, bg=GREEN,              fg=DGREEN},
        {id="weaponBtn",   label="WEAPONS",            h=1.0,  bg=color(255,160,60),  fg=color(35,20,0)},
        {id="skinBtn",     label="SKINS",              h=1.0,  bg=color(80,160,255),  fg=color(10,25,45)},
        {id="relicBtn",    label="RELICS",             h=1.0,  bg=color(160,90,255),  fg=color(30,10,45)},
        {id="metaBtn",     label="PERMANENT UPGRADES", h=1.0,  bg=color(120,109,241), fg=color(240,235,255)},
        {id="statsBtn",    label="STATS",              h=0.9,  bg=color(90,200,220),  fg=color(8,30,35)},
        {id="settingsBtn", label="SETTINGS",           h=0.9,  bg=BTN,                fg=TXT},
    }

    -- fit the stack into the space between the header and the bottom edge,
    -- as tall as fits (capped), centred in that space
    local areaBottom = S(20) + SAFE.b
    local availH = HEIGHT - (S(150) + SAFE.t) - areaBottom
    local gap = S(12)
    local sumW = 0
    for _, it in ipairs(items) do sumW = sumW + it.h end
    local unit = math.min((availH - gap * (#items - 1)) / sumW, S(72))
    local blockH = sumW * unit + gap * (#items - 1)

    local bw = math.min(WIDTH - SAFE.l - SAFE.r - S(40), S(520))
    local bx = cx - bw / 2
    local y = areaBottom + (availH - blockH) / 2
    for _, it in ipairs(items) do
        local h = it.h * unit
        drawButton(it.id, it.label, bx, y, bw, h, it.bg, it.fg, math.min(h * 0.4, S(30)))
        y = y + h + gap
    end
end

function drawModeSelect()
    fc(6, 9, 14, 200); rectF(0, 0, WIDTH, HEIGHT)
    local panelW = math.min(WIDTH - S(80), S(560))
    local panelX = (WIDTH - panelW)/2
    local panelH = math.min(HEIGHT - S(40), S(490))
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

    -- starting weapon: tap opens the weapon picker, then returns here
    local weapDef = weaponDefByKey(startWeapon)
    fc(BTN)
    rectF(panelX + S(20), y-S(50), panelW - S(40), S(50))
    txtL("STARTING WEAPON", panelX + S(34), y-S(20), S(11), MUTED)
    txtC(weapDef.name, panelX + panelW/2 + S(40), y-S(33), S(16), TXT)
    txtC(">", panelX + panelW - S(44), y-S(25), S(20), GOLD)
    table.insert(buttons, {id="openWeaponPicker", x=panelX+S(20), y=y-S(50), w=panelW-S(40), h=S(50)})
    y = y - S(50) - S(16)

    drawButton("beginBtn", "BEGIN RUN", panelX + (panelW-S(240))/2, y-S(60), S(240), S(60), GREEN, DGREEN)
    y = y - S(60) - S(14)
    drawButton("backModeBtn", "BACK", panelX + (panelW-S(200))/2, y-S(48), S(200), S(48), BTN, TXT)
end
