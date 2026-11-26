--!nonstrict
-- Editorial Telemetry Plate (FIG. 03 // TELEMETRY).
-- Directly echoes the FIG. 03 spectrum bar charts in both wallpapers using native
-- UI primitives (zero async SVG reloads -> completely flicker-free 2s live updates).

local HISTORY_LEN = 10

local cpuHist: { number } = {}
local ramHist: { number } = {}
for i = 1, HISTORY_LEN do
  cpuHist[i] = 0
  ramHist[i] = 0
end

local function pushSample(buf: { number }, val: number)
  for i = 1, HISTORY_LEN - 1 do
    buf[i] = buf[i + 1]
  end
  buf[HISTORY_LEN] = math.max(0, math.min(100, val))
end

local function spectrumBars(keyPrefix: string, values: { number }, role: string)
  local bars = {}
  local maxH = 22
  local count = #values
  for i = 1, count do
    local pct = values[i]
    local bh = math.max(2, math.floor((pct / 100.0) * maxH + 0.5))
    local alpha = if i == count then 0.95 else (0.45 + 0.35 * (i / count))
    table.insert(
      bars,
      ui.row({
        key = keyPrefix .. tostring(i),
        width = 4,
        height = bh,
        radius = 1,
        fill = string.format("%s/%.2f", role, alpha),
      }, {})
    )
  end

  return ui.column({ gap = 0 }, {
    ui.row({ height = maxH, gap = 3, align = "end" }, bars),
    ui.row({ height = 1, fill = role .. "/0.35" }, {}),
  })
end

local function diskMeter(diskPct: number, role: string)
  local bars = {}
  local maxH = 22
  local count = HISTORY_LEN
  local filledCount = math.max(1, math.floor((diskPct / 100.0) * count + 0.5))
  for i = 1, count do
    local filled = (i <= filledCount)
    local bh = if filled then math.floor(5 + (i / count) * (maxH - 5) + 0.5) else 3
    table.insert(
      bars,
      ui.row({
        key = "diskb" .. tostring(i),
        width = 4,
        height = bh,
        radius = 1,
        fill = if filled then (role .. "/0.88") else "outline_variant/0.38",
      }, {})
    )
  end

  return ui.column({ gap = 0 }, {
    ui.row({ height = maxH, gap = 3, align = "end" }, bars),
    ui.row({ height = 1, fill = "outline_variant/0.40" }, {}),
  })
end

local function metricColumn(key: string, title: string, pct: number, role: string, meterNode: any)
  return ui.column({ key = key, flexGrow = 1, gap = 2, align = "start" }, {
    ui.label({
      text = title,
      fontFamily = "JetBrainsMono NF",
      fontSize = 9.5,
      fontWeight = "bold",
      color = role,
    }),
    ui.row({ align = "end", gap = 1 }, {
      ui.label({
        text = tostring(pct),
        fontFamily = "Liberation Serif",
        fontSize = 22,
        fontWeight = "bold",
        color = "on_surface",
      }),
      ui.label({
        text = "%",
        fontFamily = "Liberation Serif",
        fontSize = 12,
        fontWeight = "medium",
        color = "on_surface_variant/0.82",
      }),
    }),
    meterNode,
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

  desktopWidget.render(ui.column({
    width = 316,
    height = 116,
    paddingH = 14,
    paddingV = 10,
    gap = 6,
    radius = 6,
    fill = "surface/0.86",
    border = "outline_variant/0.58",
    borderWidth = 1,
    justify = "space_between",
  }, {
    -- Header index row
    ui.row({ justify = "space_between", align = "center" }, {
      ui.row({ gap = 6, align = "center" }, {
        ui.label({
          text = "FIG. 03",
          fontFamily = "JetBrainsMono NF",
          fontSize = 9.5,
          fontWeight = "bold",
          color = "primary",
        }),
        ui.label({
          text = "// TELEMETRY",
          fontFamily = "JetBrainsMono NF",
          fontSize = 9.5,
          fontWeight = "medium",
          color = "on_surface_variant/0.82",
        }),
      }),
      ui.row({ gap = 5, align = "center" }, {
        ui.row({
          width = 5,
          height = 5,
          radius = 999,
          fill = "primary",
        }, {}),
        ui.label({
          text = "LIVE",
          fontFamily = "JetBrainsMono NF",
          fontSize = 9,
          fontWeight = "medium",
          color = "on_surface_variant/0.72",
        }),
      }),
    }),
    ui.row({
      height = 1,
      fill = "outline_variant/0.38",
    }, {}),
    -- Three synchronized telemetry columns
    ui.row({ gap = 10, align = "end" }, {
      metricColumn("cpu", "CPU", cpuPct, "primary", spectrumBars("cpub", cpuHist, "primary")),
      ui.row({ width = 1, height = 64, fill = "outline_variant/0.28" }, {}),
      metricColumn("ram", "RAM", ramPct, "secondary", spectrumBars("ramb", ramHist, "secondary")),
      ui.row({ width = 1, height = 64, fill = "outline_variant/0.28" }, {}),
      metricColumn("disk", "DISK", diskPct, "tertiary", diskMeter(diskPct, "tertiary")),
    }),
  }))
end

function update()
  noctalia.setUpdateInterval(2000)
  render()
end

render()
