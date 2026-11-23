--[[
    Inflate - small helper functions
]]

local mmin, mmax, msqrt = math.min, math.max, math.sqrt

function clamp(v, lo, hi)
    return mmax(lo, mmin(hi, v))
end

function lerp(a, b, t)
    return a + (b - a) * t
end

function sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
end

-- axis-aligned box vs box
function aabb(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

-- circle vs axis-aligned box
function circleRect(cx, cy, r, rx, ry, rw, rh)
    local nx = clamp(cx, rx, rx + rw)
    local ny = clamp(cy, ry, ry + rh)
    local dx, dy = cx - nx, cy - ny
    return dx * dx + dy * dy < r * r
end

function distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return msqrt(dx * dx + dy * dy)
end

-- O(1) removal for lists where order doesn't matter
function swapRemove(t, i)
    local n = #t
    t[i] = t[n]
    t[n] = nil
end
