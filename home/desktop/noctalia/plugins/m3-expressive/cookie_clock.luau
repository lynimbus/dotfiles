--!nonstrict
-- Editorial Chronometer Plate (FIG. 01 // CHRONO).
-- 100% native UI primitives (zero async SVG reloads -> completely flicker-free).
-- Pairs a concentric orbital date medallion (echoing the geometric halos in both
-- wallpapers) with Liberation Serif time typography and tracked monospace indexing.

local lastKey = ""

local function render()
  local now = os.time()
  local t = os.date("*t", now)
  local timeText = string.format("%02d:%02d", t.hour, t.min)
  local dateLine = string.upper(os.date("%a · %d %b %Y", now))
  local tzTag = os.date("%Z", now)
  local dayText = string.format("%02d", t.day)
  local monShort = string.upper(os.date("%b", now))

  local key = timeText .. "|" .. dateLine .. "|" .. tzTag
  if key == lastKey then
    return
  end
  lastKey = key

  desktopWidget.render(ui.row({
    width = 316,
    height = 106,
    paddingH = 14,
    paddingV = 11,
    gap = 14,
    radius = 6,
    fill = "surface/0.86",
    border = "outline_variant/0.58",
    borderWidth = 1,
    align = "center",
  }, {
    -- Left: concentric geometric orbital medallion (static, crisp, zero flicker)
    ui.row({
      width = 72,
      height = 72,
      radius = 999,
      fill = "surface_container_high/0.35",
      border = "primary/0.68",
      borderWidth = 1.5,
      align = "center",
      justify = "center",
    }, {
      ui.column({
        width = 54,
        height = 54,
        radius = 999,
        border = "secondary/0.38",
        borderWidth = 1,
        align = "center",
        justify = "center",
        gap = 0,
      }, {
        ui.label({
          text = dayText,
          fontFamily = "Liberation Serif",
          fontSize = 20,
          fontWeight = "bold",
          color = "primary",
        }),
        ui.label({
          text = monShort,
          fontFamily = "JetBrainsMono NF",
          fontSize = 8.5,
          fontWeight = "medium",
          color = "on_surface_variant/0.80",
        }),
      }),
    }),

    -- Vertical hairline divider
    ui.row({
      width = 1,
      height = 76,
      fill = "outline_variant/0.35",
    }, {}),

    -- Right: specimen header + serif digital time + date specification
    ui.column({ flexGrow = 1, height = 84, justify = "space_between", align = "stretch" }, {
      ui.row({ justify = "space_between", align = "center" }, {
        ui.row({ gap = 5, align = "center" }, {
          ui.label({
            text = "FIG. 01",
            fontFamily = "JetBrainsMono NF",
            fontSize = 9.5,
            fontWeight = "bold",
            color = "primary",
          }),
          ui.label({
            text = "// CHRONO",
            fontFamily = "JetBrainsMono NF",
            fontSize = 9.5,
            fontWeight = "medium",
            color = "on_surface_variant/0.78",
          }),
        }),
        ui.label({
          text = tzTag,
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
      ui.label({
        text = timeText,
        fontFamily = "Liberation Serif",
        fontSize = 38,
        fontWeight = "bold",
        color = "on_surface",
      }),
      ui.label({
        text = dateLine,
        fontFamily = "JetBrainsMono NF",
        fontSize = 9.5,
        fontWeight = "medium",
        color = "secondary/0.88",
      }),
    }),
  }))
end

function update()
  noctalia.setUpdateInterval(5000)
  render()
end

render()
