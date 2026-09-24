-- draw_world.lua
-- Drawing of the play field: grid, entities, effects, joystick.

function drawWorldShaken()
    love.graphics.push()
    if shakeAmount > 0 then
        love.graphics.translate((math.random()*2-1)*shakeAmount, (math.random()*2-1)*shakeAmount)
    end
    drawWorld()
    love.graphics.pop()
end

function drawGrid()
    local step = S(70)
    local bottom, top = arenaBounds()
    fc(255, 255, 255, 14)
    local x = 0
    while x <= WIDTH do lineF(x, bottom, x, top, 1); x = x + step end
    local y = bottom
    while y <= top do lineF(0, y, WIDTH, y, 1); y = y + step end
    fc(61, 220, 132, 50)
    rectL(2, bottom, WIDTH-4, top-bottom, 2)
end

function powerupColor(t)
    if t == "speed" then return color(120,220,255)
    elseif t == "damage" then return color(255,120,120)
    elseif t == "shield" then return color(255,255,255)
    elseif t == "health" then return color(255,90,120)
    else return color(255,207,77)
    end
end

function drawWorld()
    if not player then return end
    drawGrid()

    for _, p in ipairs(particles) do
        local a = math.max(0, p.life / p.maxLife)
        fc(p.col, 255*a)
        circF(p.x, p.y, S(6))
    end

    for _, p in ipairs(powerups) do
      if p.t == "health" then
        if p.life > 3 or math.floor(p.life * 6) % 2 == 0 then
            fc(255, 90, 120, 230)
            circF(p.x, p.y, p.r * 2.2)
            fc(255, 255, 255)
            rectF(p.x - p.r*0.7, p.y - p.r*0.2, p.r*1.4, p.r*0.4)
            rectF(p.x - p.r*0.2, p.y - p.r*0.7, p.r*0.4, p.r*1.4)
        end
      else
        fc(powerupColor(p.t), 220)
        love.graphics.push()
        love.graphics.translate(p.x, HEIGHT - p.y)
        love.graphics.rotate(math.rad(p.life * 50))
        love.graphics.rectangle("fill", -p.r, -p.r, p.r*2, p.r*2)
        love.graphics.pop()
      end
    end

    for _, z in ipairs(zombies) do
        fc(z.col)
        circF(z.x, z.y, z.r*2)
        fc(22, 29, 41)
        circF(z.x - z.r*0.32, z.y + z.r*0.1, z.r*0.32)
        circF(z.x + z.r*0.32, z.y + z.r*0.1, z.r*0.32)
        if z.t == "boss" then
            fc(255, 255, 255, 160)
            circL(z.x, z.y, z.r*2 + S(14), S(3))
        elseif z.t == "shooter" then
            fc(255, 255, 255, 200)
            circF(z.x, z.y + z.r + S(6), S(8))
        elseif z.t == "exploder" then
            fc(255, 140, 40, 60)
            circF(z.x, z.y, z.r*2 + S(16))
        elseif z.t == "shielded" and z.shield and z.shield > 0 then
            fc(90, 200, 220, 200)
            circL(z.x, z.y, z.r*2 + S(10), S(3))
        end
        if z.shield and z.maxShield and z.maxShield > 0 then
            local w = z.r*2
            fc(0, 0, 0, 140)
            rectF(z.x - w/2, z.y + z.r + S(14), w, S(5))
            fc(90, 200, 220)
            rectF(z.x - w/2, z.y + z.r + S(14), w * math.max(0, z.shield/z.maxShield), S(5))
        end
        if z.hp < z.maxHp then
            local w = z.r*2
            fc(0, 0, 0, 140)
            rectF(z.x - w/2, z.y + z.r + S(6), w, S(6))
            fc(255, 93, 93)
            rectF(z.x - w/2, z.y + z.r + S(6), w * math.max(0, z.hp/z.maxHp), S(6))
        end
    end

    for _, b in ipairs(bullets) do
        if b.kind == "laser" then
            love.graphics.push()
            love.graphics.translate(b.x, HEIGHT - b.y)
            love.graphics.rotate(-atan2(b.vy, b.vx))
            fc(120, 220, 255)
            love.graphics.rectangle("fill", -S(14), -S(2), S(28), S(4))
            love.graphics.pop()
        elseif b.kind == "grenade" then
            fc(255, 160, 60)
            circF(b.x, b.y, b.r*2)
        else
            fc(255, 229, 138)
            circF(b.x, b.y, b.r*2)
        end
    end

    fc(255, 120, 120)
    for _, b in ipairs(enemyBullets) do circF(b.x, b.y, b.r*2) end

    if player.weapon == "flamethrower" then drawFlameCone() end

    if relicEnabled.godmode or debugGod or shieldTimeLeft > 0 then
        fc(255, 255, 255, 120)
        circL(player.x, player.y, player.r*2 + S(18), S(3))
    end

    fc(player.col)
    circF(player.x, player.y, player.r*2)
    love.graphics.push()
    love.graphics.translate(player.x, HEIGHT - player.y)
    love.graphics.rotate(-player.facing)
    fc(6, 35, 15)
    love.graphics.rectangle("fill", 0, -S(3), S(18), S(6))
    love.graphics.pop()

    for _, c in ipairs(coinPops) do
        txtC(c.txt, c.x, c.y, S(18), c.col, 255*math.max(0, c.life))
    end

    if hitFlash > 0 then fc(255, 0, 0, 90*hitFlash); rectF(0, 0, WIDTH, HEIGHT) end
    if levelFlash > 0 then fc(255, 255, 255, 140*levelFlash); rectF(0, 0, WIDTH, HEIGHT) end

    if waveBannerAlpha > 0 then
        txtC(waveBannerText, WIDTH/2, HEIGHT - S(120), S(24), WHITE, 255*waveBannerAlpha)
    end

    if combo >= 3 then
        local pct = math.floor((comboMultFor()-1)*100 + 0.5)
        txtC(combo .. "x combo! (+" .. pct .. "%)", WIDTH/2, HEIGHT - S(150), S(20), GOLD)
    end
end

function drawFlameCone()
    local s = baseStats()
    local range = S(150)
    local halfAngle = 0.45 + (s.multishot - 1) * 0.10
    local ang = player.facing
    local segments = 12
    fc(255, 140, 60, 45)
    for i = 0, segments - 1 do
        local a = ang - halfAngle + (i/segments) * halfAngle * 2
        love.graphics.push()
        love.graphics.translate(player.x, HEIGHT - player.y)
        love.graphics.rotate(-a)
        love.graphics.rectangle("fill", 0, -S(4), range, S(8))
        love.graphics.pop()
    end
end

function drawJoystick()
    if not joyBaseX then return end
    fc(255, 255, 255, 90)
    circL(joyBaseX, joyBaseY, S(140), S(3))
    fc(255, 255, 255, 140)
    circF(joyThumbX, joyThumbY, S(60))
end
