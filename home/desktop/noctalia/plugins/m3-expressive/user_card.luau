--!nonstrict
-- Material 3 Expressive profile & quick-actions card (inspired by end4-pC UserCardWidget).
-- Combines a scalloped 8-sided Cookie avatar badge, greeting + uptime, and M3 Expressive
-- pill/circle action buttons (Lock, Settings, Session).

local shapes = require("./shapes.luau")

local lastPaletteKey = ""
local avatarPath: string? = nil

local username = noctalia.getenv("USER") or "user"
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
    return string.format("Up %dd %dh", days, hours)
  elseif hours > 0 then
    return string.format("Up %dh %dm", hours, mins)
  else
    return string.format("Up %dm", mins)
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

local function ensureAvatar()
  local cBg = shapes.color("primary_container", "#3d2c2e")
  local cFg = shapes.color("on_primary_container", "#ffd9dd")
  local cAccent = shapes.color("primary", "#ffb2bc")
  local key = cBg .. "|" .. cFg .. "|" .. cAccent
  if key == lastPaletteKey and avatarPath and noctalia.fileExists(avatarPath) then
    return
  end

  local d = shapes.cookiePath(24, 24, 21, 8, 0.085, 112)
  local initial = string.upper(string.sub(username, 1, 1))
  local svg = table.concat({
    '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">',
    string.format('<path d="%s" fill="%s"/>', d, cBg),
    string.format('<path d="%s" fill="none" stroke="%s" stroke-width="1.5" stroke-opacity="0.45"/>', d, cAccent),
    string.format(
      '<text x="24" y="25" fill="%s" font-family="Rubik, sans-serif" font-weight="700" font-size="20" text-anchor="middle" dominant-baseline="central">%s</text>',
      cFg,
      initial
    ),
    "</svg>",
  })
  avatarPath = shapes.writeVersionedSvg("user_avatar", avatarPath, svg)
  lastPaletteKey = key
end

local function render()
  ensureAvatar()

  local now = os.date("*t")
  local up = readUptime()
  local subline = if up ~= "" then string.format("%s@%s · %s", username, hostname, up) else string.format("%s@%s", username, hostname)

  local avatarNode
  if avatarPath then
    avatarNode = ui.image({ path = avatarPath, width = 46, height = 46, fit = "contain" })
  else
    avatarNode = ui.row({
      width = 46,
      height = 46,
      radius = 999,
      fill = "primary_container",
      align = "center",
      justify = "center",
    }, {
      ui.glyph({ name = "user", size = 22, color = "on_primary_container" }),
    })
  end

  desktopWidget.render(ui.column({
    width = 312,
    padding = 14,
    gap = 12,
    radius = 24,
    fill = "surface_container/0.86",
    border = "outline_variant/0.5",
    borderWidth = 1,
  }, {
    ui.row({ gap = 12, align = "center" }, {
      avatarNode,
      ui.column({ gap = 2, flexGrow = 1, align = "start" }, {
        ui.label({
          text = string.format("%s, %s", greetingForHour(now.hour), username),
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
        ui.label({
          text = subline,
          fontSize = 12,
          fontWeight = "medium",
          color = "on_surface_variant",
        }),
      }),
    }),
    ui.row({ gap = 8, align = "center" }, {
      ui.row({
        key = "lock",
        flexGrow = 1,
        height = 36,
        radius = 999,
        fill = "primary",
        gap = 6,
        align = "center",
        justify = "center",
        onClick = function()
          noctalia.runAsync({ "noctalia", "msg", "session", "lock" })
        end,
      }, {
        ui.glyph({ name = "lock", size = 15, color = "on_primary" }),
        ui.label({
          text = "Lock",
          fontSize = 13,
          fontWeight = "bold",
          color = "on_primary",
        }),
      }),
      ui.row({
        key = "settings",
        width = 36,
        height = 36,
        radius = 999,
        fill = "secondary_container",
        align = "center",
        justify = "center",
        onClick = function()
          noctalia.runAsync({ "noctalia", "msg", "settings-toggle" })
        end,
      }, {
        ui.glyph({ name = "settings", size = 16, color = "on_secondary_container" }),
      }),
      ui.row({
        key = "session",
        width = 36,
        height = 36,
        radius = 999,
        fill = "tertiary_container",
        align = "center",
        justify = "center",
        onClick = function()
          noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "session" })
        end,
      }, {
        ui.glyph({ name = "power", size = 16, color = "on_tertiary_container" }),
      }),
    }),
  }))
end

function update()
  noctalia.setUpdateInterval(30000)
  render()
end

render()
