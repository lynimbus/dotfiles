--!nonstrict
-- Widget-aware wallpaper depth service for lynimbus/m3-expressive.
-- Generates Depth Anything V2 foreground masks that keep interactive/text desktop
-- widgets cleanly above the wallpaper and apply an iOS-style occlusion guard to
-- clocks, while allowing decorative widgets (audio visualizers) behind foregrounds.

noctalia.setUpdateInterval(1500)

local helperPath = noctalia.pluginDir() .. "/depth_mask.py"
local dataDir = noctalia.pluginDataDir()
if dataDir == nil then
  error("m3-expressive depth service requires a plugin data directory")
end

local pythonAvailable = noctalia.commandExists("python3")
local activeJob = nil
local pending = {}
local queued = {}
local applied = {}

local function clamp(value: number, low: number, high: number): number
  return math.max(low, math.min(high, value))
end

local function readParams()
  local enabled = noctalia.getConfig("depth_enabled")
  if enabled == nil then
    enabled = true
  end
  local threshold = tonumber(noctalia.getConfig("depth_threshold")) or 58
  local feather = tonumber(noctalia.getConfig("depth_feather")) or 6
  local maxClock = tonumber(noctalia.getConfig("clock_max_occlusion")) or 28
  return {
    enabled = enabled == true,
    threshold = clamp(threshold, 0, 100) / 100,
    feather = clamp(feather, 0, 50) / 100,
    maxClockOcclusion = clamp(maxClock, 0, 100) / 100,
  }
end

local function classifyWidget(widgetType: string): string
  if widgetType == "audio_visualizer" or widgetType == "fancy_audio_visualizer" then
    return "depth"
  end
  if widgetType == "clock" or widgetType == "lynimbus/m3-expressive:cookie_clock" then
    return "clock"
  end
  return "protect"
end

local function resolveWidgetSize(id: string, widgetType: string, uiScale: number): (number, number, number, number)
  local base = "desktop_widgets.widget." .. id
  local bw = tonumber(noctalia.getSetting(base .. ".box_width")) or 0
  local bh = tonumber(noctalia.getSetting(base .. ".box_height")) or 0

  if bw > 0 and bh > 0 then
    local extra = 0
    if noctalia.getSetting(base .. ".settings.background") == true then
      local bgPad = tonumber(noctalia.getSetting(base .. ".settings.background_padding")) or 0
      extra = bgPad * 2
    end
    return bw + extra, bh + extra, 16, 16
  end

  if widgetType == "lynimbus/m3-expressive:cookie_clock" then
    return 204 * uiScale, 204 * uiScale, 16, 16
  elseif widgetType == "lynimbus/m3-expressive:resources" then
    return 386 * uiScale, 114 * uiScale, 16, 16
  elseif widgetType == "lynimbus/m3-expressive:calendar" then
    return 312 * uiScale, 130 * uiScale, 16, 16
  elseif widgetType == "lynimbus/m3-expressive:user_card" then
    return 312 * uiScale, 126 * uiScale, 16, 16
  elseif widgetType == "noctalia/lyrics:desktop" then
    local lw = tonumber(noctalia.getSetting(base .. ".settings.width")) or 640
    local fontSize = tonumber(noctalia.getSetting(base .. ".settings.font_size")) or 22
    local lines = tonumber(noctalia.getSetting(base .. ".settings.line_count")) or 3
    local lh = (fontSize * 38 / 22) * lines
    -- Tight vertical padding keeps lyrics clear without eating into the visualizer below.
    return lw * uiScale, lh * uiScale, 14, 6
  end

  return 320 * uiScale, 150 * uiScale, 16, 16
end

local function collectWidgets(outputName: string)
  if noctalia.getSetting("desktop_widgets.enabled") == false then
    return {}
  end
  local order = noctalia.getSetting("desktop_widgets.widget_order")
  if type(order) ~= "table" then
    return {}
  end
  local uiScale = math.max(tonumber(noctalia.getSetting("accessibility.ui_scale")) or 1, 0.5)
  local list = {}
  for _, id in ipairs(order) do
    if type(id) == "string" and id ~= "" then
      local base = "desktop_widgets.widget." .. id
      local enabled = noctalia.getSetting(base .. ".enabled")
      local targetOutput = noctalia.getSetting(base .. ".output")
      if enabled ~= false and (targetOutput == nil or targetOutput == "" or targetOutput == outputName) then
        local widgetType = tostring(noctalia.getSetting(base .. ".type") or "")
        local cx = tonumber(noctalia.getSetting(base .. ".cx"))
        local cy = tonumber(noctalia.getSetting(base .. ".cy"))
        if cx ~= nil and cy ~= nil then
          local w, h, padX, padY = resolveWidgetSize(id, widgetType, uiScale)
          table.insert(list, {
            id = id,
            type = widgetType,
            role = classifyWidget(widgetType),
            cx = cx,
            cy = cy,
            width = w,
            height = h,
            pad_x = padX,
            pad_y = padY,
          })
        end
      end
    end
  end
  return list
end

local runNext

local function enqueue(job)
  if queued[job.outputName] == job.key then
    return
  end
  if activeJob ~= nil and activeJob.outputName == job.outputName and activeJob.key == job.key then
    return
  end
  queued[job.outputName] = job.key
  table.insert(pending, job)
end

runNext = function()
  if activeJob ~= nil or not pythonAvailable then
    return
  end
  local job = nil
  while #pending > 0 do
    local candidate = table.remove(pending, 1)
    queued[candidate.outputName] = nil
    local currentWp = noctalia.wallpaperPath(candidate.outputName)
    if currentWp == candidate.wallpaperPath then
      job = candidate
      break
    end
  end
  if job == nil then
    return
  end

  activeJob = job
  local accepted = noctalia.runAsync({
    "python3",
    helperPath,
    "--data-dir",
    dataDir,
    "generate",
    "--wallpaper",
    job.wallpaperPath,
    "--threshold",
    tostring(job.threshold),
    "--feather",
    tostring(job.feather),
    "--max-clock-occlusion",
    tostring(job.maxClockOcclusion),
    "--output-width",
    tostring(job.outputWidth),
    "--output-height",
    tostring(job.outputHeight),
    "--fill-mode",
    job.fillMode,
    "--widgets-json",
    job.widgetsJson,
  }, function(result)
    local completed = activeJob
    activeJob = nil
    if completed == nil then
      runNext()
      return
    end

    local currentWp = noctalia.wallpaperPath(completed.outputName)
    local params = readParams()
    if not params.enabled or currentWp ~= completed.wallpaperPath then
      if not params.enabled then
        noctalia.setWallpaperMask(completed.outputName, nil)
      end
      runNext()
      return
    end

    if result.exitCode == 0 and not result.timedOut then
      local parsed = noctalia.json.decode(result.stdout or "")
      if type(parsed) == "table" and type(parsed.maskPath) == "string" and parsed.maskPath ~= "" then
        noctalia.setWallpaperMask(completed.outputName, {
          path = parsed.maskPath,
          wallpaperPath = completed.wallpaperPath,
        })
        applied[completed.outputName] = completed.key
      else
        noctalia.setWallpaperMask(completed.outputName, nil)
      end
    else
      noctalia.setWallpaperMask(completed.outputName, nil)
    end
    runNext()
  end, 60000)

  if not accepted then
    activeJob = nil
    runNext()
  end
end

local function syncOutputs(force: boolean)
  local params = readParams()
  local fillMode = tostring(noctalia.getSetting("wallpaper.fill_mode") or "crop")
  local seen = {}

  for _, output in ipairs(noctalia.outputs()) do
    seen[output.name] = true
    if not params.enabled or not pythonAvailable then
      if applied[output.name] ~= nil or force then
        noctalia.setWallpaperMask(output.name, nil)
        applied[output.name] = nil
      end
    else
      local wallpaperPath = noctalia.wallpaperPath(output.name)
      if wallpaperPath ~= nil and not noctalia.fileExists(wallpaperPath) then
        wallpaperPath = nil
      end
      if wallpaperPath == nil then
        if applied[output.name] ~= nil then
          noctalia.setWallpaperMask(output.name, nil)
          applied[output.name] = nil
        end
      else
        local widgets = collectWidgets(output.name)
        local widgetsJson = noctalia.json.encode(widgets)
        local outW = tonumber(output.width) or 1462
        local outH = tonumber(output.height) or 914
        local key = table.concat({
          wallpaperPath,
          string.format("%.4f", params.threshold),
          string.format("%.4f", params.feather),
          string.format("%.4f", params.maxClockOcclusion),
          string.format("%.1fx%.1f", outW, outH),
          fillMode,
          widgetsJson,
        }, "|")

        if force or applied[output.name] ~= key then
          if force or (applied[output.name] ~= nil and string.sub(applied[output.name], 1, #wallpaperPath) ~= wallpaperPath) then
            noctalia.setWallpaperMask(output.name, nil)
          end
          enqueue({
            outputName = output.name,
            wallpaperPath = wallpaperPath,
            threshold = params.threshold,
            feather = params.feather,
            maxClockOcclusion = params.maxClockOcclusion,
            outputWidth = outW,
            outputHeight = outH,
            fillMode = fillMode,
            widgetsJson = widgetsJson,
            key = key,
          })
        end
      end
    end
  end

  for name, _ in pairs(applied) do
    if not seen[name] then
      applied[name] = nil
      queued[name] = nil
    end
  end

  runNext()
end

function onIpc(event, _payload)
  if event == "regenerate" then
    applied = {}
    syncOutputs(true)
  elseif event == "clear-cache" then
    applied = {}
    pending = {}
    queued = {}
    for _, output in ipairs(noctalia.outputs()) do
      noctalia.setWallpaperMask(output.name, nil)
    end
    noctalia.runAsync({ "python3", helperPath, "--data-dir", dataDir, "clear-cache" }, function()
      syncOutputs(true)
    end, 30000)
  end
end

function onConfigChanged()
  syncOutputs(false)
end

function update()
  syncOutputs(false)
end

syncOutputs(false)
