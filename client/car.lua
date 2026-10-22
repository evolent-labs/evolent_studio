local camera = require 'client.camera'
local config = require 'shared.config'
local nui = require 'client.nui'
local studioSettings = require 'shared.settings'
local state = require 'client.state'
local util = require 'shared.util'

local car = {}

local MODEL_LOAD_TIMEOUT_MS = 10000
local FLOOR_LOAD_TIMEOUT_MS = 3000
local GROUND_PROBE_HEIGHT = 1.5
local GROUND_SNAP_RANGE = 3.0
local REST_POSITION_TOLERANCE = 0.05
local REST_HEADING_TOLERANCE = 0.5
local SETTLE_DROP_HEIGHT = 0.25
local SETTLE_FIRST_WAIT_MS = 250
local SETTLE_TIMEOUT_MS = 2500
local SETTLE_STILL_SPEED = 0.03
local SETTLE_DELAY_MS = 450
local FELL_THROUGH_FLOOR = 1.5
local POSITION_STEP = 0.0005
local HEADING_STEP = 0.01
local WINDOW_COUNT = 4
local NEON_SIDES = 4

local FLOOR_MODELS = { `stt_prop_stunt_bblock_huge_01`, `stt_prop_stunt_bblock_lrg1` }
local TINT_INDEX = { none = 0, light = 3, dark = 2, limo = 5, black = 1 }
local PAINT_FINISH = { gloss = 0, matte = 3 }
local LIGHTS = { off = 1, on = 2 }
local LANDING_GEAR = { down = 0, up = 3 }
local GLIDING = { 'x', 'y', 'z', 'pitch', 'roll' }

---@param model string
---@return integer? hash
---@return string? problem
function car.loadModel(model)
    local hash = joaat(model)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return nil, 'Not a vehicle model on this server'
    end

    if not pcall(lib.requestModel, hash, MODEL_LOAD_TIMEOUT_MS) then
        return nil, 'Model did not load'
    end

    return hash
end

local function exists(vehicle)
    return vehicle ~= nil and DoesEntityExist(vehicle)
end

local function locationBase(session)
    local settings = session.settings
    local places

    if settings.place == 'garage' then
        places = config.Garages
    elseif settings.place == 'saved' then
        places = session.places
    end

    for _, place in ipairs(places or {}) do
        if place.id == settings.placeId then
            return place
        end
    end

    return session.scene.playerSpot
end

function car.resetSpot(session)
    local scene = session.scene
    local base = locationBase(session)
    local heading = (base.h or 0.0) % 360

    if scene.spot then
        scene.turned += camera.angleTo(scene.spot.h, heading)
    end

    scene.spot = { x = base.x, y = base.y, z = base.z, h = heading }
    nui.send('spot', { h = heading })
end

---Where the car stands: the studio centre, or the spot in a real place.
---@param session StudioSession
---@return vector3 at
---@return number heading
---@return boolean isOnGround
function car.spot(session)
    local scene = session.scene

    if not studioSettings.isOnLocation(session.settings) then
        return scene.studioCentre, 0.0, false
    end

    if not scene.spot then
        car.resetSpot(session)
    end

    return vector3(scene.spot.x, scene.spot.y, scene.spot.z), scene.spot.h, true
end

local function placeKey(settings)
    if settings.place == 'green' then
        return 'green'
    end

    return settings.place .. (settings.placeId or '')
end

local function setPose(vehicle, pose)
    SetEntityCoordsNoOffset(vehicle, pose.x, pose.y, pose.z, false, false, false)
    SetEntityRotation(vehicle, pose.pitch, pose.roll, pose.h, 2, false)
end

local function restFits(rest, settings, at, heading, isOnGround)
    if not rest or rest.where ~= placeKey(settings) then
        return false
    end

    if not isOnGround then
        return true
    end

    local isSameX = math.abs(rest.x - at.x) < REST_POSITION_TOLERANCE
    local isSameY = math.abs(rest.y - at.y) < REST_POSITION_TOLERANCE

    return isSameX and isSameY and math.abs(camera.angleTo(rest.h, heading)) < REST_HEADING_TOLERANCE
end

function car.place(session, snap)
    local carState, settings = session.car, session.settings
    local vehicle = carState.entity

    if not exists(vehicle) then
        return
    end

    local at, heading, isOnGround = car.spot(session)
    local z = at.z

    if isOnGround then
        local found, groundZ = GetGroundZFor_3dCoord(at.x, at.y, at.z + GROUND_PROBE_HEIGHT, false)

        if found and math.abs(groundZ - at.z) < GROUND_SNAP_RANGE then
            z = groundZ
        end
    end

    z -= GetModelDimensions(carState.hash).z

    local pitch, roll = 0.0, 0.0

    if restFits(carState.rest, settings, at, heading, isOnGround) then
        z = carState.rest.z
        pitch = carState.rest.pitch
        roll = carState.rest.roll
    end

    carState.goal = {
        x = at.x,
        y = at.y,
        z = z,
        h = heading + 0.0,
        pitch = pitch + settings.pitch,
        roll = roll + settings.roll,
    }

    if carState.isSettling then
        return
    end

    if snap or not carState.pose or session.isShooting then
        carState.pose = {}

        for key, value in pairs(carState.goal) do
            carState.pose[key] = value
        end

        setPose(vehicle, carState.pose)
    end
end

function car.glide(session, smoothing)
    local carState = session.car
    local pose, goal = carState.pose, carState.goal

    if not pose or not goal or not carState.entity or carState.isSettling then
        return
    end

    local hasMoved = false

    for _, key in ipairs(GLIDING) do
        local left = goal[key] - pose[key]

        if math.abs(left) > POSITION_STEP then
            pose[key] += left * smoothing
            hasMoved = true
        end
    end

    local turnLeft = camera.angleTo(pose.h, goal.h)

    if math.abs(turnLeft) > HEADING_STEP then
        pose.h += turnLeft * smoothing
        hasMoved = true
    end

    if hasMoved then
        setPose(carState.entity, pose)
    end
end

local function spawnStudioFloor(session)
    local scene = session.scene

    while scene.isSpawningFloor and not state.isStale(session) do
        Wait(0)
    end

    if exists(scene.floor) or scene.hasNoFloor then
        return
    end

    scene.isSpawningFloor = true

    for _, hash in ipairs(FLOOR_MODELS) do
        if IsModelInCdimage(hash) then
            local isLoaded = pcall(lib.requestModel, hash, FLOOR_LOAD_TIMEOUT_MS)

            if state.isStale(session) then
                scene.isSpawningFloor = false
                return
            end

            if isLoaded then
                local low, high = GetModelDimensions(hash)
                local centre = scene.studioCentre
                local floor = CreateObjectNoOffset(
                    hash,
                    centre.x - (low.x + high.x) / 2,
                    centre.y - (low.y + high.y) / 2,
                    centre.z - high.z,
                    false,
                    false,
                    false
                )

                SetModelAsNoLongerNeeded(hash)
                FreezeEntityPosition(floor, true)
                SetEntityVisible(floor, false, false)
                scene.floor = floor
                scene.isSpawningFloor = false
                return
            end
        end
    end

    scene.isSpawningFloor = false
    scene.hasNoFloor = true
end

local function ignoreCollisionsWithScene(session, vehicle)
    SetEntityNoCollisionEntity(vehicle, cache.ped, false)

    local ownCar = session.scene.ownCar

    if exists(ownCar) then
        SetEntityNoCollisionEntity(vehicle, ownCar, false)
    end

    for _, entity in ipairs(session.scene.hiddenEntities) do
        if DoesEntityExist(entity) then
            SetEntityNoCollisionEntity(vehicle, entity, false)
        end
    end
end

local function hasGoalMoved(from, to)
    if math.abs(from.x - to.x) > REST_POSITION_TOLERANCE or math.abs(from.y - to.y) > REST_POSITION_TOLERANCE then
        return true
    end

    return math.abs(camera.angleTo(from.h, to.h)) > REST_HEADING_TOLERANCE
end

local function isStillTheCar(session, vehicle)
    return not state.isStale(session) and session.car.entity == vehicle
end

---Drops the car onto the ground and keeps the pose it comes to rest in.
---@param session StudioSession
function car.settle(session)
    local carState, settings = session.car, session.settings
    local vehicle = carState.entity

    if state.isStale(session) or not exists(vehicle) or carState.isSettling or session.isShooting or not carState.goal then
        return
    end

    local isOnLocation = studioSettings.isOnLocation(settings)

    if isOnLocation and settings.ground == 'off' then
        return
    end

    if not isOnLocation then
        if carState.rest and carState.rest.where == 'green' then
            car.place(session)
            return
        end

        spawnStudioFloor(session)

        if not isStillTheCar(session, vehicle) then
            return
        end
    end

    carState.isSettling = true

    local goal = carState.goal

    SetEntityCoordsNoOffset(vehicle, goal.x, goal.y, goal.z + SETTLE_DROP_HEIGHT, false, false, false)
    SetEntityRotation(vehicle, 0.0, 0.0, goal.h, 2, false)
    ignoreCollisionsWithScene(session, vehicle)
    SetEntityCollision(vehicle, true, true)
    FreezeEntityPosition(vehicle, false)
    SetVehicleOnGroundProperly(vehicle)

    local deadline = GetGameTimer() + SETTLE_TIMEOUT_MS
    Wait(SETTLE_FIRST_WAIT_MS)

    while isStillTheCar(session, vehicle) and GetGameTimer() < deadline do
        if #GetEntityVelocity(vehicle) <= SETTLE_STILL_SPEED then
            break
        end

        Wait(50)
    end

    if not isStillTheCar(session, vehicle) then
        return
    end

    if not DoesEntityExist(vehicle) then
        carState.isSettling = false
        return
    end

    FreezeEntityPosition(vehicle, true)
    SetEntityCollision(vehicle, false, false)

    local at = GetEntityCoords(vehicle)
    local rotation = GetEntityRotation(vehicle, 2)

    if goal.z - at.z < FELL_THROUGH_FLOOR then
        carState.rest = {
            x = goal.x,
            y = goal.y,
            h = goal.h,
            z = at.z,
            pitch = rotation.x,
            roll = rotation.y,
            where = placeKey(settings),
        }
    end

    carState.isSettling = false
    car.place(session, true)

    if isOnLocation and hasGoalMoved(goal, carState.goal) then
        car.settle(session)
    end
end

function car.settleSoon(session)
    local token = GetGameTimer()
    session.car.settleToken = token

    SetTimeout(SETTLE_DELAY_MS, function()
        if not state.isStale(session) and session.car.settleToken == token then
            car.settle(session)
        end
    end)
end

local function openDoors(settings)
    local isOpen = {}

    for _, door in ipairs(settings.doors) do
        isOpen[door] = true
    end

    return isOpen
end

local function carKeyOf(settings, isOpen)
    local doors = {}

    for door = 0, studioSettings.DOOR_COUNT - 1 do
        doors[#doors + 1] = isOpen[door] and '1' or '0'
    end

    return table.concat({
        settings.lights,
        settings.roof,
        settings.windows,
        settings.cabin,
        settings.ride,
        settings.plate,
        settings.neon,
        settings.neonColour,
        settings.tint,
        settings.indicators,
        settings.gear,
        settings.paint,
        table.concat(doors),
    }, '|')
end

local function applyToVehicle(vehicle, settings, isOpen, isAircraft, instantly)
    SetVehicleLights(vehicle, LIGHTS[settings.lights])

    if IsVehicleAConvertible(vehicle, false) then
        if settings.roof == 'down' then
            LowerConvertibleRoof(vehicle, instantly)
        else
            RaiseConvertibleRoof(vehicle, instantly)
        end
    end

    for door = 0, studioSettings.DOOR_COUNT - 1 do
        if isOpen[door] then
            SetVehicleDoorOpen(vehicle, door, false, instantly)
        else
            SetVehicleDoorShut(vehicle, door, instantly)
        end
    end

    for window = 0, WINDOW_COUNT - 1 do
        if settings.windows == 'down' then
            RollDownWindow(vehicle, window)
        else
            RollUpWindow(vehicle, window)
        end
    end

    SetVehicleInteriorlight(vehicle, settings.cabin == 'on')

    if SetVehicleSuspensionHeight then
        SetVehicleSuspensionHeight(vehicle, -settings.ride / 100.0)
    end

    SetVehicleNumberPlateText(vehicle, settings.plate ~= '' and settings.plate or ' ')

    for side = 0, NEON_SIDES - 1 do
        SetVehicleNeonLightEnabled(vehicle, side, settings.neon == 'on')
    end

    SetVehicleNeonLightsColour(vehicle, util.rgbOf(settings.neonColour))
    SetVehicleWindowTint(vehicle, TINT_INDEX[settings.tint] or 0)

    local finish = PAINT_FINISH[settings.paint]

    SetVehicleModColor_1(vehicle, finish, 0, 0)
    SetVehicleModColor_2(vehicle, finish, 0)
    SetVehicleIndicatorLights(vehicle, 0, settings.indicators == 'right' or settings.indicators == 'both')
    SetVehicleIndicatorLights(vehicle, 1, settings.indicators == 'left' or settings.indicators == 'both')

    if isAircraft then
        ControlLandingGear(vehicle, LANDING_GEAR[settings.gear])
    end
end

function car.applySettings(session)
    local carState, settings, cache = session.car, session.settings, session.cache

    if not exists(carState.entity) then
        return
    end

    local isOpen = openDoors(settings)
    local carKey = carKeyOf(settings, isOpen)

    if carKey ~= cache.carKey then
        local instantly = cache.carKey == nil or session.isShooting
        cache.carKey = carKey
        applyToVehicle(carState.entity, settings, isOpen, carState.isAircraft, instantly)
    end

    car.place(session)
end

function car.paintPreview(session)
    local vehicle = session.car.entity

    if not exists(vehicle) or session.isShooting then
        return
    end

    SetVehicleCustomPrimaryColour(vehicle, util.rgbOf(session.primary))
    SetVehicleCustomSecondaryColour(vehicle, util.rgbOf(session.secondary))
end

---Swaps the studio car for the model and sets it down.
---@param session StudioSession
---@param model string
---@return integer? vehicle
---@return string? problem
function car.spawn(session, model)
    local hash, problem = car.loadModel(model)

    if not hash then
        return nil, problem
    end

    if state.isStale(session) then
        return nil, 'The menu was closed'
    end

    local carState = session.car

    if exists(carState.entity) then
        DeleteEntity(carState.entity)
    end

    local centre = session.scene.studioCentre
    local vehicle = CreateVehicle(hash, centre.x, centre.y, centre.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    if vehicle == 0 then
        return nil, 'Model did not load'
    end

    FreezeEntityPosition(vehicle, true)
    SetEntityCollision(vehicle, false, false)
    SetVehicleModKit(vehicle, 0)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineOn(vehicle, false, true, true)

    local _, wheelColour = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, 0, wheelColour)

    carState.entity = vehicle
    carState.model = model
    carState.hash = hash
    carState.pose = nil
    carState.rest = nil
    carState.isSettling = false
    carState.isAircraft = util.isTrue(IsThisModelAPlane(hash)) or util.isTrue(IsThisModelAHeli(hash))
    session.cache.carKey = nil

    car.applySettings(session)
    car.paintPreview(session)
    car.settle(session)

    if not isStillTheCar(session, vehicle) then
        return nil, 'Another car was picked meanwhile'
    end

    nui.send('model', { model = model, isAircraft = carState.isAircraft })

    return vehicle
end

function car.remove(session)
    if exists(session.car.entity) then
        DeleteEntity(session.car.entity)
    end

    if exists(session.scene.floor) then
        DeleteEntity(session.scene.floor)
    end
end

return car
