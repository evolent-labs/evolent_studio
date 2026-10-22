local car = require 'client.car'
local net = require 'shared.net'
local nui = require 'client.nui'
local photos = require 'client.photos'
local studioSettings = require 'shared.settings'
local state = require 'client.state'
local util = require 'shared.util'

local UPLOAD_TIMEOUT_MS = 60000

local pendingUploads = {}

local function forwardToPage(event, buildMessage)
    net.on(event, function(...)
        if state.session then
            local kind, message = buildMessage(...)
            nui.send(kind, message)
        end
    end)
end

nui.on('refresh', function(_, cb)
    cb({ ok = true })
    net.send('list')
end)

forwardToPage('list', function(vehicles)
    return 'vehicles', { list = vehicles }
end)

nui.onStudioAction('delete', function(_, data)
    local model = util.modelName(data.model)

    CreateThread(function()
        if not net.await('delete', model) then return end

        photos.forget(model)

        if state.session then
            nui.send('row', { id = model, status = 'missing' })
        end
    end)
end)

nui.on('addon', function(data, cb)
    local model = type(data) == 'table' and util.modelName(data.model) or ''

    if model == '' then
        cb({ ok = false, error = 'Type a spawn code first.' })
        return
    end

    local hash = joaat(model)

    if not util.isValidModel(model) or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        cb({ ok = false, error = model .. ' is not a vehicle model on this server.' })
        return
    end

    local label = GetLabelText(GetDisplayNameFromVehicleModel(hash))
    local name = label ~= 'NULL' and label or model

    net.send('addon', model, name)
    cb({ ok = true, id = model, name = name })
end)

nui.onStudioAction('style', function(_, data)
    net.send('style', data)
end)

nui.onStudioAction('styles:delete', function(_, data)
    net.send('styles:delete', data.id)
end)

forwardToPage('styles', function(styles, addedId)
    return 'styles', { styles = styles, added = addedId }
end)

nui.onStudioAction('place', function(session, data)
    if not studioSettings.isOnLocation(session.settings) or not session.car.entity then
        return
    end

    local at, heading = car.spot(session)
    local hasGround, groundZ = GetGroundZFor_3dCoord(at.x, at.y, at.z + 1.5, false)

    net.send('place', {
        name = data.name or '',
        x = at.x,
        y = at.y,
        z = hasGround and groundZ or at.z,
        h = heading,
        hour = session.settings.hour,
        weather = session.settings.weather,
    })
end)

nui.onStudioAction('places:delete', function(_, data)
    net.send('places:delete', data.id)
end)

net.on('places', function(places, addedId)
    local session = state.session

    if session then
        session.places = type(places) == 'table' and places or {}
        nui.send('places', { places = session.places, added = addedId })
    end
end)

nui.onStudioAction('uploadSettings', function(_, data)
    CreateThread(function()
        local view = net.await('uploadSettings', data)

        if view and state.session then
            nui.send('upload', { upload = view })
        end
    end)
end)

net.on('uploaded', function(model, ok, urlOrError)
    local reply = { ok = ok }

    if ok then
        reply.url = urlOrError
    else
        reply.error = urlOrError
    end

    util.resolveReply(pendingUploads, model, reply)
end)

nui.on('upload', function(data, cb)
    local model = type(data) == 'table' and util.modelName(data.model) or ''
    local isFree = util.isValidModel(model) and not pendingUploads[model]
    local canUpload = state.session and isFree and type(data.image) == 'string'

    if not canUpload then
        cb({ ok = false, error = 'Could not be uploaded' })
        return
    end

    local reply = util.expectReply(
        pendingUploads,
        model,
        UPLOAD_TIMEOUT_MS,
        { ok = false, error = 'No answer from the server' }
    )

    net.sendLarge('upload', model, data.image)

    CreateThread(function()
        cb(Citizen.Await(reply))
    end)
end)
