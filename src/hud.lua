-- hud.lua
-- In-run HUD, the shared drawButton helper, and pause / game-over overlays.

-- size (optional) overrides the label font size
function drawButton(id, label, x, y, w, h, bgcol, txtcol, size)
    fc(bgcol)
    rectF(x, y, w, h)
    txtC(label, x + w/2, y + h/2, size or S(18), txtcol)
    table.insert(buttons, {id=id, x=x, y=y, w=w, h=h})
end

function drawHud()
    local pad = S(16)
    local chipH = S(40)
    local chipW = S(130)
    local gap = S(14)
    local left = SAFE.l + pad                    -- keep clear of notches / rounded corners
    local right = WIDTH - SAFE.r - pad
    local chipY = HEIGHT - SAFE.t - chipH - pad

    fc(22, 29, 41, 230)
    rectF(left, chipY, chipW, chipH)
    txtL("coins " .. coins, left + S(12), chipY + S(10), S(20), GOLD)
    txtL("gems " .. gems, left + S(12), chipY - S(16), S(13), CYAN)

    local buffParts = {}
    if buffSpeedTimeLeft > 0 then table.insert(buffParts, "SPD " .. math.ceil(buffSpeedTimeLeft) .. "s") end
    if buffDamageTimeLeft > 0 then table.insert(buffParts, "DMG " .. math.ceil(buffDamageTimeLeft) .. "s") end
    if shieldTimeLeft > 0 then table.insert(buffParts, "SHIELD " .. math.ceil(shieldTimeLeft) .. "s") end
    if #buffParts > 0 then
        txtL(table.concat(buffParts, "  "), left + S(12), chipY - S(32), S(11), WHITE)
    end

    fc(22, 29, 41, 230)
    rectF(right - chipW, chipY, chipW, chipH)
    if gameMode == "classic" then
        txtL("wave " .. wave, right - chipW + S(12), chipY + S(10), S(20), WHITE)
    else
        local mm = math.floor(survivalTime/60)
        local ss = math.floor(survivalTime % 60)
        txtL(string.format("%d:%02d", mm, ss), right - chipW + S(12), chipY + S(10), S(20), WHITE)
    end

    local barX = left + chipW + gap
    local barW = math.max(S(60), (right - chipW - gap) - barX)
    fc(22, 29, 41, 230)
    rectF(barX, chipY, barW, chipH)
    if player then
        local pct = math.max(0, player.hp / player.maxHp)
        fc(255, 93, 93)
        rectF(barX + S(4), chipY + S(4), (barW - S(8)) * pct, chipH - S(8))
        txtC(math.ceil(player.hp) .. " / " .. math.floor(player.maxHp + 0.5), barX + barW/2, chipY + chipH/2, S(16), WHITE)
    end

    local btnH = S(56)
    local shopW, weapW, pauseW = S(140), S(140), S(120)
    local btnGap = S(10)
    local totalW = shopW + btnGap + weapW + btnGap + pauseW
    local startX = WIDTH/2 - totalW/2
    local btnY = S(16) + SAFE.b
    drawButton("shopBtn", "SHOP", startX, btnY, shopW, btnH, GREEN, DGREEN)
    drawButton("cycleWeaponBtn", currentWeaponDef().short, startX + shopW + btnGap, btnY, weapW, btnH, color(120,109,241), color(240,235,255))
    drawButton("pauseBtn", state == "paused" and "RESUME" or "PAUSE", startX + shopW + btnGap + weapW + btnGap, btnY, pauseW, btnH, BTN, TXT)
end

function drawGameOverScreen()
    fc(6, 9, 14, 210); rectF(0, 0, WIDTH, HEIGHT)
    txtC("YOU FELL", WIDTH/2, HEIGHT/2 + S(110), S(40), color(255,93,93))
    if gameMode == "classic" then
        txtC("Wave " .. wave .. "    Kills " .. kills .. "    Coins " .. coins, WIDTH/2, HEIGHT/2 + S(72), S(17), TXT)
    else
        local mm = math.floor(survivalTime/60)
        local ss = math.floor(survivalTime % 60)
        txtC(string.format("Survived %d:%02d    Kills %d    Coins %d", mm, ss, kills, coins), WIDTH/2, HEIGHT/2 + S(72), S(17), TXT)
    end
    txtC("Gems banked: " .. gems, WIDTH/2, HEIGHT/2 + S(46), S(17), CYAN)
    drawButton("retryBtn", "PLAY AGAIN", WIDTH/2 - S(120), HEIGHT/2 - S(50), S(240), S(60), GREEN, DGREEN)
    drawButton("menuBtn", "MAIN MENU", WIDTH/2 - S(120), HEIGHT/2 - S(120), S(240), S(50), BTN, TXT)
end

function drawPauseOverlay()
    fc(6, 9, 14, 180); rectF(0, 0, WIDTH, HEIGHT)
    txtC("PAUSED", WIDTH/2, HEIGHT/2 + S(80), S(36), TXT)
    drawButton("resumeBtn2", "RESUME", WIDTH/2-S(120), HEIGHT/2-S(10), S(240), S(60), GREEN, DGREEN)
    drawButton("quitBtn", "QUIT TO MENU", WIDTH/2-S(120), HEIGHT/2-S(80), S(240), S(54), color(200,50,50), color(255,235,235))
end
