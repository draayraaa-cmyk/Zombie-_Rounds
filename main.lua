if os.getenv("LOVE2D_TOOLS") then pcall(require, "_love2d_tools_bridge") end
-- Zombie Siege  (LÖVE 11.x port of the Codea version)
-- Game logic keeps Codea's coordinate system (origin bottom-left, y up).
-- All drawing/input goes through small helpers that flip y for LÖVE.
-- No image/audio assets: sounds are synthesized at startup.
--
-- Desktop extras: WASD / arrows to move, Tab = cycle weapon, B = shop,
-- Esc / P = pause, mouse wheel / drag scrolls long lists.
-- Debug: F1 overlay, F2-F9 cheats (see src/debug_tools.lua).
--
-- Layout (all modules share globals; load order only matters for top-level code):
--   src/gfx.lua          drawing helpers + palette
--   src/debug_tools.lua  DEBUG flag, cheat keys, overlay
--   src/save.lua         persistence, (de)serialization, persistMeta/resetProgress
--   src/audio.lua        procedural sounds
--   src/defs.lua         static definition tables (weapons, relics, achievements...)
--   src/stats.lua        levels/costs, baseStats, weapon helpers
--   src/progress.lua     achievement / relic unlock checks
--   src/state.lua        initState(): initial values for every global
--   src/game.lua         run lifecycle (newGame, startWave, endGame)
--   src/zombies.lua      zombie types, spawning, drops
--   src/combat.lua       weapons, damage, rewards, powerups
--   src/update.lua       per-frame simulation
--   src/draw_world.lua   arena / entity drawing
--   src/hud.lua          HUD, drawButton, pause + game-over overlays
--   src/menus.lua        start screen, run setup
--   src/panels.lua       shops, relics, settings
--   src/input.lua        button actions + mouse/touch/keyboard callbacks

VERSION = "1.0.2"

require("src.gfx")
require("src.debug_tools")
require("src.save")
require("src.audio")
require("src.defs")
require("src.stats")
require("src.progress")
require("src.state")
require("src.game")
require("src.zombies")
require("src.combat")
require("src.update")
require("src.draw_world")
require("src.hud")
require("src.menus")
require("src.panels")
require("src.input")

function love.load()
    love.graphics.setBackgroundColor(13 / 255, 17 / 255, 23 / 255)
    love.graphics.setLineStyle("smooth")
    WIDTH, HEIGHT = love.graphics.getDimensions()
    updateSafeArea()
    math.randomseed(os.time())
    loadSave()
    initSounds()
    initState()
end

function love.resize(w, h)
    WIDTH, HEIGHT = love.graphics.getDimensions()
    updateSafeArea()
end

function love.quit() persistMeta(); flushSave() end

function love.focus(f)
    if not f then
        if state == "playing" then state = "paused" end
        -- mobile OSes can kill a backgrounded app without calling love.quit,
        -- so save everything the moment focus is lost
        if state then persistMeta(); flushSave() end
    end
end

function love.update(dt)
    dt = math.min(dt, 1/20)
    if state ~= prevState then listScroll = 0; dragId = nil; prevState = state end
    update(dt)
    flushSave()
end

function love.draw()
    love.graphics.clear(13/255, 17/255, 23/255)
    buttons = {}

    if state == "start" then
        drawStartScreen()
    elseif state == "modeSelect" then
        drawModeSelect()
    elseif state == "metaShop" then
        drawMetaShop()
    elseif state == "weaponShop" then
        drawWeaponShop()
    elseif state == "skinShop" then
        drawSkinShop()
    elseif state == "relicMenu" then
        drawRelicMenu()
    elseif state == "settings" then
        drawSettings()
    elseif state == "gameover" then
        drawWorldShaken()
        drawHud()
        buttons = {}   -- HUD is only backdrop here; its buttons must not be clickable
        drawGameOverScreen()
    else
        drawWorldShaken()
        drawHud()
        if state == "playing" then drawJoystick() end
        if state == "shop" then drawShop() end
        if state == "paused" then drawPauseOverlay() end
    end

    if DEBUG and debugOverlay then drawDebug() end
end
