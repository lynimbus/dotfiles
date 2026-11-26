--!nonstrict
-- Editorial Ephemeris Plate (FIG. 02 // EPHEMERIS).
-- Unified SVG architectural plate matching FIG. 01 & FIG. 03: same 316x106 grid,
-- faint coordinate lines, primary corner registration ticks, ISO week index,
-- and crisp serif numerals with a highlighted active day square.

local shapes = require("./shapes.luau")

local W = 316
local H = 106
local WEEKDAYS = { "MO", "TU", "WE", "TH", "FR", "SA", "SU" }

local lastKey = ""
local lastSvgPath: string? = nil

local function buildCalendarSvg(
  monthLabel: string,
  weekLabel: string,
  days: { { day: number, isToday: boolean, inMonth: boolean } },
  cBg: string,
  cBorder: string,
  cOnSurface: string,
  cMuted: string,
  cPrimary: string,
  cOnPrimary: string
): string
  local parts = {
    string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', W, H, W, H),
    shapes.plateFrameSvg(W, H, cBg, cBorder, cPrimary, cOnSurface),

    -- Header bar (identical baseline y=22 and divider y=29 as FIG. 01 & FIG. 03)
    string.format(
      '<text x="14" y="22" fill="%s" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" font-weight="700" letter-spacing="1.2">FIG. 02</text>',
      cPrimary
    ),
    string.format(
      '<text x="65" y="22" fill="%s" fill-opacity="0.82" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" letter-spacing="1.1">// %s</text>',
      cMuted,
      monthLabel
    ),
    string.format(
      '<text x="%d" y="22" text-anchor="end" fill="%s" fill-opacity="0.68" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9" letter-spacing="0.9">%s</text>',
      W - 14,
      cMuted,
      weekLabel
    ),
    string.format(
      '<line x1="14" y1="29" x2="%d" y2="29" stroke="%s" stroke-opacity="0.38" stroke-width="0.85"/>',
      W - 14,
      cBorder
    ),
  }

  -- 7 balanced day columns across x = 14 .. 302 (288px / 7 ≈ 41.14px)
  local innerW = W - 28
  local colW = innerW / 7.0
  for i = 1, 7 do
    local entry = days[i]
    local cx = 14 + (i - 0.5) * colW
    table.insert(
      parts,
      string.format(
        '<text x="%.2f" y="50" text-anchor="middle" fill="%s" fill-opacity="%.2f" font-family="JetBrainsMono NF, JetBrains Mono, monospace" font-size="9.5" font-weight="%s" letter-spacing="0.8">%s</text>',
        cx,
        if entry.isToday then cPrimary else cMuted,
        if entry.isToday then 1.0 else 0.75,
        if entry.isToday then "700" else "500",
        WEEKDAYS[i]
      )
    )
    if entry.isToday then
      table.insert(
        parts,
        string.format(
          '<rect x="%.2f" y="61" width="30" height="28" rx="4" fill="%s"/>',
          cx - 15,
          cPrimary
        )
      )
      table.insert(
        parts,
        string.format(
          '<text x="%.2f" y="80" text-anchor="middle" fill="%s" font-family="Liberation Serif, DejaVu Serif, serif" font-size="16" font-weight="700">%02d</text>',
          cx,
          cOnPrimary,
          entry.day
        )
      )
    else
      table.insert(
        parts,
        string.format(
          '<text x="%.2f" y="80" text-anchor="middle" fill="%s" fill-opacity="%.2f" font-family="Liberation Serif, DejaVu Serif, serif" font-size="16" font-weight="500">%02d</text>',
          cx,
          if entry.inMonth then cOnSurface else cMuted,
          if entry.inMonth then 0.90 else 0.38,
          entry.day
        )
      )
    end
  end

  table.insert(parts, "</svg>")
  return table.concat(parts)
end

local function render()
  local now = os.time()
  local today = os.date("*t", now)

  local cBg = shapes.color("surface", "#101116")
  local cBorder = shapes.color("outline_variant", "#49454f")
  local cOnSurface = shapes.color("on_surface", "#eae4dc")
  local cMuted = shapes.color("on_surface_variant", "#c4beb5")
  local cPrimary = shapes.color("primary", "#f2be6e")
  local cOnPrimary = shapes.color("on_primary", "#442c00")

  local key = table.concat({
    string.format("%04d-%02d-%02d", today.year, today.month, today.day),
    cBg,
    cBorder,
    cOnSurface,
    cMuted,
    cPrimary,
    cOnPrimary,
  }, "|")

  if key == lastKey and lastSvgPath and noctalia.fileExists(lastSvgPath) then
    return
  end

  local mondayOffset = (today.wday + 5) % 7
  local noonToday = os.time({
    year = today.year,
    month = today.month,
    day = today.day,
    hour = 12,
    min = 0,
    sec = 0,
  })
  local mondayTime = noonToday - mondayOffset * 86400

  local days = {}
  for i = 0, 6 do
    local d = os.date("*t", mondayTime + i * 86400)
    table.insert(days, {
      day = d.day,
      isToday = (d.day == today.day and d.month == today.month and d.year == today.year),
      inMonth = (d.month == today.month),
    })
  end

  local monthLabel = string.upper(os.date("%B %Y", now))
  local weekNum = math.floor((today.yday + 6 - mondayOffset) / 7)
  if weekNum < 1 then
    weekNum = 1
  end
  local weekLabel = string.format("WK %02d", weekNum)

  local svg = buildCalendarSvg(monthLabel, weekLabel, days, cBg, cBorder, cOnSurface, cMuted, cPrimary, cOnPrimary)
  local path = shapes.writeVersionedSvg("editorial_calendar", lastSvgPath, svg)
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
  noctalia.setUpdateInterval(60000)
  render()
end

render()
