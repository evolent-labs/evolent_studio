local net = require 'shared.net'
local studioSettings = require 'shared.settings'
local util = require 'shared.util'

local look = {}

local FROZEN_CLOCK_MS_PER_MINUTE = 99999999
local DEFAULT_CLOCK_MS_PER_MINUTE = 2000
local RAIN_LEVEL = 0.6
local GLOW_REACH = 0.75
local GLOW_RANGE = 2.2
local GLOW_LIFT = 0.8
local DOF_NEAR_MARGIN = 3.0
local DOF_FAR_MARGIN = 2.0
local DOF_FAR_RANGE = 25.0

local GAME_WEATHER = {
    sunny = 'EXTRASUNNY',
    clear = 'CLEAR',
    clouds = 'CLOUDS',
    overcast = 'OVERCAST',
    foggy = 'FOGGY',
    rain = 'RAIN',
}
local STUDIO_WEATHER = { sun = 'EXTRASUNNY', soft = 'OVERCAST', cloudy = 'CLOUDS' }
local FILTER_MODIFIER = {
    vivid = 'rply_saturation',
    faded = 'rply_saturation_neg',
    contrast = 'rply_contrast',
    dark = 'rply_brightness_neg',
    bw = 'NG_filmnoir_BW01',
    vignette = 'rply_vignette',
}

local SHINE_MODIFIER = 'evolent_studio_shine'
local SUN_MODIFIER = 'evolent_studio_sun'
local OWN_MODIFIERS = {
    [SHINE_MODIFIER] = {
        'reflection_tweak_interior_amb',
        'reflection_tweak_exterior_amb',
        'reflection_tweak_emissive',
        'reflection_tweak_directional',
        'reflection_hdr_mult',
    },
    [SUN_MODIFIER] = { 'light_dir_mult' },
}
local GLOW_SIDES = {
    around = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } },
    left = { { -1, 0 } },
    right = { { 1, 0 } },
    behind = { { 0, -1 } },
}

---Stops (or restarts) the weather and time sync resources from changing the studio's sky.
---@param hold boolean
function look.holdWorldSync(hold)
    net.send('sync', hold)
    TriggerEvent(hold and 'qb-weathersync:client:DisableSync' or 'qb-weathersync:client:EnableSync')
    TriggerEvent('cd_easytime:PauseSync', hold)
end

local ownModifiers

local function makeOwnModifiers()
    if ownModifiers then
        return ownModifiers
    end

    ownModifiers = {}

    local canMake = CreateTimecycleModifier and SetTimecycleModifierVar and GetTimecycleVarCount and GetTimecycleVarNameByIndex

    if not canMake then
        return ownModifiers
    end

    local usualValue = {}

    for index = 0, GetTimecycleVarCount() - 1 do
        local name = GetTimecycleVarNameByIndex(index) or ''
        usualValue[name] = GetTimecycleVarDefaultValueByIndex and GetTimecycleVarDefaultValueByIndex(index) or 1.0
    end

    for modifier, variables in pairs(OWN_MODIFIERS) do
        CreateTimecycleModifier(modifier)

        for _, variable in ipairs(variables) do
            if usualValue[variable] then
                SetTimecycleModifierVar(modifier, variable, 0.0, 0.0)
                ownModifiers[modifier] = ownModifiers[modifier] or {}
                ownModifiers[modifier][variable] = usualValue[variable]
            end
        end

        if not ownModifiers[modifier] then
            lib.print.warn(('%s can not be made on this game build'):format(modifier))
        end
    end

    return ownModifiers
end

local function applyMainModifier(session)
    local settings, cache = session.settings, session.cache
    local modifier
    local strength

    if studioSettings.isOnLocation(settings) then
        modifier = FILTER_MODIFIER[settings.filter]
        strength = settings.filterPower / 100
    elseif settings.sunPower < 100 and makeOwnModifiers()[SUN_MODIFIER] then
        modifier = SUN_MODIFIER
        strength = 1 - settings.sunPower / 100
    end

    if modifier ~= cache.mainModifier then
        cache.mainModifier = modifier

        if modifier then
            SetTimecycleModifier(modifier)
        else
            ClearTimecycleModifier()
        end
    end

    if modifier then
        SetTimecycleModifierStrength(strength)
    end
end

local function applyShine(session)
    local settings, cache = session.settings, session.cache
    local shine

    if settings.shine < 100 and makeOwnModifiers()[SHINE_MODIFIER] then
        shine = settings.shine
    end

    if shine == cache.shine then
        return
    end

    cache.shine = shine

    if not shine then
        ClearExtraTimecycleModifier()
        return
    end

    for variable, usual in pairs(ownModifiers[SHINE_MODIFIER]) do
        local value = (usual > 0 and usual or 1.0) * shine / 100
        SetTimecycleModifierVar(SHINE_MODIFIER, variable, value, value)
    end

    SetExtraTimecycleModifier(SHINE_MODIFIER)
end

local function clockHour(settings)
    if studioSettings.isOnLocation(settings) then
        return settings.hour
    end

    return settings.sun
end

function look.holdClock(session)
    NetworkOverrideClockTime(clockHour(session.settings), 0, 0)

    if session.cache.weather == 'RAIN' then
        SetRainLevel(RAIN_LEVEL)
    end
end

function look.rememberWeather(session)
    if GetWeatherTypeTransition then
        local from, to, progress = GetWeatherTypeTransition()

        if from and to then
            session.scene.weatherBefore = { from = from, to = to, progress = progress or 0.0 }
        end
    end
end

---Applies the time, weather and screen filters of the settings.
---@param session StudioSession
function look.apply(session)
    local settings = session.settings

    look.holdClock(session)
    applyMainModifier(session)
    applyShine(session)

    local weather

    if studioSettings.isOnLocation(settings) then
        weather = GAME_WEATHER[settings.weather]
    else
        weather = STUDIO_WEATHER[settings.sky]
    end

    if weather == session.cache.weather then
        return
    end

    session.cache.weather = weather

    NetworkOverrideClockMillisecondsPerGameMinute(FROZEN_CLOCK_MS_PER_MINUTE)
    net.send('sync', true, weather)
    ClearWeatherTypePersist()
    SetRainLevel(weather == 'RAIN' and RAIN_LEVEL or 0.0)
    SetWeatherTypeNowPersist(weather)
    SetOverrideWeather(weather)
end

function look.restore(session)
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    NetworkClearClockTimeOverride()
    NetworkOverrideClockMillisecondsPerGameMinute(session.scene.clockSpeed or DEFAULT_CLOCK_MS_PER_MINUTE)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetRainLevel(-1.0)

    local before = session.scene.weatherBefore

    if before and SetWeatherTypeTransition then
        SetWeatherTypeTransition(before.from, before.to, before.progress)
    end

    look.holdWorldSync(false)
end

function look.drawGlow(session)
    local settings, car = session.settings, session.car

    if settings.glow <= 0 then
        return
    end

    local low, high = GetModelDimensions(car.hash)
    local middle = GetOffsetFromEntityInWorldCoords(
        car.entity,
        (low.x + high.x) / 2,
        (low.y + high.y) / 2,
        (low.z + high.z) / 2
    )
    local size = #(high - low)
    local reach = size * GLOW_REACH
    local r, g, b = util.rgbOf(settings.glowColour)
    local range = reach * GLOW_RANGE
    local intensity = settings.glow / 10.0

    if settings.glowFrom == 'above' then
        DrawLightWithRange(middle.x, middle.y, middle.z + size * 0.6, r, g, b, range, intensity)
        return
    end

    local cameraAt = GetCamCoord(session.camera.handle)
    local toCamera = vector3(cameraAt.x - middle.x, cameraAt.y - middle.y, 0.0)
    toCamera = #toCamera > 0.01 and toCamera / #toCamera or vector3(0.0, -1.0, 0.0)
    local right = vector3(-toCamera.y, toCamera.x, 0.0)

    for _, side in ipairs(GLOW_SIDES[settings.glowFrom]) do
        local at = middle + right * (reach * side[1]) + toCamera * (reach * side[2])
        DrawLightWithRange(at.x, at.y, at.z + GLOW_LIFT, r, g, b, range, intensity)
    end
end

function look.updateDepthOfField(session)
    local settings, camera = session.settings, session.camera
    local handle = camera.handle

    if studioSettings.isOnLocation(settings) and settings.blur > 0 then
        local blur = settings.blur / 100
        local distance = #(GetCamCoord(handle) - GetEntityCoords(session.car.entity))

        SetUseHiDof()
        SetCamUseShallowDofMode(handle, true)
        SetCamNearDof(handle, math.max(0.1, distance - DOF_NEAR_MARGIN))
        SetCamFarDof(handle, distance + DOF_FAR_MARGIN + (1.0 - blur) * DOF_FAR_RANGE)
        SetCamDofStrength(handle, blur)
        camera.hasDof = true
    elseif camera.hasDof then
        SetCamUseShallowDofMode(handle, false)
        SetCamDofStrength(handle, 0.0)
        camera.hasDof = false
    end
end

return look
