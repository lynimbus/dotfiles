--!nonstrict
-- Shared editorial monograph SVG helpers, registration marks, and cache-safe file writer.

local M = {}

function M.color(role: string, fallback: string): string
  return noctalia.getColor(role) or fallback
end

-- Minimalist architectural plate backdrop: translucent dark glass, subtle grid,
-- 1px hairline border, and four primary-accented corner registration ticks.
function M.plateFrameSvg(
  w: number,
  h: number,
  cBg: string,
  cBorder: string,
  cAccent: string,
  cGrid: string
): string
  local r = 6
  local tick = 7
  local parts = {
    -- Dark glass base
    string.format(
      '<rect x="0.5" y="0.5" width="%.1f" height="%.1f" rx="%d" fill="%s" fill-opacity="0.86" stroke="%s" stroke-opacity="0.55" stroke-width="1"/>',
      w - 1,
      h - 1,
      r,
      cBg,
      cBorder
    ),
    -- Faint mathematical grid inside plate
    '<g stroke="' .. cGrid .. '" stroke-opacity="0.06" stroke-width="0.75">',
  }
  for x = 24, w - 12, 24 do
    table.insert(parts, string.format('<line x1="%d" y1="1" x2="%d" y2="%d"/>', x, x, h - 1))
  end
  for y = 24, h - 12, 24 do
    table.insert(parts, string.format('<line x1="1" y1="%d" x2="%d" y2="%d"/>', y, w - 1, y))
  end
  table.insert(parts, "</g>")

  -- Four crisp corner registration marks
  table.insert(
    parts,
    string.format(
      '<g fill="none" stroke="%s" stroke-opacity="0.78" stroke-width="1.2" stroke-linecap="square">'
        .. '<path d="M1 %d V1 H%d"/>'
        .. '<path d="M%.1f 1 H%.1f V%d"/>'
        .. '<path d="M1 %.1f V%.1f H%d"/>'
        .. '<path d="M%.1f %.1f H%.1f V%.1f"/>'
        .. "</g>",
      cAccent,
      1 + tick,
      1 + tick,
      w - 1 - tick,
      w - 1,
      1 + tick,
      h - 1 - tick,
      h - 1,
      1 + tick,
      w - 1 - tick,
      h - 1,
      w - 1,
      h - 1 - tick
    )
  )

  return table.concat(parts)
end

-- Simple deterministic 32-bit FNV-1a hex hash for cache-busting SVG filenames when
-- theme colors or metrics change, avoiding stale image texture caches.
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
