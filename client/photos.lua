local net = require 'shared.net'
local nui = require 'client.nui'
local util = require 'shared.util'

local photos = {}

local LAYER_REQUEST_TIMEOUT_MS = 30000
local PAINTED_CACHE_LIMIT = 300

local layerCache = {}
local layerRequests = {}
local paintedCache = {}
local paintedCount = 0

net.on('layers', function(model, version, layers, isBusy)
    if not isBusy then
        layerCache[model] = { version = version, layers = layers or nil }
    end

    util.resolveReply(layerRequests, model, true)
end)

---The stored layers of a model, asked from the server when the cached ones are older than `version`.
---@param model string
---@param version? integer
---@return table|false|nil layers
---@return integer? version
function photos.layersOf(model, version)
    local cached = layerCache[model]

    if cached and (version == nil or cached.version >= version) then
        return cached.layers, cached.version
    end

    local request = layerRequests[model]

    if not request then
        request = util.expectReply(layerRequests, model, LAYER_REQUEST_TIMEOUT_MS, false)
        net.send('request', model)
    end

    Citizen.Await(request)
    cached = layerCache[model]

    if cached then
        return cached.layers, cached.version
    end
end

---@param model string
function photos.forget(model)
    layerCache[model] = nil
end

local function rememberPainted(key, image)
    paintedCount += 1

    if paintedCount > PAINTED_CACHE_LIMIT then
        table.wipe(paintedCache)
        paintedCount = 1
    end

    paintedCache[key] = image
end

local function paintedPhoto(model, version, primary, secondary)
    if not util.isValidModel(model) or not util.isHexColour(primary) then
        return nil
    end

    if not util.isHexColour(secondary) then
        secondary = primary
    end

    local layers, storedVersion = photos.layersOf(model, tonumber(version))

    if not layers then
        return nil
    end

    local photoKey = model .. ':' .. storedVersion
    local paintedKey = ('%s:%s:%s'):format(photoKey, primary, secondary)

    if not paintedCache[paintedKey] then
        local reply = nui.requestFromPage({
            action = 'paint',
            key = photoKey,
            layers = layers,
            primary = primary,
            secondary = secondary,
        })

        if type(reply) ~= 'table' or not reply.ok then
            return nil
        end

        rememberPainted(paintedKey, reply.image)
    end

    return paintedCache[paintedKey]
end

exports('GetPhoto', function(model, version, primary, secondary, cb)
    if type(cb) ~= 'function' and type(cb) ~= 'table' then
        return
    end

    model = util.modelName(model)

    CreateThread(function()
        cb(paintedPhoto(model, version, primary, secondary))
    end)
end)

nui.on('layers', function(data, cb)
    local model = type(data) == 'table' and util.modelName(data.model) or ''

    if not util.isValidModel(model) then
        cb({})
        return
    end

    CreateThread(function()
        local layers = photos.layersOf(model, tonumber(data.version))
        cb({ layers = layers })
    end)
end)

return photos
