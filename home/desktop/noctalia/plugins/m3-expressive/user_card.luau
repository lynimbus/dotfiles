--!nonstrict
-- Editorial Session Plate (FIG. 04 // SESSION).
-- 100% native UI primitives (zero async SVG reloads -> completely flicker-free).
-- Combines a concentric orbital monogram badge, serif greeting + host uptime,
-- and crisp micro-radius action controls (Lock, Settings, Session).

local username = noctalia.getenv("USER") or "user"
local initial = string.upper(string.sub(username, 1, 1))
local hostname = "nixos"
do
  local rawHost = noctalia.readFile("/etc/hostname")
  if rawHost and rawHost ~= "" then
    hostname = noctalia.string.trim(rawHost)
  end
end

local function readUptime(): string
  local raw = noctalia.readFile("/proc/uptime")
  if not raw then
    return ""
  end
  local secs = tonumber(string.match(raw, "^(%d+)"))
  if not secs then
    return ""
  end
  local days = math.floor(secs / 86400)
  local hours = math.floor((secs % 86400) / 3600)
  local mins = math.floor((secs % 3600) / 60)
  if days > 0 then
    return string.format("UP %dD %dH", days, hours)
  elseif hours > 0 then
    return string.format("UP %dH %02dM", hours, mins)
  else
    return string.format("UP %dM", mins)
  end
end

local function greetingForHour(hour: number): string
  if hour < 6 then
    return "Good Night"
  elseif hour < 12 then
    return "Good Morning"
  elseif hour < 18 then
    return "Good Afternoon"
  else
    return "Good Evening"
  end
end

local function render()
  local now = os.date("*t")
  local up = readUptime()

  desktopWidget.render(ui.column({
    width = 316,
    height = 116,
    paddingH = 14,
    paddingV = 10,
    gap = 7,
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
          text = "FIG. 04",
          fontFamily = "JetBrainsMono NF",
          fontSize = 9.5,
          fontWeight = "bold",
          color = "primary",
        }),
        ui.label({
          text = "// SESSION",
          fontFamily = "JetBrainsMono NF",
          fontSize = 9.5,
          fontWeight = "medium",
          color = "on_surface_variant/0.82",
        }),
      }),
      ui.label({
        text = up,
        fontFamily = "JetBrainsMono NF",
        fontSize = 9,
        fontWeight = "medium",
        color = "on_surface_variant/0.72",
      }),
    }),
    ui.row({
      height = 1,
      fill = "outline_variant/0.38",
    }, {}),
    -- Identity row with native concentric monogram badge
    ui.row({ gap = 10, align = "center" }, {
      ui.row({
        width = 36,
        height = 36,
        radius = 999,
        fill = "surface_container_high/0.65",
        border = "primary/0.72",
        borderWidth = 1.2,
        align = "center",
        justify = "center",
      }, {
        ui.row({
          width = 28,
          height = 28,
          radius = 999,
          border = "secondary/0.35",
          borderWidth = 1,
          align = "center",
          justify = "center",
        }, {
          ui.label({
            text = initial,
            fontFamily = "Liberation Serif",
            fontSize = 15,
            fontWeight = "bold",
            color = "on_surface",
          }),
        }),
      }),
      ui.column({ gap = 1, flexGrow = 1, align = "start" }, {
        ui.label({
          text = string.format("%s, %s", greetingForHour(now.hour), username),
          fontFamily = "Liberation Serif",
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
        ui.label({
          text = string.format("%s@%s", username, hostname),
          fontFamily = "JetBrainsMono NF",
          fontSize = 10,
          fontWeight = "medium",
          color = "on_surface_variant/0.78",
        }),
      }),
    }),
    -- Crisp architectural action strip
    ui.row({ gap = 6, align = "center" }, {
      ui.row({
        key = "lock",
        flexGrow = 1,
        height = 26,
        radius = 4,
        fill = "primary",
        gap = 6,
        align = "center",
        justify = "center",
        onClick = function()
          noctalia.runAsync({ "noctalia", "msg", "session", "lock" })
        end,
      }, {
        ui.glyph({ name = "lock", size = 13, color = "on_primary" }),
        ui.label({
          text = "LOCK",
          fontFamily = "JetBrainsMono NF",
          fontSize = 10.5,
          fontWeight = "bold",
          color = "on_primary",
        }),
      }),
      ui.row({
        key = "settings",
        width = 34,
        height = 26,
        radius = 4,
        fill = "surface_container_high/0.85",
        border = "outline_variant/0.55",
        borderWidth = 1,
        align = "center",
        justify = "center",
        onClick = function()
          noctalia.runAsync({ "noctalia", "msg", "settings-toggle" })
        end,
      }, {
        ui.glyph({ name = "settings", size = 14, color = "on_surface" }),
      }),
      ui.row({
        key = "session",
        width = 34,
        height = 26,
        radius = 4,
        fill = "surface_container_high/0.85",
        border = "outline_variant/0.55",
        borderWidth = 1,
        align = "center",
        justify = "center",
        onClick = function()
          noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "session" })
        end,
      }, {
        ui.glyph({ name = "power", size = 14, color = "tertiary" }),
      }),
    }),
  }))
end

function update()
  noctalia.setUpdateInterval(30000)
  render()
end

render()
