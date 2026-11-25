--!nonstrict
-- Material 3 Expressive week calendar strip (inspired by end4-pC CalendarWidget).
-- Emphasized primary pill for the month heading + 7-day strip with active day highlighted
-- inside a filled primary circle.

local WEEKDAYS = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }
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
        height = 30,
        radius = 999,
        fill = "primary",
        align = "center",
        justify = "center",
      }, {
        ui.label({
          text = tostring(d.day),
          fontSize = 13,
          fontWeight = "bold",
          color = "on_primary",
        }),
      })
    else
      dayCell = ui.row({
        width = 30,
        height = 30,
        radius = 999,
        align = "center",
        justify = "center",
      }, {
        ui.label({
          text = tostring(d.day),
          fontSize = 13,
          fontWeight = "medium",
          color = if inMonth then "on_surface" else "on_surface_variant/0.45",
        }),
      })
    end

    table.insert(
      dayCols,
      ui.column({ key = "d" .. tostring(i), width = 36, align = "center", gap = 6 }, {
        ui.label({
          text = WEEKDAYS[i + 1],
          fontSize = 11,
          fontWeight = if isToday then "bold" else "medium",
          color = if isToday then "primary" else "on_surface_variant",
        }),
        dayCell,
      })
    )
  end

  local monthLabel = os.date("%B %Y", now)
  local weekdayLabel = os.date("%A", now)

  desktopWidget.render(ui.column({
    width = 312,
    padding = 14,
    gap = 12,
    radius = 24,
    fill = "surface_container/0.86",
    border = "outline_variant/0.5",
    borderWidth = 1,
  }, {
    ui.row({ justify = "space_between", align = "center" }, {
      ui.row({
        fill = "primary",
        radius = 999,
        paddingH = 12,
        paddingV = 5,
        align = "center",
      }, {
        ui.label({
          text = monthLabel,
          fontSize = 13,
          fontWeight = "bold",
          color = "on_primary",
        }),
      }),
      ui.label({
        text = weekdayLabel,
        fontSize = 12,
        fontWeight = "medium",
        color = "on_surface_variant",
      }),
    }),
    ui.row({ justify = "space_between", align = "center" }, dayCols),
  }))
end

function update()
  noctalia.setUpdateInterval(60000)
  render()
end

render()
