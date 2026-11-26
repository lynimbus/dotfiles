--!nonstrict
-- Editorial Ephemeris Plate (FIG. 02 // EPHEMERIS).
-- 100% native UI primitives (zero async SVG reloads -> completely flicker-free).
-- Matches FIG. 01, FIG. 03, and FIG. 04 exact geometry, hairline rules, and palette roles.

local WEEKDAYS = { "MO", "TU", "WE", "TH", "FR", "SA", "SU" }
local lastKey = ""

local function render()
  local now = os.time()
  local today = os.date("*t", now)
  local dayKey = string.format("%04d-%02d-%02d", today.year, today.month, today.day)
  if dayKey == lastKey then
    return
  end
  lastKey = dayKey

  -- Lua os.date wday: 1 = Sun, 2 = Mon, ..., 7 = Sat -> convert to 0 = Mon .. 6 = Sun
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

  local dayCols = {}
  for i = 0, 6 do
    local d = os.date("*t", mondayTime + i * 86400)
    local isToday = (d.day == today.day and d.month == today.month and d.year == today.year)
    local inMonth = (d.month == today.month)

    local dayCell
    if isToday then
      dayCell = ui.row({
        width = 30,
        height = 28,
        radius = 4,
        fill = "primary",
        align = "center",
        justify = "center",
      }, {
        ui.label({
          text = string.format("%02d", d.day),
          fontFamily = "Liberation Serif",
          fontSize = 15,
          fontWeight = "bold",
          color = "on_primary",
        }),
      })
    else
      dayCell = ui.row({
        width = 30,
        height = 28,
        radius = 4,
        align = "center",
        justify = "center",
      }, {
        ui.label({
          text = string.format("%02d", d.day),
          fontFamily = "Liberation Serif",
          fontSize = 15,
          fontWeight = "medium",
          color = if inMonth then "on_surface/0.90" else "on_surface_variant/0.38",
        }),
      })
    end

    table.insert(
      dayCols,
      ui.column({ key = "d" .. tostring(i), width = 38, align = "center", gap = 5 }, {
        ui.label({
          text = WEEKDAYS[i + 1],
          fontFamily = "JetBrainsMono NF",
          fontSize = 9.5,
          fontWeight = if isToday then "bold" else "medium",
          color = if isToday then "primary" else "on_surface_variant/0.75",
        }),
        dayCell,
      })
    )
  end

  local monthLabel = string.upper(os.date("%B %Y", now))
  local weekNum = math.floor((today.yday + 6 - mondayOffset) / 7)
  if weekNum < 1 then
    weekNum = 1
  end
  local weekLabel = string.format("WK %02d", weekNum)

  desktopWidget.render(ui.column({
    width = 316,
    height = 106,
    paddingH = 14,
    paddingV = 11,
    gap = 7,
    radius = 6,
    fill = "surface/0.86",
    border = "outline_variant/0.58",
    borderWidth = 1,
    justify = "space_between",
  }, {
    ui.row({ justify = "space_between", align = "center" }, {
      ui.row({ gap = 6, align = "center" }, {
        ui.label({
          text = "FIG. 02",
          fontFamily = "JetBrainsMono NF",
          fontSize = 9.5,
          fontWeight = "bold",
          color = "primary",
        }),
        ui.label({
          text = "// " .. monthLabel,
          fontFamily = "JetBrainsMono NF",
          fontSize = 9.5,
          fontWeight = "medium",
          color = "on_surface/0.86",
        }),
      }),
      ui.label({
        text = weekLabel,
        fontFamily = "JetBrainsMono NF",
        fontSize = 9,
        fontWeight = "medium",
        color = "on_surface_variant/0.68",
      }),
    }),
    ui.row({
      height = 1,
      fill = "outline_variant/0.38",
    }, {}),
    ui.row({ justify = "space_between", align = "center" }, dayCols),
  }))
end

function update()
  noctalia.setUpdateInterval(60000)
  render()
end

render()
