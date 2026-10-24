local config = require 'config'
local util = require 'shared.util'

---@class StudioSettings: table

local studioSettings = {}

studioSettings.DOOR_COUNT = 6
studioSettings.DEFAULT_PRIMARY = '#e11d2a'
studioSettings.DEFAULT_SECONDARY = '#16161a'

local MAX_TEXTS = 3
local MAX_IMAGES = 3

local function setOf(values)
    local set = {}

    for _, value in ipairs(values) do
        set[value] = true
    end

    return set
end

studioSettings.WIDTHS = setOf({ 512, 640, 800, 1024, 1280, 1600, 1920 })
studioSettings.WEATHERS = setOf({ 'sunny', 'clear', 'clouds', 'overcast', 'foggy', 'rain' })
studioSettings.PLACES = setOf({ 'green', 'here', 'garage', 'saved' })
studioSettings.GLOW_FROM = setOf({ 'around', 'left', 'right', 'behind', 'above' })
studioSettings.SKIES = setOf({ 'sun', 'soft', 'cloudy' })
studioSettings.SHADOWS = setOf({ 'soft', 'contact', 'cast' })
studioSettings.TINTS = setOf({ 'none', 'light', 'dark', 'limo', 'black' })
studioSettings.FILTERS = setOf({ 'none', 'vivid', 'faded', 'contrast', 'dark', 'bw', 'vignette' })
studioSettings.BACKGROUNDS = setOf({ 'none', 'solid', 'linear', 'radial', 'studio', 'image' })
studioSettings.FRAMES = setOf({ 'fit', 'custom', '16:9', '3:2', '4:3', '1:1', '4:5' })
studioSettings.INDICATORS = setOf({ 'off', 'left', 'right', 'both' })
studioSettings.WEIGHTS = setOf({ 400, 600, 800 })

local clamp = util.clamp

local function oneOf(value, allowed, fallback)
    if allowed[value] then
        return value
    end

    return fallback
end

local function toggle(value, on, off)
    if value == on then
        return on
    end

    return off
end

local function sanitizePicture(value)
    value = tostring(value or ''):sub(1, 300)

    local isLink = value:match('^https?://[%w%-%._~:/%?#%[%]@!%$&\'%(%)%*%+,;=%%]+$')
    local isFile = value:match('^[%w_%-%.]+$')

    if isLink or isFile then
        return value
    end

    return ''
end

local function sanitizeImages(list)
    local images = {}

    for _, image in ipairs(type(list) == 'table' and list or {}) do
        if type(image) == 'table' and #images < MAX_IMAGES then
            images[#images + 1] = {
                src = sanitizePicture(image.src),
                x = clamp(image.x, 0, 100, 50),
                y = clamp(image.y, 0, 100, 50),
                size = clamp(image.size, 2, 100, 16),
                alpha = clamp(image.alpha, 0, 100, 100),
                back = image.back == true,
                on = image.on ~= false,
            }
        end
    end

    return images
end

local function sanitizeTexts(list)
    local texts = {}

    for _, text in ipairs(type(list) == 'table' and list or {}) do
        if type(text) == 'table' and #texts < MAX_TEXTS then
            local weight = math.floor(tonumber(text.weight) or 800)

            texts[#texts + 1] = {
                t = util.truncateUtf8((tostring(text.t or ''):gsub('[%c]', '')), 40),
                x = clamp(text.x, 0, 100, 50),
                y = clamp(text.y, 0, 100, 15),
                size = clamp(text.size, 2, 30, 9, 0.5),
                colour = util.hexColour(text.colour, '#ffffff'),
                weight = oneOf(weight, studioSettings.WEIGHTS, 800),
                caps = text.caps == true,
                spacing = clamp(text.spacing, 0, 40, 0),
                alpha = clamp(text.alpha, 0, 100, 100),
                back = text.back ~= false,
                on = text.on ~= false,
            }
        end
    end

    return texts
end

local function sanitizeDoors(list)
    local doors = {}
    local seen = {}

    for _, door in ipairs(type(list) == 'table' and list or {}) do
        door = math.floor(tonumber(door) or -1)

        if door >= 0 and door < studioSettings.DOOR_COUNT and not seen[door] then
            seen[door] = true
            doors[#doors + 1] = door
        end
    end

    return doors
end

---Every setting the menu sends, checked and limited, with defaults for the missing ones.
---@param input any
---@param fallback? table
---@return StudioSettings
function studioSettings.sanitize(input, fallback)
    input = type(input) == 'table' and input or {}
    fallback = fallback or {}

    local width = tonumber(input.width)
    local plate = tostring(input.plate or fallback.plate or ''):upper():gsub('[^%w ]', ''):sub(1, 8)

    return {
        rot = clamp(input.rot, -180, 180, fallback.rot or 35, 0.1),
        height = clamp(input.height, -10, 45, fallback.height or 8, 0.1),
        fov = clamp(input.fov, 20, 80, fallback.fov or 40),
        distance = clamp(input.distance, 50, 250, 100),
        shiftX = clamp(input.shiftX, -50, 50, 0),
        shiftY = clamp(input.shiftY, -50, 50, 0),

        lights = toggle(input.lights or fallback.lights, 'on', 'off'),
        roof = toggle(input.roof or fallback.roof, 'down', 'up'),
        windows = toggle(input.windows, 'down', 'up'),
        cabin = toggle(input.cabin, 'on', 'off'),
        steer = clamp(input.steer, -40, 40, input.wheels == 'turned' and 30 or 0),
        pitch = clamp(input.pitch, -15, 15, 0),
        roll = clamp(input.roll, -15, 15, 0),
        ride = clamp(input.ride, -10, 10, 0),
        doors = sanitizeDoors(input.doors),
        plate = plate,
        neon = toggle(input.neon, 'on', 'off'),
        neonColour = util.hexColour(input.neonColour, '#00bfff'),
        tint = oneOf(input.tint, studioSettings.TINTS, 'none'),
        indicators = oneOf(input.indicators, studioSettings.INDICATORS, 'off'),
        gear = toggle(input.gear, 'up', 'down'),
        ground = toggle(input.ground, 'off', 'on'),
        paint = toggle(input.paint, 'matte', 'gloss'),

        place = oneOf(input.place, studioSettings.PLACES, 'green'),
        placeId = type(input.placeId) == 'string' and input.placeId:sub(1, 40) or nil,
        hour = clamp(input.hour, 0, 23, 13),
        weather = oneOf(input.weather, studioSettings.WEATHERS, 'sunny'),
        blur = clamp(input.blur, 0, 100, 0),
        filter = oneOf(input.filter, studioSettings.FILTERS, 'none'),
        filterPower = clamp(input.filterPower, 0, 100, 70),

        sky = oneOf(input.sky, studioSettings.SKIES, 'sun'),
        sun = clamp(input.sun, 6, 20, 13),
        shine = clamp(input.shine, 0, 100, 100),
        sunPower = clamp(input.sunPower, 0, 100, 100),
        glow = clamp(input.glow, 0, 100, 0),
        glowColour = util.hexColour(input.glowColour, '#ff2d55'),
        glowFrom = oneOf(input.glowFrom, studioSettings.GLOW_FROM, 'around'),

        width = studioSettings.WIDTHS[width] and width or fallback.width or 800,
        frame = oneOf(input.frame, studioSettings.FRAMES, 'fit'),
        frameW = clamp(input.frameW, 128, 2048, 800),
        frameH = clamp(input.frameH, 128, 2048, 450),
        carSize = clamp(input.carSize, 40, 150, 94),
        carY = clamp(input.carY, 0, 100, 50),
        carDX = clamp(input.carDX, -60, 60, 0, 0.1),
        carDY = clamp(input.carDY, -60, 60, 0, 0.1),

        bg = oneOf(input.bg, studioSettings.BACKGROUNDS, 'none'),
        bgImage = sanitizePicture(input.bgImage),
        bgColourA = util.hexColour(input.bgColourA or input.bgA, '#f4f4f5'),
        bgColourB = util.hexColour(input.bgColourB or input.bgB, '#a1a1aa'),
        bgAngle = clamp(input.bgAngle, 0, 360, 180),
        horizon = clamp(input.horizon, 30, 90, 66),
        vignette = clamp(input.vignette, 0, 100, 0),

        shadow = clamp(input.shadow, 0, 100, 0),
        shadowSoft = clamp(input.shadowSoft, 0, 100, 50),
        shadowWide = clamp(input.shadowWide, 50, 150, 100),
        shadowStyle = oneOf(input.shadowStyle, studioSettings.SHADOWS, 'contact'),
        reflect = clamp(input.reflect, 0, 100, 0),
        reflectBlur = clamp(input.reflectBlur, 0, 100, 60),
        reflectReach = clamp(input.reflectReach, 10, 100, 45),

        texts = sanitizeTexts(input.texts),
        images = sanitizeImages(input.images),

        edge = clamp(input.edge, 0, 100, 0),
        bright = clamp(input.bright, -50, 50, 0),
        contrast = clamp(input.contrast, -50, 50, 0),
        saturation = clamp(input.saturation or input.satur, -50, 50, 0),
        warm = clamp(input.warm, -50, 50, 0),
    }
end

---@param fix any
---@return { bright: number, contrast: number, saturation: number, warm: number }?
function studioSettings.sanitizeFix(fix)
    if type(fix) ~= 'table' then
        return nil
    end

    return {
        bright = clamp(fix.bright, -50, 50, 0),
        contrast = clamp(fix.contrast, -50, 50, 0),
        saturation = clamp(fix.saturation or fix.satur, -50, 50, 0),
        warm = clamp(fix.warm, -50, 50, 0),
    }
end

---@return StudioSettings
function studioSettings.fromConfig()
    local studio = config.Studio

    return studioSettings.sanitize({
        rot = studio.Rotation,
        height = studio.Height,
        fov = studio.Fov,
        lights = studio.Lights and 'on' or 'off',
        roof = studio.RoofDown and 'down' or 'up',
        plate = studio.Plate or 'EVOLENT',
        width = studio.Width,
    })
end

---@param settings StudioSettings
---@return boolean
function studioSettings.isOnLocation(settings)
    return settings.place ~= 'green'
end

return studioSettings
