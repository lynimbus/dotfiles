--!nonstrict
-- Material 3 Expressive 12-sided Cookie analog clock (inspired by end4-pC CookieClock).
-- Renders a scalloped Cookie12Sided dial tinted live from the active Noctalia M3 palette,
-- oversized low-emphasis cardinal numerals, thick rounded pill hands, and floating day/month badges.

local shapes = require("./shapes.luau")

local lastKey = ""
local lastSvgPath: string? = nil

local function buildClockSvg(
  hour: number,
  minute: number,
  day: number,
  month: number,
  cBody: string,
  cOnBody: string,
  cHour: string,
  cMinute: string,
  cOnHour: string,
  cDayBg: string,
  cDayFg: string,
  cMonthBg: string,
  cMonthFg: string
): string
  local cookieD = shapes.cookiePath(110, 110, 88, 12, 0.068, 144)

  local hourAngle = ((hour % 12) + minute / 60) * 30
  local minAngle = minute * 6

  local hRad = math.rad(hourAngle - 90)
  local mRad = math.rad(minAngle - 90)
  local hx = 110 + 43 * math.cos(hRad)
  local hy = 110 + 43 * math.sin(hRad)
  local mx = 110 + 62 * math.cos(mRad)
  local my = 110 + 62 * math.sin(mRad)

  -- Subtle dots at non-cardinal hour positions.
  local dots = {}
  for h = 1, 12 do
    if h ~= 12 and h ~= 3 and h ~= 6 and h ~= 9 then
      local rad = math.rad(h * 30 - 90)
      local dx = 110 + 70 * math.cos(rad)
      local dy = 110 + 70 * math.sin(rad)
      table.insert(
        dots,
        string.format(
          '<circle cx="%.1f" cy="%.1f" r="2.6" fill="%s" fill-opacity="0.28"/>',
          dx,
          dy,
          cOnBody
        )
      )
    end
  end

  local dayText = string.format("%02d", day)
  local monthText = string.format("%02d", month)

  return table.concat({
    '<svg xmlns="http://www.w3.org/2000/svg" width="220" height="220" viewBox="0 0 220 220">',
    string.format('<path d="%s" fill="%s" fill-opacity="0.92"/>', cookieD, cBody),
    table.concat(dots),
    -- Oversized expressive cardinal numerals inside the dial
    string.format(
      '<g fill="%s" fill-opacity="0.26" font-family="Rubik, Noto Sans CJK SC, sans-serif" font-weight="800" font-size="38" text-anchor="middle" dominant-baseline="central">',
      cOnBody
    ),
    '<text x="110" y="54">12</text>',
    '<text x="166" y="111">3</text>',
    '<text x="110" y="168">6</text>',
    '<text x="54" y="111">9</text>',
    "</g>",
    -- Minute hand (tertiary pill)
    string.format(
      '<line x1="110" y1="110" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="10" stroke-linecap="round"/>',
      mx,
      my,
      cMinute
    ),
    -- Hour hand (primary bold pill)
    string.format(
      '<line x1="110" y1="110" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="14" stroke-linecap="round"/>',
      hx,
      hy,
      cHour
    ),
    -- Center pivot
    string.format(
      '<circle cx="110" cy="110" r="6.5" fill="%s" stroke="%s" stroke-width="3"/>',
      cOnHour,
      cHour
    ),
    -- Top-left floating day badge (tertiary_container)
    string.format('<circle cx="38" cy="38" r="22" fill="%s"/>', cDayBg),
    string.format(
      '<text x="38" y="39" fill="%s" font-family="Rubik, sans-serif" font-weight="700" font-size="18" text-anchor="middle" dominant-baseline="central">%s</text>',
      cDayFg,
      dayText
    ),
    -- Bottom-right floating month badge (secondary_container)
    string.format('<circle cx="182" cy="182" r="22" fill="%s"/>', cMonthBg),
    string.format(
      '<text x="182" y="183" fill="%s" font-family="Rubik, sans-serif" font-weight="700" font-size="18" text-anchor="middle" dominant-baseline="central">%s</text>',
      cMonthFg,
      monthText
    ),
    "</svg>",
  })
end

local function render()
  local t = os.date("*t")
  local cBody = shapes.color("primary_container", "#3d2c2e")
  local cOnBody = shapes.color("on_primary_container", "#ffd9dd")
  local cHour = shapes.color("primary", "#ffb2bc")
  local cMinute = shapes.color("tertiary", "#e5c18d")
  local cOnHour = shapes.color("on_primary", "#561d27")
  local cDayBg = shapes.color("tertiary_container", "#5b421a")
  local cDayFg = shapes.color("on_tertiary_container", "#ffdea8")
  local cMonthBg = shapes.color("secondary_container", "#5c3f43")
  local cMonthFg = shapes.color("on_secondary_container", "#ffd9dd")

  local key = table.concat({
    tostring(t.hour),
    tostring(t.min),
    tostring(t.day),
    tostring(t.month),
    cBody,
    cOnBody,
    cHour,
    cMinute,
    cDayBg,
    cMonthBg,
  }, "|")

  if key == lastKey and lastSvgPath and noctalia.fileExists(lastSvgPath) then
    return
  end

  local svg = buildClockSvg(
    t.hour,
    t.min,
    t.day,
    t.month,
    cBody,
    cOnBody,
    cHour,
    cMinute,
    cOnHour,
    cDayBg,
    cDayFg,
    cMonthBg,
    cMonthFg
  )
  local path = shapes.writeVersionedSvg("cookie_clock", lastSvgPath, svg)
  if not path then
    return
  end
  lastSvgPath = path
  lastKey = key

  desktopWidget.render(ui.column({ align = "center", justify = "center" }, {
    ui.image({
      path = path,
      width = 204,
      height = 204,
      fit = "contain",
    }),
  }))
end

function update()
  noctalia.setUpdateInterval(5000)
  render()
end

render()
