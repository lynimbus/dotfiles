--!nonstrict
-- Shared Material 3 Expressive scalloped polygon SVG helpers and cache-safe file writer.

local M = {}

function M.color(role: string, fallback: string): string
  return noctalia.getColor(role) or fallback
end

-- Generates an SVG path for an N-sided Material 3 Expressive "Cookie" scalloped shape:
--   r(theta) = radius * (1 + amplitude * cos(lobes * theta))
function M.cookiePath(cx: number, cy: number, radius: number, lobes: number, amplitude: number, steps: number?): string
  local n = steps or 144
  local parts = table.create(n + 1)
  local twoPi = math.pi * 2
  for i = 0, n - 1 do
    local theta = (i / n) * twoPi
    local r = radius * (1 + amplitude * math.cos(lobes * theta))
    local x = cx + r * math.cos(theta)
    local y = cy + r * math.sin(theta)
    local prefix = if i == 0 then "M" else "L"
    parts[i + 1] = string.format("%s%.2f %.2f", prefix, x, y)
  end
  parts[n + 1] = "Z"
  return table.concat(parts, " ")
end

-- Simple deterministic 32-bit FNV-1a hex hash for cache-busting SVG filenames when
-- theme colors or time change, avoiding stale image texture caches.
function M.hash(input: string): string
  local h = 2166136261
  for i = 1, #input do
    h = bit32.bxor(h, string.byte(input, i))
    h = (h * 16777619) % 4294967296
  end
  return string.format("%08x", h)
end

function M.writeVersionedSvg(prefix: string, prevPath: string?, svg: string): string?
  local dir = noctalia.pluginDataDir()
  if not dir or dir == "" then
    return nil
  end
  noctalia.mkdirAll(dir)
  local nextPath = string.format("%s/%s_%s.svg", dir, prefix, M.hash(svg))
  if prevPath == nextPath and noctalia.fileExists(nextPath) then
    return nextPath
  end
  local ok = noctalia.writeFile(nextPath, svg)
  if not ok then
    return prevPath
  end
  if prevPath and prevPath ~= nextPath then
    noctalia.removeFile(prevPath)
  end
  return nextPath
end

return M
