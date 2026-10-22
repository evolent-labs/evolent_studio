local camera = require 'client.camera'
local car = require 'client.car'
local config = require 'shared.config'
local look = require 'client.look'
local net = require 'shared.net'
local nui = require 'client.nui'
local queue = require 'client.queue'
local studioSettings = require 'shared.settings'
local shoot = require 'client.shoot'
local state = require 'client.state'
local util = require 'shared.util'

local BACKDROP_HALF_SIZE = 80.0
local CLEAR_RADIUS = 80.0
local HIDDEN_REFRESH_MS = 250
local WORLD_REFRESH_MS = 1000
local CAMERA_SMOOTHING = 14.0
local PLACE_LOAD_TIMEOUT_MS = 5000
local COLLISION_TIMEOUT_MS = 5000
local PANEL_OFFSET = { x = 0.288, y = 0.0, scale = 1.7 }
local WORLD_KEYS = { 'hour', 'weather', 'place', 'filter', 'filterPower', 'sky', 'sun', 'shine', 'sunPower' }
local BACKDROP_COLOURS = { green = { 0, 255, 0 }, black = { 0, 0, 0 }, white = { 255, 255, 255 } }
local BACKDROP_FACES = {
    { 1, 2, 3, 4 },
    { 5, 6, 7, 8 },
    { 1, 2, 6, 5 },
    { 2, 3, 7, 6 },
    { 3, 4, 8, 7 },
    { 4, 1, 5, 8 },
}

local DrawPoly = DrawPoly
local isPedFrozen = false

---@param data table
---@param ped integer
---@return StudioSession
local function newSession(data, ped)
    local standing = GetEntityCoords(ped)
    local hasGround, groundZ = GetGroundZFor_3dCoord(standing.x, standing.y, standing.z + 1.0, false)

    return {
        settings = studioSettings.sanitize(data.studio),
        places = type(data.places) == 'table' and data.places or {},
        primary = studioSettings.DEFAULT_PRIMARY,
        secondary = studioSettings.DEFAULT_SECONDARY,
        isShooting = false,
        drag = nil,
        car = {
            entity = nil,
            model = nil,
            hash = nil,
            isAircraft = false,
            pose = nil,
            goal = nil,
            rest = nil,
            isSettling = false,
            settleToken = nil,
        },
        camera = {
            handle = nil,
            view = nil,
            reach = nil,
            panel = { x = PANEL_OFFSET.x, y = PANEL_OFFSET.y, scale = PANEL_OFFSET.scale },
            skipSmoothing = false,
            hasDof = false,
            box = nil,
            footprint = nil,
            boxSentAt = 0,
        },
        scene = {
            studioCentre = config.StudioSpot,
            playerSpot = {
                x = standing.x,
                y = standing.y,
                z = hasGround and groundZ or standing.z - 1.0,
                h = GetEntityHeading(ped),
            },
            spot = nil,
            turned = 0.0,
            backdrop = 'green',
            interior = nil,
            floor = nil,
            isSpawningFloor = false,
            hasNoFloor = false,
            hiddenEntities = {},
            hiddenAt = 0,
            placeToken = 0,
            ownCar = nil,
            clockSpeed = GetMillisecondsPerGameMinute(),
            weatherBefore = nil,
        },
        cache = {
            carKey = nil,
            weather = nil,
            mainModifier = nil,
            shine = nil,
        },
    }
end

local function drawBackdrop(centre, colour)
    local half = BACKDROP_HALF_SIZE
    local r, g, b = colour[1], colour[2], colour[3]
    local corners = {
        centre + vector3(-half, -half, -half), centre + vector3(half, -half, -half),
        centre + vector3(half, half, -half), centre + vector3(-half, half, -half),
        centre + vector3(-half, -half, half), centre + vector3(half, -half, half),
        centre + vector3(half, half, half), centre + vector3(-half, half, half),
    }

    for _, face in ipairs(BACKDROP_FACES) do
        local p, q, s, t = corners[face[1]], corners[face[2]], corners[face[3]], corners[face[4]]

        DrawPoly(p.x, p.y, p.z, q.x, q.y, q.z, s.x, s.y, s.z, r, g, b, 255)
        DrawPoly(p.x, p.y, p.z, s.x, s.y, s.z, t.x, t.y, t.z, r, g, b, 255)
        DrawPoly(s.x, s.y, s.z, q.x, q.y, q.z, p.x, p.y, p.z, r, g, b, 255)
        DrawPoly(t.x, t.y, t.z, s.x, s.y, s.z, p.x, p.y, p.z, r, g, b, 255)
    end
end

local function clearLocation(session, centre)
    local scene = session.scene

    SetVehicleDensityMultiplierThisFrame(0.0)
    SetRandomVehicleDensityMultiplierThisFrame(0.0)
    SetParkedVehicleDensityMultiplierThisFrame(0.0)
    SetPedDensityMultiplierThisFrame(0.0)
    SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)

    if GetGameTimer() > scene.hiddenAt then
        scene.hiddenAt = GetGameTimer() + HIDDEN_REFRESH_MS

        local nearby = {}

        for _, pool in ipairs({ 'CPed', 'CVehicle' }) do
            for _, entity in ipairs(GetGamePool(pool)) do
                if entity ~= session.car.entity and #(GetEntityCoords(entity) - centre) < CLEAR_RADIUS then
                    nearby[#nearby + 1] = entity
                end
            end
        end

        scene.hiddenEntities = nearby
    end

    for _, entity in ipairs(scene.hiddenEntities) do
        if DoesEntityExist(entity) then
            SetEntityLocallyInvisible(entity)
        end
    end
end

local function unpinInterior(session)
    local scene = session.scene

    if scene.interior then
        UnpinInterior(scene.interior)
        scene.interior = nil
    end
end

local function isPlaceLoadCurrent(session, token)
    return not state.isStale(session) and session.scene.placeToken == token
end

---Moves the scene to the place in the settings and waits for its collision before setting the car down.
---@param session StudioSession
local function loadPlace(session)
    if state.isStale(session) then
        return
    end

    local scene = session.scene
    scene.placeToken += 1
    local token = scene.placeToken

    unpinInterior(session)

    if not studioSettings.isOnLocation(session.settings) then
        local centre = scene.studioCentre

        SetFocusPosAndVel(centre.x, centre.y, centre.z, 0.0, 0.0, 0.0)
        car.place(session, true)
        session.camera.skipSmoothing = true
        car.settle(session)
        return
    end

    car.resetSpot(session)
    scene.turned = 0.0

    local spot = scene.spot
    SetFocusPosAndVel(spot.x, spot.y, spot.z, 0.0, 0.0, 0.0)

    local deadline = GetGameTimer() + PLACE_LOAD_TIMEOUT_MS
    local interior = GetInteriorAtCoords(spot.x, spot.y, spot.z)

    if interior ~= 0 then
        PinInteriorInMemory(interior)
        scene.interior = interior

        while isPlaceLoadCurrent(session, token) and not IsInteriorReady(interior) and GetGameTimer() < deadline do
            Wait(0)
        end
    end

    while isPlaceLoadCurrent(session, token) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(spot.x, spot.y, spot.z)

        if GetGroundZFor_3dCoord(spot.x, spot.y, spot.z + 1.5, false) then
            break
        end

        Wait(0)
    end

    if not isPlaceLoadCurrent(session, token) then
        return
    end

    car.place(session, true)
    session.camera.skipSmoothing = true
    car.settle(session)
end

local function runFrameLoop(session)
    local handle = session.camera.handle
    local nextWorldRefresh = 0

    while not state.isStale(session) do
        HideHudAndRadarThisFrame()
        ThefeedHideThisFrame()
        camera.keepActive(handle)

        if session.isShooting and BusyspinnerIsOn() then
            BusyspinnerOff()
        end

        look.holdClock(session)

        local isOnLocation = studioSettings.isOnLocation(session.settings)

        if isOnLocation then
            local at = car.spot(session)
            clearLocation(session, at)
            RequestCollisionAtCoord(at.x, at.y, at.z)
        else
            drawBackdrop(session.scene.studioCentre, BACKDROP_COLOURS[session.scene.backdrop])
        end

        if GetGameTimer() > nextWorldRefresh then
            nextWorldRefresh = GetGameTimer() + WORLD_REFRESH_MS
            look.apply(session)

            if isOnLocation then
                local at = car.spot(session)
                SetFocusPosAndVel(at.x, at.y, at.z, 0.0, 0.0, 0.0)
            end
        end

        local vehicle = session.car.entity

        if vehicle and DoesEntityExist(vehicle) then
            local smoothing = 1.0 - math.exp(-GetFrameTime() * CAMERA_SMOOTHING)

            if session.isShooting or session.camera.skipSmoothing then
                smoothing = 1.0
            end

            session.camera.skipSmoothing = false
            camera.glide(session, smoothing)
            car.glide(session, smoothing)
            SetVehicleSteeringAngle(vehicle, session.camera.view.steer + 0.0)

            local isDragging = session.drag ~= nil

            if not isDragging or session.isShooting then
                local from, target, fov = camera.frame(session, smoothing)

                if session.isShooting and not isOnLocation then
                    fov = camera.fillScreen(session, from, target, fov)
                end

                SetCamCoord(handle, from.x, from.y, from.z)
                PointCamAtCoord(handle, target.x, target.y, target.z)
                SetCamFov(handle, fov)
                camera.sendBox(session, camera.projectCar(session, from, target, fov))
            end

            look.drawGlow(session)
            look.updateDepthOfField(session)
        end

        Wait(0)
    end
end

local function garageList()
    local list = {}

    for _, garage in ipairs(config.Garages) do
        list[#list + 1] = { id = garage.id, name = garage.name }
    end

    return list
end

net.on('open', function(data)
    if state.session or type(data) ~= 'table' then
        return
    end

    SetNuiFocus(true, true)

    if not data.allowed then
        nui.send('open', { block = 'noaccess', ace = data.ace, accent = data.accent })
        return
    end

    local ped = cache.ped
    local session = newSession(data, ped)
    state.session = session
    session.camera.view = camera.viewOf(session)

    FreezeEntityPosition(ped, true)
    isPedFrozen = true

    local ownCar = cache.vehicle

    if ownCar then
        FreezeEntityPosition(ownCar, true)
        session.scene.ownCar = ownCar
    end

    look.rememberWeather(session)
    look.holdWorldSync(true)
    look.apply(session)
    camera.create(session)

    nui.send('open', {
        block = not shoot.screenshotResource() and 'noresource' or nil,
        ace = data.ace,
        accent = data.accent,
        studio = data.studio,
        defaults = data.defaults,
        limitKb = data.limitKb,
        queue = queue.view(),
        garages = garageList(),
        places = session.places,
        styles = data.styles,
        images = data.images,
        upload = data.upload,
    })
    net.send('list')

    CreateThread(function()
        loadPlace(session)

        local firstModel = data.model or queue.currentModel() or config.PreviewModel

        if not car.spawn(session, firstModel) and firstModel ~= config.PreviewModel then
            car.spawn(session, config.PreviewModel)
        end
    end)

    CreateThread(function()
        runFrameLoop(session)
    end)
end)

---@param isResourceStopping? boolean
local function close(isResourceStopping)
    queue.pause()

    local session = state.session
    state.session = nil

    SetNuiFocus(false, false)
    nui.send('close')

    if not session then
        return
    end

    car.remove(session)
    camera.destroy(session)
    ClearFocus()
    unpinInterior(session)
    look.restore(session)

    local ped = cache.ped
    local ownCar = session.scene.ownCar

    if ownCar and DoesEntityExist(ownCar) then
        FreezeEntityPosition(ownCar, false)
    end

    if isResourceStopping then
        FreezeEntityPosition(ped, false)
        isPedFrozen = false
        return
    end

    CreateThread(function()
        local at = GetEntityCoords(ped)
        local deadline = GetGameTimer() + COLLISION_TIMEOUT_MS

        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
            RequestCollisionAtCoord(at.x, at.y, at.z)
            Wait(0)
        end

        if not state.session then
            FreezeEntityPosition(ped, false)
            isPedFrozen = false
        end
    end)
end

nui.on('close', function(data, cb)
    cb({ ok = true })

    if state.session and type(data) == 'table' and type(data.settings) == 'table' then
        net.send('studio', data.settings)
    end

    close()
end)

nui.onStudioAction('panel', function(session, data)
    session.camera.panel = {
        x = util.clamp(data.x, -0.5, 0.5, 0.0, 0.001),
        y = util.clamp(data.y, -0.5, 0.5, 0.0, 0.001),
        scale = util.clamp(data.scale, 0.5, 4.0, 1.0, 0.001),
    }
end)

nui.onStudioAction('settings', function(session, data)
    if type(data.settings) ~= 'table' or state.isLocked(session) then
        return
    end

    local before = session.settings
    local settings = studioSettings.sanitize(data.settings)
    session.settings = settings
    car.applySettings(session)

    local hasNewPlace = settings.place ~= before.place or settings.placeId ~= before.placeId
    local mustSitAgain = settings.ride ~= before.ride or (settings.ground == 'on' and before.ground == 'off')

    if hasNewPlace then
        CreateThread(function()
            loadPlace(session)
        end)
    elseif mustSitAgain then
        session.car.rest = nil
        car.settleSoon(session)
    end

    if util.changed(WORLD_KEYS, before, settings) then
        look.apply(session)
    end
end)

nui.onStudioAction('colours', function(session, data)
    session.primary = util.hexColour(data.primary, session.primary)
    session.secondary = util.hexColour(data.secondary, session.secondary)
    car.paintPreview(session)
end)

nui.onStudioAction('save', function(_, data)
    net.send('studio', data.settings)
end)

local function whyNoPreview(session, model)
    if not util.isValidModel(model) then
        return 'Not a vehicle model on this server'
    end

    if state.isQueueRunning then
        return 'Wait for the queue to finish or pause it'
    end

    if session.isShooting then
        return 'A photo is being taken'
    end
end

nui.onStudioAction('preview', function(session, data)
    local model = util.modelName(data.model)

    if model == session.car.model then
        return
    end

    local problem = whyNoPreview(session, model)

    if problem then
        nui.send('nocar', { model = model, error = problem })
        return
    end

    CreateThread(function()
        local vehicle, spawnProblem = car.spawn(session, model)

        if not vehicle and not state.isStale(session) then
            nui.send('nocar', { model = model, error = spawnProblem })
        end
    end)
end)

nui.on('test', function(_, cb)
    local session = state.session

    if not session or not session.car.model then
        cb({ ok = false, error = 'A photo is being taken' })
        return
    end

    local problem = whyNoPreview(session, session.car.model)

    if problem then
        cb({ ok = false, error = problem })
        return
    end

    CreateThread(function()
        local layers, shootProblem = shoot.shoot(session, session.car.model)

        if layers then
            cb({ ok = true, layers = layers })
        else
            cb({ ok = false, error = shootProblem })
        end
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= cache.resource then
        return
    end

    if state.session then
        close(true)
    elseif isPedFrozen then
        FreezeEntityPosition(cache.ped, false)
    end
end)
