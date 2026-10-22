local camera = require 'client.camera'
local car = require 'client.car'
local nui = require 'client.nui'
local studioSettings = require 'shared.settings'
local state = require 'client.state'

local RIGHT_BUTTON = 2
local MOVE_SETTLE_DELAY_MS = 450

local function mouseOnLocation(data)
    local session = state.session

    if not session or type(data) ~= 'table' then
        return nil
    end

    local screenX, screenY = tonumber(data.x), tonumber(data.y)
    local canPoint = studioSettings.isOnLocation(session.settings) and not state.isLocked(session) and session.car.entity

    if canPoint and screenX and screenY then
        return session, screenX, screenY
    end
end

local function moveSpot(session, at, offsetX, offsetY)
    local spot = session.scene.spot

    spot.x = at.x + offsetX
    spot.y = at.y + offsetY
    spot.z = at.z
    car.place(session)
end

local function settleInThread(session)
    CreateThread(function()
        car.settle(session)
    end)
end

nui.on('hover', function(data, cb)
    local session, screenX, screenY = mouseOnLocation(data)
    cb({ car = session ~= nil and camera.isOnCar(session, screenX, screenY) })
end)

nui.on('grab', function(data, cb)
    local session, screenX, screenY = mouseOnLocation(data)

    if not session or not camera.isOnCar(session, screenX, screenY) then
        cb({ car = false })
        return
    end

    if data.button == RIGHT_BUTTON then
        session.drag = { isSpin = true }
    else
        local spot = session.scene.spot
        local at = camera.groundAt(session, screenX, screenY) or vector3(spot.x, spot.y, spot.z)
        session.drag = { dx = spot.x - at.x, dy = spot.y - at.y }
    end

    cb({ car = true })
end)

nui.on('drag', function(data, cb)
    cb({ ok = true })

    local session, screenX, screenY = mouseOnLocation(data)
    local drag = session?.drag

    if not drag or drag.isSpin then
        return
    end

    local at = camera.groundAt(session, screenX, screenY)

    if at then
        moveSpot(session, at, drag.dx, drag.dy)
    end
end)

nui.onStudioAction('spin', function(session, data)
    local degrees = tonumber(data.by)

    if not degrees or not session.drag or not session.drag.isSpin then
        return
    end

    local scene = session.scene
    scene.spot.h = (scene.spot.h + degrees) % 360
    scene.turned += degrees

    car.place(session)
    nui.send('spot', { h = scene.spot.h })
end)

nui.on('release', function(_, cb)
    cb({ ok = true })

    local session = state.session

    if not session then
        return
    end

    local wasDragging = session.drag ~= nil
    session.drag = nil

    if wasDragging and studioSettings.isOnLocation(session.settings) then
        settleInThread(session)
    end
end)

nui.on('settle', function(_, cb)
    cb({ ok = true })

    local session = state.session

    if session and not state.isLocked(session) then
        session.car.rest = nil
        settleInThread(session)
    end
end)

nui.on('car:moveTo', function(data, cb)
    cb({ ok = true })

    local session, screenX, screenY = mouseOnLocation(data)
    local at = session and camera.groundAt(session, screenX, screenY)

    if not at then
        return
    end

    moveSpot(session, at, 0.0, 0.0)

    CreateThread(function()
        Wait(MOVE_SETTLE_DELAY_MS)
        car.settle(session)
    end)
end)

nui.onStudioAction('car:setHeading', function(session, data)
    local heading = tonumber(data.h)

    if not heading or not studioSettings.isOnLocation(session.settings) or state.isLocked(session) then
        return
    end

    heading = heading % 360

    local scene = session.scene

    car.spot(session)
    scene.turned += camera.angleTo(scene.spot.h, heading)
    scene.spot.h = heading
    car.place(session)
    car.settleSoon(session)
end)

nui.on('camera:resetTurn', function(_, cb)
    cb({ ok = true })

    local session = state.session

    if session and not state.isLocked(session) then
        session.scene.turned = 0.0
    end
end)

nui.on('car:resetPosition', function(_, cb)
    cb({ ok = true })

    local session = state.session

    if session and studioSettings.isOnLocation(session.settings) and not state.isLocked(session) then
        car.resetSpot(session)
        car.place(session)
        settleInThread(session)
    end
end)
