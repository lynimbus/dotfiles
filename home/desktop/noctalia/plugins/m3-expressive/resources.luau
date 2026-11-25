--!nonstrict
-- Material 3 Expressive tonal system resource cards (CPU / RAM / Disk).
-- Follows the end4-pC M3 Expressive card trio: each card uses a distinct M3 tonal container
-- role (primary_container, secondary_container, tertiary_container) paired with a scalloped
-- shape badge in the top-right corner and bold emphasized metric at the bottom-left.

local shapes = require("./shapes.luau")

local lastPaletteKey = ""
local badgePaths: { cpu: string?, ram: string?, disk: string? } = {}

local function buildBadgeSvg(lobes: number, amp: number, bg: string, fg: string, innerMarkup: string): string
  local d = shapes.cookiePath(20, 20, 17, lobes, amp, 96)
  return table.concat({
    '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">',
    string.format('<path d="%s" fill="%s"/>', d, bg),
    string.format(
      '<g fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">%s</g>',
      fg,
      innerMarkup
    ),
    "</svg>",
  })
end

local function ensureBadges()
  local cPri = shapes.color("primary", "#ffb2bc")
  local cOnPri = shapes.color("on_primary", "#561d27")
  local cSec = shapes.color("secondary", "#e5bdc2")
  local cOnSec = shapes.color("on_secondary", "#43292d")
  local cTer = shapes.color("tertiary", "#e5c18d")
  local cOnTer = shapes.color("on_tertiary", "#422c05")

  local paletteKey = table.concat({ cPri, cOnPri, cSec, cOnSec, cTer, cOnTer }, "|")
  if paletteKey == lastPaletteKey and badgePaths.cpu and badgePaths.ram and badgePaths.disk then
    return
  end

  -- Activity pulse glyph inside 12-sided cookie (CPU)
  local cpuSvg = buildBadgeSvg(12, 0.075, cPri, cOnPri, '<path d="M11 20h3l2.2-5.5 3.6 11 2.2-5.5h3"/>')
  -- Chip glyph inside 6-sided cookie (RAM)
  local ramSvg = buildBadgeSvg(
    6,
    0.09,
    cSec,
    cOnSec,
    '<rect x="14.5" y="14.5" width="11" height="11" rx="2"/><path d="M17.5 11.5v3M22.5 11.5v3M17.5 25.5v3M22.5 25.5v3M11.5 17.5h3M11.5 22.5h3M25.5 17.5h3M25.5 22.5h3"/>'
  )
  -- Storage stack glyph inside 8-sided cookie (Disk)
  local diskSvg = buildBadgeSvg(
    8,
    0.08,
    cTer,
    cOnTer,
    string.format(
      '<rect x="13" y="13" width="14" height="5.5" rx="2"/><rect x="13" y="21.5" width="14" height="5.5" rx="2"/><circle cx="16.5" cy="15.75" r="0.9" fill="%s" stroke="none"/><circle cx="16.5" cy="24.25" r="0.9" fill="%s" stroke="none"/>',
      cOnTer,
      cOnTer
    )
  )

  badgePaths.cpu = shapes.writeVersionedSvg("badge_cpu", badgePaths.cpu, cpuSvg)
  badgePaths.ram = shapes.writeVersionedSvg("badge_ram", badgePaths.ram, ramSvg)
  badgePaths.disk = shapes.writeVersionedSvg("badge_disk", badgePaths.disk, diskSvg)
  lastPaletteKey = paletteKey
end

local function statCard(
  key: string,
  fillRole: string,
  fgRole: string,
  badgePath: string?,
  fallbackGlyph: string,
  badgeBg: string,
  badgeFg: string,
  valueText: string,
  labelText: string
)
  local badgeNode
  if badgePath then
    badgeNode = ui.image({ path = badgePath, width = 34, height = 34, fit = "contain" })
  else
    badgeNode = ui.row({
      width = 34,
      height = 34,
      radius = 999,
      fill = badgeBg,
      align = "center",
      justify = "center",
    }, {
      ui.glyph({ name = fallbackGlyph, size = 18, color = badgeFg }),
    })
  end

  return ui.column({
    key = key,
    width = 122,
    height = 114,
    padding = 14,
    radius = 24,
    fill = fillRole .. "/0.92",
    justify = "space_between",
  }, {
    ui.row({ justify = "end", align = "center" }, {
      badgeNode,
    }),
    ui.column({ gap = 1, align = "start" }, {
      ui.label({
        text = valueText,
        fontSize = 24,
        fontWeight = "bold",
        color = fgRole,
      }),
      ui.label({
        text = labelText,
        fontSize = 12,
        fontWeight = "medium",
        color = fgRole .. "/0.72",
      }),
    }),
  })
end

local function render()
  ensureBadges()

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

  desktopWidget.render(ui.row({ gap = 10, align = "center" }, {
    statCard(
      "cpu",
      "primary_container",
      "on_primary_container",
      badgePaths.cpu,
      "cpu",
      "primary",
      "on_primary",
      string.format("%d%%", cpuPct),
      "CPU"
    ),
    statCard(
      "ram",
      "secondary_container",
      "on_secondary_container",
      badgePaths.ram,
      "activity",
      "secondary",
      "on_secondary",
      string.format("%d%%", ramPct),
      "RAM"
    ),
    statCard(
      "disk",
      "tertiary_container",
      "on_tertiary_container",
      badgePaths.disk,
      "database",
      "tertiary",
      "on_tertiary",
      string.format("%d%%", diskPct),
      "Disk"
    ),
  }))
end

function update()
  noctalia.setUpdateInterval(2000)
  render()
end

render()
