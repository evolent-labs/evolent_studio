local catalog = require 'server.catalog'
local config = require 'shared.config'
local database = require 'server.database'
local kvp = require 'server.kvp'
local net = require 'shared.net'
local studioSettings = require 'shared.settings'
local uploads = require 'server.uploads'
local util = require 'shared.util'

local MAX_STYLES = 30
local MAX_PLACES = 50
local MAX_ADDONS = 500
local MAX_FAILED = 500
local MAX_COORDINATE = 100000
local MAX_UPLOAD_LENGTH = 3000000
local RATE_WINDOW_MS = 10000
local RATE_MAX_REQUESTS = 30
local RATE_SAME_MODEL_MS = 60000

local function newId(prefix)
    return ('%s%d%d'):format(prefix, os.time(), math.random(100, 999))
end

local function nameOr(name, fallback)
    if name ~= '' then
        return name
    end

    return fallback
end

local function loadStyles()
    local styles = kvp.load('styles')
    local defaults = studioSettings.fromConfig()

    for _, style in ipairs(styles) do
        style.settings = studioSettings.sanitize(style.settings, defaults)
    end

    return styles
end

RegisterCommand(config.Command, function(playerId, args)
    if playerId == 0 then
        return
    end

    if not net.isAdmin(playerId) then
        net.send(playerId, 'open', { allowed = false, ace = config.Ace, accent = config.Accent })
        return
    end

    local model = util.modelName(args[1])
    local defaults = studioSettings.fromConfig()

    net.sendLarge(playerId, 'open', {
        allowed = true,
        ace = config.Ace,
        accent = config.Accent,
        studio = studioSettings.sanitize(kvp.load('studio'), defaults),
        defaults = defaults,
        limitKb = config.MaxLayerKB,
        model = util.isValidModel(model) and model or nil,
        places = kvp.load('places'),
        styles = loadStyles(),
        images = config.Images,
        upload = uploads.view(),
    })
end, false)

net.onAdmin('list', function(playerId)
    database.waitReady()
    net.sendLarge(playerId, 'list', catalog.vehicleList())
end)

net.onAdmin('studio', function(_, settings)
    kvp.save('studio', studioSettings.sanitize(settings, studioSettings.fromConfig()))
end)

local playersHoldingWeather = {}

local function releaseWeatherHold(playerId)
    if not playersHoldingWeather[playerId] then
        return
    end

    playersHoldingWeather[playerId] = nil

    if GetPlayerName(playerId) then
        local state = Player(playerId).state
        state:set('playerWeather', nil, true)
        state:set('syncWeather', true, true)
    end
end

net.on('sync', function(hold, weather)
    local playerId = source

    if not hold then
        releaseWeatherHold(playerId)
        return
    end

    if not net.isAdmin(playerId) then
        return
    end

    playersHoldingWeather[playerId] = true

    local state = Player(playerId).state
    local isWeatherName = type(weather) == 'string' and #weather <= 16 and weather:match('^%u+$')

    if isWeatherName then
        state:set('playerWeather', weather, true)
    end

    state:set('syncWeather', false, true)
end)

net.onAdmin('style', function(playerId, input)
    if type(input) ~= 'table' then
        return
    end

    local styles = kvp.load('styles')
    local name = util.sanitizeText(input.name, 32)
    local settings = studioSettings.sanitize(input.settings, studioSettings.fromConfig())
    local savedId

    if not input.fresh then
        for _, style in ipairs(styles) do
            if style.id == input.id then
                style.settings = settings
                style.name = nameOr(name, style.name)
                savedId = style.id
            end
        end
    end

    if not savedId then
        if #styles >= MAX_STYLES then
            return
        end

        savedId = newId('style')
        styles[#styles + 1] = {
            id = savedId,
            name = nameOr(name, ('Style %d'):format(#styles + 1)),
            settings = settings,
        }
    end

    kvp.save('styles', styles)
    net.sendLarge(playerId, 'styles', styles, savedId)
end)

net.onAdmin('styles:delete', function(playerId, id)
    local styles = util.withoutId(kvp.load('styles'), id)

    kvp.save('styles', styles)
    net.sendLarge(playerId, 'styles', styles)
end)

local function isCoordinate(value)
    return value ~= nil and value == value and math.abs(value) < MAX_COORDINATE
end

net.onAdmin('place', function(playerId, input)
    if type(input) ~= 'table' then
        return
    end

    local x = tonumber(input.x)
    local y = tonumber(input.y)
    local z = tonumber(input.z)
    local heading = tonumber(input.h)

    if not (isCoordinate(x) and isCoordinate(y) and isCoordinate(z) and isCoordinate(heading)) then
        return
    end

    local places = kvp.load('places')

    if #places >= MAX_PLACES then
        return
    end

    local id = newId('place')
    local weather = studioSettings.WEATHERS[input.weather] and input.weather or 'sunny'

    places[#places + 1] = {
        id = id,
        name = nameOr(util.sanitizeText(input.name, 32), ('Place %d'):format(#places + 1)),
        x = x,
        y = y,
        z = z,
        h = heading % 360,
        hour = util.clamp(input.hour, 0, 23, 13),
        weather = weather,
    }

    kvp.save('places', places)
    net.sendLarge(playerId, 'places', places, id)
end)

net.onAdmin('places:delete', function(playerId, id)
    local places = util.withoutId(kvp.load('places'), id)

    kvp.save('places', places)
    net.sendLarge(playerId, 'places', places)
end)

net.onAdmin('addon', function(_, model, name)
    model = util.modelName(model)

    if not util.isValidModel(model) then
        return
    end

    local addons = kvp.load('addons')

    if not addons[model] and util.count(addons) >= MAX_ADDONS then
        return
    end

    addons[model] = nameOr(util.sanitizeText(name, 64), model)
    kvp.save('addons', addons)
end)

net.onAdmin('failed', function(_, model, problem)
    model = util.modelName(model)

    if not util.isValidModel(model) or database.versionOf(model) then
        return
    end

    local failures = kvp.load('failed')

    if failures[model] or util.count(failures) < MAX_FAILED then
        failures[model] = util.sanitizeText(problem or 'Failed', 80)
        kvp.save('failed', failures)
    end
end)

local function forgetFailure(model)
    local failures = kvp.load('failed')

    if failures[model] then
        failures[model] = nil
        kvp.save('failed', failures)
    end
end

net.onAdminCallback('delete', function(playerId, model)
    model = util.modelName(model)

    if not util.isValidModel(model) then return false end

    database.waitReady()
    database.deletePhoto(model)

    lib.print.info(('%s deleted by %s'):format(model, GetPlayerName(playerId)))

    return true
end)

local function whyNotStorable(model, layers)
    if not util.isValidModel(model) or type(layers) ~= 'table' then
        return 'Could not be saved'
    end

    local longest = util.maxDataUrlLength(config.MaxLayerKB)

    for _, key in ipairs(database.LAYER_KEYS) do
        local layer = layers[key]

        if type(layer) ~= 'string' or not layer:match('^data:image/webp;base64,[%w%+/=]+$') then
            lib.print.warn(('photo of %s refused: layer %s is not a webp picture'):format(model, key))
            return 'Could not be saved'
        end

        if #layer > longest then
            return 'Photo over size limit'
        end
    end

    return nil
end

net.onAdmin('save', function(playerId, model, layers)
    database.waitReady()
    model = util.modelName(model)

    local problem = whyNotStorable(model, layers)

    if not problem and not database.savePhoto(model, layers) then
        problem = 'Could not be saved'
    end

    if problem then
        net.send(playerId, 'saved', model, false, problem)
        return
    end

    forgetFailure(model)

    lib.print.info(('%s saved by %s'):format(model, GetPlayerName(playerId)))
    net.send(playerId, 'saved', model, true)
end)

net.onAdminCallback('uploadSettings', function(_, input)
    if type(input) ~= 'table' then return false end

    uploads.saveSettings(input)

    return uploads.view()
end)

net.onAdmin('upload', function(playerId, model, dataUrl)
    model = util.modelName(model)

    if not util.isValidModel(model) then
        return
    end

    local function answer(ok, urlOrProblem)
        net.send(playerId, 'uploaded', model, ok, urlOrProblem)
    end

    database.waitReady()

    if not database.versionOf(model) then
        return answer(false, 'Photograph this vehicle first')
    end

    if type(dataUrl) ~= 'string' then
        return answer(false, 'The picture could not be read')
    end

    if #dataUrl > MAX_UPLOAD_LENGTH then
        return answer(false, 'The picture is too big to send, pick WebP or a smaller size')
    end

    uploads.send(model, dataUrl, function(url, problem)
        if url then
            database.setUrl(model, url)
            answer(true, url)
        else
            lib.print.warn(('upload of %s failed: %s'):format(model, problem))
            answer(false, problem)
        end
    end)
end)

local requestRateLimits = {}

local function isOverRateLimit(playerId, model)
    local now = GetGameTimer()
    local window = requestRateLimits[playerId]

    if not window or now - window.startedAt > RATE_WINDOW_MS then
        local askedAt = window?.askedAt or {}

        for asked, at in pairs(askedAt) do
            if now - at >= RATE_SAME_MODEL_MS then
                askedAt[asked] = nil
            end
        end

        window = { startedAt = now, count = 0, askedAt = askedAt }
        requestRateLimits[playerId] = window
    end

    window.count += 1

    local lastAsked = window.askedAt[model]

    if window.count > RATE_MAX_REQUESTS or (lastAsked and now - lastAsked < RATE_SAME_MODEL_MS) then
        return true
    end

    window.askedAt[model] = now

    return false
end

net.on('request', function(model)
    local playerId = source
    model = util.modelName(model)

    if not util.isValidModel(model) then
        return
    end

    local function answerBusy()
        net.send(playerId, 'layers', model, 0, false, true)
    end

    if not net.isAdmin(playerId) and isOverRateLimit(playerId, model) then
        return answerBusy()
    end

    database.waitReady()

    local version = database.versionOf(model)
    local layers = false

    if version then
        layers = database.layersOf(model)

        if layers == nil then
            return answerBusy()
        end
    end

    net.sendLarge(playerId, 'layers', model, version or 0, layers)
end)

AddEventHandler('playerDropped', function()
    playersHoldingWeather[source] = nil
    requestRateLimits[source] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= cache.resource then
        return
    end

    for playerId in pairs(playersHoldingWeather) do
        releaseWeatherHold(playerId)
    end
end)
