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
    elseif t == "freeze" then return color(180,240,255)
    elseif t == "magnet" then return color(255,90,200)
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
      elseif p.t == "nuke" then
        -- rare pickup: an unmissable pulsing hazard marker instead of the usual spinning square
        local pulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 6)
        fc(210, 255, 60, 90)
        circF(p.x, p.y, p.r * 3.2 * pulse)
        fc(30, 30, 20, 230)
        circF(p.x, p.y, p.r * 2.2)
        love.graphics.push()
        love.graphics.translate(p.x, HEIGHT - p.y)
        love.graphics.rotate(love.timer.getTime() * 1.5)
        fc(210, 255, 60)
        for k = 0, 2 do
            love.graphics.rotate(math.pi * 2 / 3)
            love.graphics.rectangle("fill", -p.r*0.18, p.r*0.15, p.r*0.36, p.r*0.95)
        end
        love.graphics.pop()
      else
        fc(powerupColor(p.t), 220)
        love.graphics.push()
        love.graphics.translate(p.x, HEIGHT - p.y)
        love.graphics.rotate(math.rad(p.life * 50))
        love.graphics.rectangle("fill", -p.r, -p.r, p.r*2, p.r*2)
        love.graphics.pop()
      end
    end

    for _, m in ipairs(mines) do
        fc(58, 64, 78)
        circF(m.x, m.y, m.r * 2.4)
        if m.arm > 0 then
            fc(255, 207, 77)                                   -- arming
        elseif math.floor(love.timer.getTime() * 4) % 2 == 0 then
            fc(255, 80, 80)                                    -- armed, blinking
        else
            fc(120, 30, 30)
        end
        circF(m.x, m.y, m.r * 0.9)
    end

    for _, z in ipairs(zombies) do
        fc(z.col)
        circF(z.x, z.y, z.r*2)
        if freezeTimeLeft > 0 then
            fc(180, 240, 255, 110)
            circF(z.x, z.y, z.r*2)
        end
        fc(22, 29, 41)
        circF(z.x - z.r*0.32, z.y + z.r*0.1, z.r*0.32)
        circF(z.x + z.r*0.32, z.y + z.r*0.1, z.r*0.32)
        if isBossType(z.t) then
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
        if z.charge and z.chargeState == "telegraph" then
            -- flickers faster as the dash gets closer, so the warning reads as urgent
            local flicker = 0.35 + 0.45 * math.abs(math.sin(love.timer.getTime() * 14))
            local dashDist = z.dashSpeed * z.dashDuration
            fc(255, 70, 70, 255 * flicker)
            lineF(z.x, z.y, z.x + z.dashDX * dashDist, z.y + z.dashDY * dashDist, S(4))
            fc(255, 70, 70, 90)
            circL(z.x, z.y, z.r*2 + S(10), S(2))
        elseif z.chargeState == "dash" then
            fc(255, 255, 255, 130)
            circL(z.x, z.y, z.r*2 + S(8), S(3))
        end
        if z.t == "necromancer" and z.healPulse and z.healPulse > 0 then
            local t = z.healPulse / 0.35              -- 1 at cast, fading to 0
            fc(160, 70, 200, 200 * t)
            circL(z.x, z.y, z.healRadius * 2 * (1 - t), S(3))
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
        elseif b.kind == "bolt" then
            love.graphics.push()
            love.graphics.translate(b.x, HEIGHT - b.y)
            love.graphics.rotate(-atan2(b.vy, b.vx))
            fc(190, 150, 100)
            love.graphics.rectangle("fill", -S(18), -S(2.5), S(36), S(5))
            fc(235, 235, 240)
            love.graphics.rectangle("fill", S(12), -S(4), S(8), S(8))
            love.graphics.pop()
        elseif b.kind == "boomerang" then
            love.graphics.push()
            love.graphics.translate(b.x, HEIGHT - b.y)
            love.graphics.rotate(-b.spin)
            fc(240, 200, 120)
            love.graphics.rectangle("fill", -S(13), -S(3.5), S(26), S(7))
            love.graphics.rectangle("fill", -S(3.5), -S(13), S(7), S(26))
            love.graphics.pop()
        else
            fc(255, 229, 138)
            circF(b.x, b.y, b.r*2)
        end
    end

    fc(255, 120, 120)
    for _, b in ipairs(enemyBullets) do circF(b.x, b.y, b.r*2) end

    if player.weapon == "flamethrower" then drawFlameCone() end
    drawArcs()
    if player.weapon == "blades" then drawBlades() end

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

-- jagged lightning between points; flickers because the jitter is re-rolled each frame
function drawArcs()
    for _, a in ipairs(arcs) do
        local alpha = 255 * math.max(0, a.life / 0.18)
        for i = 1, #a.pts - 1 do
            local p, q = a.pts[i], a.pts[i + 1]
            local dx, dy = q.x - p.x, q.y - p.y
            local len = math.sqrt(dx*dx + dy*dy)
            if len > 1 then
                local nx, ny = -dy / len, dx / len
                local segs = math.max(2, math.floor(len / S(30)))
                local px, py = p.x, p.y
                fc(190, 230, 255, alpha)
                for k = 1, segs do
                    local t = k / segs
                    local qx, qy = p.x + dx * t, p.y + dy * t
                    if k < segs then
                        local j = (math.random() * 2 - 1) * S(10)
                        qx, qy = qx + nx * j, qy + ny * j
                    end
                    lineF(px, py, qx, qy, S(3))
                    px, py = qx, qy
                end
            end
        end
    end
end

function drawBlades()
    local s = baseStats()
    fc(255, 255, 255, 22)
    circL(player.x, player.y, S(78) * 2, 1)
    for _, p in ipairs(bladePositions(s)) do
        love.graphics.push()
        love.graphics.translate(p.x, HEIGHT - p.y)
        love.graphics.rotate(-(p.a + math.pi / 2))
        fc(120, 220, 255, 120)
        love.graphics.rectangle("fill", -S(17), -S(6), S(34), S(12))
        fc(235, 240, 250)
        love.graphics.rectangle("fill", -S(14), -S(3.5), S(28), S(7))
        love.graphics.pop()
    end
end
