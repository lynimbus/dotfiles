--!nonstrict
-- Editorial Telemetry Plate (FIG. 03 // TELEMETRY).
-- Directly echoes the FIG. 03 spectrum bar charts in both wallpapers: displays
-- CPU, RAM, and Disk percentages in editorial serif paired with live vertical
-- micro-bar spectra tinted from the active Noctalia M3 palette.

local shapes = require("./shapes.luau")

local W = 316
local H = 116
local HISTORY_LEN = 12

local cpuHist: { number } = {}
local ramHist: { number } = {}
for i = 1, HISTORY_LEN do
  cpuHist[i] = 0
  ramHist[i] = 0
end

local lastKey = ""
local lastSvgPath: string? = nil

local function pushSample(buf: { number }, val: number)
  for i = 1, HISTORY_LEN - 1 do
    buf[i] = buf[i + 1]
  end
  buf[HISTORY_LEN] = math.max(0, math.min(100, val))
end

local function buildSpectrumBars(
  x0: number,
  yBottom: number,
  maxH: number,
  values: { number },
  cActive: string,
  cMuted: string
): string
  local parts = {}
  local count = #values
  local step = 7.0
  local barW = 3.2
  for i = 1, count do
    local pct = values[i]
    local bh = math.max(2.0, (pct / 100.0) * maxH)
    local x = x0 + (i - 1) * step
    local y = yBottom - bh
    local isLatest = (i == count)
    table.insert(
      parts,
      string.format(
        '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f"/>',
        x,
        y,
        barW,
        bh,
        if isLatest then cActive else cMuted,
        if isLatest then 0.95 else 0.50 + 0.35 * (i / count)
      )
    )
  end
  -- Baseline rule
  table.insert(
    parts,
    string.format(
      '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-opacity="0.35" stroke-width="0.8"/>',
      x0,
      yBottom + 0.5,
      x0 + (count - 1) * step + barW,
      yBottom + 0.5,
      cMuted
    )
  )
  return table.concat(parts)
end

local function buildDiskMeter(
  x0: number,
  yBottom: number,
  maxH: number,
  diskPct: number,
  cActive: string,
  cBorder: string
): string
  -- 12 stepped bars representing static storage allocation profile
  local parts = {}
  local count = 12
  local step = 7.0
  local barW = 3.2
  local filledCount = math.max(1, math.floor((diskPct / 100.0) * count + 0.5))
  for i = 1, count do
    local filled = (i <= filledCount)
    local bh = if filled then (5.5 + (i / count) * (maxH - 5.5)) else 3.0
    local x = x0 + (i - 1) * step
    local y = yBottom - bh
    table.insert(
      parts,
      string.format(
        '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f"/>',
        x,
        y,
        barW,
        bh,
        if filled then cActive else cBorder,
        if filled then 0.85 else 0.35
      )
    )
  end
  table.insert(
    parts,
    string.format(
      '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-opacity="0.35" stroke-width="0.8"/>',
      x0,
      yBottom + 0.5,
      x0 + (count - 1) * step + barW,
      yBottom + 0.5,
      cBorder
    )
  )
  return table.concat(parts)
end

local function buildTelemetrySvg(
  cpuPct: number,
  ramPct: number,
  diskPct: number,
  cBg: string,
  cBorder: string,
  cOnSurface: string,
  cMuted: string,
  cPrimary: string,
  cSecondary: string,
  cTertiary: string
): string
  local colX = { 14, 114, 214 }
  local yBarBottom = 102
  local maxBarH = 24

  return table.concat({
    string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', W, H, W, H),
    shapes.plateFrameSvg(W, H, cBg, cBorder, cPrimary, cOnSurface),

    -- Header bar
    string.format(
      '<text x="14" y="22" fill="%s" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" font-weight="700" letter-spacing="1.2">FIG. 03</text>',
      cPrimary
    ),
    string.format(
      '<text x="65" y="22" fill="%s" fill-opacity="0.78" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" letter-spacing="1.1">// TELEMETRY</text>',
      cMuted
    ),
    string.format('<circle cx="%d" cy="18.5" r="2.5" fill="%s"/>', W - 52, cPrimary),
    string.format(
      '<text x="%d" y="22" text-anchor="end" fill="%s" fill-opacity="0.7" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9" letter-spacing="0.9">LIVE</text>',
      W - 14,
      cMuted
    ),
    string.format(
      '<line x1="14" y1="29" x2="%d" y2="29" stroke="%s" stroke-opacity="0.38" stroke-width="0.85"/>',
      W - 14,
      cBorder
    ),

    -- Subtle column separators
    string.format(
      '<g stroke="%s" stroke-opacity="0.28" stroke-width="0.8">'
        .. '<line x1="104" y1="36" x2="104" y2="104"/>'
        .. '<line x1="204" y1="36" x2="204" y2="104"/>'
        .. "</g>",
      cBorder
    ),

    -- Column 1: CPU
    string.format(
      '<text x="%d" y="45" fill="%s" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" font-weight="600" letter-spacing="1.2">CPU</text>',
      colX[1],
      cPrimary
    ),
    string.format(
      '<text x="%d" y="69" fill="%s" font-family="Liberation Serif, DejaVu Serif, serif" font-size="24" font-weight="700">%d<tspan font-size="13" fill="%s">%%</tspan></text>',
      colX[1],
      cOnSurface,
      cpuPct,
      cMuted
    ),
    buildSpectrumBars(colX[1], yBarBottom, maxBarH, cpuHist, cPrimary, cPrimary),

    -- Column 2: RAM
    string.format(
      '<text x="%d" y="45" fill="%s" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" font-weight="600" letter-spacing="1.2">RAM</text>',
      colX[2],
      cSecondary
    ),
    string.format(
      '<text x="%d" y="69" fill="%s" font-family="Liberation Serif, DejaVu Serif, serif" font-size="24" font-weight="700">%d<tspan font-size="13" fill="%s">%%</tspan></text>',
      colX[2],
      cOnSurface,
      ramPct,
      cMuted
    ),
    buildSpectrumBars(colX[2], yBarBottom, maxBarH, ramHist, cSecondary, cSecondary),

    -- Column 3: DISK
    string.format(
      '<text x="%d" y="45" fill="%s" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" font-weight="600" letter-spacing="1.2">DISK</text>',
      colX[3],
      cTertiary
    ),
    string.format(
      '<text x="%d" y="69" fill="%s" font-family="Liberation Serif, DejaVu Serif, serif" font-size="24" font-weight="700">%d<tspan font-size="13" fill="%s">%%</tspan></text>',
      colX[3],
      cOnSurface,
      diskPct,
      cMuted
    ),
    buildDiskMeter(colX[3], yBarBottom, maxBarH, diskPct, cTertiary, cBorder),

    "</svg>",
  })
end

local function render()
  local stats = noctalia.systemStats()
  local cpuPct = 0
  local ramPct = 0
  if stats then
    cpuPct = math.floor((stats.cpu.usagePercent or 0) + 0.5)
    ramPct = math.floor((stats.ram.usagePercent or 0) + 0.5)
  end

  local disk = noctalia.diskStats("/")
  local diskPct = 0
  if disk then
    diskPct = math.floor((disk.usagePercent or 0) + 0.5)
  end

  pushSample(cpuHist, cpuPct)
  pushSample(ramHist, ramPct)

  local cBg = shapes.color("surface", "#101116")
  local cBorder = shapes.color("outline_variant", "#49454f")
  local cOnSurface = shapes.color("on_surface", "#eae4dc")
  local cMuted = shapes.color("on_surface_variant", "#c4beb5")
  local cPrimary = shapes.color("primary", "#f2be6e")
  local cSecondary = shapes.color("secondary", "#dcc3a1")
  local cTertiary = shapes.color("tertiary", "#b6cea3")

  local histParts = {}
  for i = 1, HISTORY_LEN do
    histParts[i] = tostring(cpuHist[i]) .. ":" .. tostring(ramHist[i])
  end
  local key = table.concat({
    tostring(cpuPct),
    tostring(ramPct),
    tostring(diskPct),
    table.concat(histParts, ","),
    cBg,
    cBorder,
    cOnSurface,
    cPrimary,
    cSecondary,
    cTertiary,
  }, "|")

  if key == lastKey and lastSvgPath and noctalia.fileExists(lastSvgPath) then
    return
  end

  local svg = buildTelemetrySvg(
    cpuPct,
    ramPct,
    diskPct,
    cBg,
    cBorder,
    cOnSurface,
    cMuted,
    cPrimary,
    cSecondary,
    cTertiary
  )
  local path = shapes.writeVersionedSvg("editorial_telemetry", lastSvgPath, svg)
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
  noctalia.setUpdateInterval(2000)
  render()
end

render()
