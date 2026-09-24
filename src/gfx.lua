-- gfx.lua
-- Compat + drawing helpers. Game logic keeps Codea's coordinate system
-- (origin bottom-left, y up); every draw helper here flips y for LÖVE.

atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
WIDTH, HEIGHT = 1024, 768

function color(r, g, b, a) return {r = r, g = g, b = b, a = a or 255} end

-- set draw color: fc(colorTable [,alpha]) or fc(r,g,b [,a])   (0-255)
function fc(r, g, b, a)
    if type(r) == "table" then
        love.graphics.setColor(r.r / 255, r.g / 255, r.b / 255, (g or r.a or 255) / 255)
    else
        love.graphics.setColor(r / 255, g / 255, b / 255, (a or 255) / 255)
    end
end

function SC()
    local m = math.min(WIDTH, HEIGHT)
    local s = m / 768
    if s < 0.55 then s = 0.55 end
    if s > 1.5 then s = 1.5 end
    return s
end
function S(v) return v * SC() end

function randInt(a, b)
    a = math.floor(a); b = math.floor(b)
    if b < a then a, b = b, a end
    return math.random(a, b)
end

function rectF(x, y, w, h) love.graphics.rectangle("fill", x, HEIGHT - y - h, w, h) end
function rectL(x, y, w, h, lw)
    love.graphics.setLineWidth(lw or 1)
    love.graphics.rectangle("line", x, HEIGHT - y - h, w, h)
end
function circF(x, y, d) love.graphics.circle("fill", x, HEIGHT - y, d / 2) end
function circL(x, y, d, lw)
    love.graphics.setLineWidth(lw or 1)
    love.graphics.circle("line", x, HEIGHT - y, d / 2)
end
function lineF(x1, y1, x2, y2, lw)
    love.graphics.setLineWidth(lw or 1)
    love.graphics.line(x1, HEIGHT - y1, x2, HEIGHT - y2)
end

local fonts = {}
local function getFont(size)
    size = math.max(6, math.floor(size + 0.5))
    local f = fonts[size]
    if not f then f = love.graphics.newFont(size); fonts[size] = f end
    return f
end
-- centered on (x,y)
function txtC(str, x, y, size, c, a)
    local f = getFont(size)
    love.graphics.setFont(f)
    if c then fc(c, a) end
    str = tostring(str)
    love.graphics.print(str, math.floor(x - f:getWidth(str) / 2), math.floor(HEIGHT - y - f:getHeight() / 2))
end
-- bottom-left at (x,y)  (Codea CORNER mode)
function txtL(str, x, y, size, c, a)
    local f = getFont(size)
    love.graphics.setFont(f)
    if c then fc(c, a) end
    love.graphics.print(tostring(str), math.floor(x), math.floor(HEIGHT - y - f:getHeight()))
end

-- palette (globals so every UI module can use them)
TXT    = color(232, 237, 245)
MUTED  = color(139, 150, 168)
GOLD   = color(255, 207, 77)
CYAN   = color(120, 220, 255)
WHITE  = color(255, 255, 255)
PANEL  = color(22, 29, 41)
ROW    = color(19, 26, 36)
BTN    = color(35, 44, 61)
GREEN  = color(61, 220, 132)
DGREEN = color(6, 35, 15)
BUYON  = color(31, 122, 76)
BUYOFF = color(42, 49, 64)

-- ---------- safe area (notches, rounded corners, system bars) ----------
-- Insets in pixels, measured inward from each screen edge. All zero on desktop.
SAFE = {l = 0, r = 0, t = 0, b = 0}

function updateSafeArea()
    SAFE.l, SAFE.r, SAFE.t, SAFE.b = 0, 0, 0, 0
    if not love.window.getSafeArea then return end
    local ok, x, y, w, h = pcall(love.window.getSafeArea)
    if not ok or not w or w <= 0 or h <= 0 then return end
    local sc = (love.window.getDPIScale and love.window.getDPIScale()) or 1
    x, y, w, h = x * sc, y * sc, w * sc, h * sc
    -- clamp so a bad value from the platform can never wreck the layout
    SAFE.l = math.min(math.max(0, x), WIDTH * 0.25)
    SAFE.t = math.min(math.max(0, y), HEIGHT * 0.25)
    SAFE.r = math.min(math.max(0, WIDTH - (x + w)), WIDTH * 0.25)
    SAFE.b = math.min(math.max(0, HEIGHT - (y + h)), HEIGHT * 0.25)
end

function isTouchDevice()
    local os_ = love.system.getOS()
    return os_ == "Android" or os_ == "iOS"
end
