--!nonstrict
-- Editorial Chronometer Plate (FIG. 01 // CHRONO).
-- Pairs an orbital compass analog dial (echoing the geometric halos in the wallpaper
-- plates) with serif time typography and tracked monospace date indexing.

local shapes = require("./shapes.luau")

local W = 316
local H = 106

local lastKey = ""
local lastSvgPath: string? = nil

local function buildChronoSvg(
  hour: number,
  minute: number,
  dateLine: string,
  tzTag: string,
  cBg: string,
  cBorder: string,
  cOnSurface: string,
  cMuted: string,
  cPrimary: string,
  cSecondary: string
): string
  local cx, cy = 56, 53
  local rOuter = 36
  local rInner = 26

  local hourAngle = ((hour % 12) + minute / 60) * 30
  local minAngle = minute * 6
  local hRad = math.rad(hourAngle - 90)
  local mRad = math.rad(minAngle - 90)

  local hx = cx + 20 * math.cos(hRad)
  local hy = cy + 20 * math.sin(hRad)
  local mx = cx + 29 * math.cos(mRad)
  local my = cy + 29 * math.sin(mRad)
  local hBackX = cx - 5 * math.cos(hRad)
  local hBackY = cy - 5 * math.sin(hRad)
  local mBackX = cx - 6 * math.cos(mRad)
  local mBackY = cy - 6 * math.sin(mRad)

  local ticks = {}
  for i = 0, 11 do
    local rad = math.rad(i * 30 - 90)
    local isCardinal = (i % 3 == 0)
    local r0 = if isCardinal then rOuter - 6.5 else rOuter - 3.5
    local r1 = rOuter - 0.5
    local x0 = cx + r0 * math.cos(rad)
    local y0 = cy + r0 * math.sin(rad)
    local x1 = cx + r1 * math.cos(rad)
    local y1 = cy + r1 * math.sin(rad)
    table.insert(
      ticks,
      string.format(
        '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-opacity="%.2f" stroke-width="%.1f"/>',
        x0,
        y0,
        x1,
        y1,
        if isCardinal then cPrimary else cOnSurface,
        if isCardinal then 0.90 else 0.35,
        if isCardinal then 1.4 else 0.9
      )
    )
  end

  local timeText = string.format("%02d:%02d", hour, minute)

  return table.concat({
    string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', W, H, W, H),
    shapes.plateFrameSvg(W, H, cBg, cBorder, cPrimary, cOnSurface),

    -- Subtle vertical hairline separating dial and typography
    string.format(
      '<line x1="108" y1="14" x2="108" y2="%d" stroke="%s" stroke-opacity="0.35" stroke-width="0.9"/>',
      H - 14,
      cBorder
    ),

    -- Orbital compass dial (left)
    string.format(
      '<g stroke="%s" stroke-opacity="0.16" stroke-width="0.75">'
        .. '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
        .. '<line x1="%d" y1="%d" x2="%d" y2="%d"/>'
        .. "</g>",
      cOnSurface,
      cx - rOuter - 5,
      cy,
      cx + rOuter + 5,
      cy,
      cx,
      cy - rOuter - 5,
      cx,
      cy + rOuter + 5
    ),
    string.format(
      '<circle cx="%d" cy="%d" r="%d" fill="none" stroke="%s" stroke-opacity="0.62" stroke-width="1.1"/>',
      cx,
      cy,
      rOuter,
      cPrimary
    ),
    string.format(
      '<circle cx="%d" cy="%d" r="%d" fill="none" stroke="%s" stroke-opacity="0.28" stroke-width="0.8" stroke-dasharray="2.5 3.5"/>',
      cx,
      cy,
      rInner,
      cSecondary
    ),
    table.concat(ticks),
    -- Minute needle
    string.format(
      '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-opacity="0.92" stroke-width="1.7" stroke-linecap="round"/>',
      mBackX,
      mBackY,
      mx,
      my,
      cOnSurface
    ),
    -- Hour needle
    string.format(
      '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="2.7" stroke-linecap="round"/>',
      hBackX,
      hBackY,
      hx,
      hy,
      cPrimary
    ),
    -- Center jewel node
    string.format('<circle cx="%d" cy="%d" r="3.4" fill="%s" stroke="%s" stroke-width="1.5"/>', cx, cy, cBg, cPrimary),
    string.format('<circle cx="%d" cy="%d" r="1.2" fill="%s"/>', cx, cy, cOnSurface),

    -- Right side: specimen header + serif time + date spec (aligned to 22px header / 29px rule)
    string.format(
      '<text x="122" y="22" fill="%s" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" font-weight="700" letter-spacing="1.2">FIG. 01</text>',
      cPrimary
    ),
    string.format(
      '<text x="173" y="22" fill="%s" fill-opacity="0.76" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" letter-spacing="1.1">// CHRONO</text>',
      cMuted
    ),
    string.format(
      '<text x="%d" y="22" text-anchor="end" fill="%s" fill-opacity="0.65" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9" letter-spacing="0.8">%s</text>',
      W - 14,
      cMuted,
      tzTag
    ),
    string.format(
      '<line x1="122" y1="29" x2="%d" y2="29" stroke="%s" stroke-opacity="0.38" stroke-width="0.85"/>',
      W - 14,
      cBorder
    ),
    -- Oversized crisp editorial serif time
    string.format(
      '<text x="121" y="72" fill="%s" font-family="Liberation Serif, DejaVu Serif, serif" font-size="42" font-weight="700" letter-spacing="1.8">%s</text>',
      cOnSurface,
      timeText
    ),
    -- Bottom tracked date specification
    string.format(
      '<text x="122" y="92" fill="%s" fill-opacity="0.85" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="10" font-weight="500" letter-spacing="1.3">%s</text>',
      cSecondary,
      dateLine
    ),

    "</svg>",
  })
end

local function render()
  local now = os.time()
  local t = os.date("*t", now)
  local dateLine = string.upper(os.date("%a · %d %b %Y", now))
  local tzTag = os.date("%Z", now)

  local cBg = shapes.color("surface", "#101116")
  local cBorder = shapes.color("outline_variant", "#49454f")
  local cOnSurface = shapes.color("on_surface", "#eae4dc")
  local cMuted = shapes.color("on_surface_variant", "#c4beb5")
  local cPrimary = shapes.color("primary", "#f2be6e")
  local cSecondary = shapes.color("secondary", "#dcc3a1")

  local key = table.concat({
    tostring(t.hour),
    tostring(t.min),
    dateLine,
    cBg,
    cBorder,
    cOnSurface,
    cMuted,
    cPrimary,
    cSecondary,
  }, "|")

  if key == lastKey and lastSvgPath and noctalia.fileExists(lastSvgPath) then
    return
  end

  local svg = buildChronoSvg(t.hour, t.min, dateLine, tzTag, cBg, cBorder, cOnSurface, cMuted, cPrimary, cSecondary)
  local path = shapes.writeVersionedSvg("editorial_chrono", lastSvgPath, svg)
  if not path then
    return
  end
  lastSvgPath = path
  lastKey = key

  desktopWidget.render(ui.column({ align = "center", justify = "center" }, {
    ui.image({
      path = path,
      width = W,
      height = H,
      fit = "contain",
    }),
  }))
end

function update()
  noctalia.setUpdateInterval(5000)
  render()
end

render()
