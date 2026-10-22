local car = require 'client.car'
local nui = require 'client.nui'
local studioSettings = require 'shared.settings'
local state = require 'client.state'
local util = require 'shared.util'

local shoot = {}

local REPAINT_WAIT_MS = 700
local SCREENSHOT_TIMEOUT_MS = 15000
local SCREENSHOT_RESOURCES = { 'screencapture', 'screenshot-basic' }

local SHOTS = {
    { key = 'black', primary = { 0, 0, 0 }, secondary = { 0, 0, 0 } },
    { key = 'primary', primary = { 255, 255, 255 }, secondary = { 0, 0, 0 } },
    { key = 'secondary', primary = { 0, 0, 0 }, secondary = { 255, 255, 255 } },
}
local CUTTING_STEP = #SHOTS + 1

---The screenshot resource that is running, if any.
---@return string?
function shoot.screenshotResource()
    for _, name in ipairs(SCREENSHOT_RESOURCES) do
        if GetResourceState(name) == 'started' then
            return name
        end
    end
end

local pendingScreenshot = {}

local function takeScreenshot(resource)
    local reply = util.expectReply(pendingScreenshot, 'shot', SCREENSHOT_TIMEOUT_MS, nil)

    exports[resource]:requestScreenshot({ encoding = 'png' }, function(image)
        if pendingScreenshot.shot == reply then
            util.resolveReply(pendingScreenshot, 'shot', image)
        end
    end)

    return Citizen.Await(reply)
end

local function takeShots(session, vehicle, model, resource, onLayer)
    local shots = {}

    for step, shot in ipairs(SHOTS) do
        if onLayer then
            onLayer(step)
        end

        nui.send('shooting', { on = true, layer = step, model = model })
        SetVehicleCustomPrimaryColour(vehicle, shot.primary[1], shot.primary[2], shot.primary[3])
        SetVehicleCustomSecondaryColour(vehicle, shot.secondary[1], shot.secondary[2], shot.secondary[3])
        Wait(REPAINT_WAIT_MS)

        if state.isStale(session) then
            return nil, 'The menu was closed'
        end

        if not DoesEntityExist(vehicle) or session.car.entity ~= vehicle then
            return nil, 'Another car was picked meanwhile'
        end

        shots[shot.key] = takeScreenshot(resource)

        if state.isStale(session) then
            return nil, 'The menu was closed'
        end

        if type(shots[shot.key]) ~= 'string' then
            return nil, 'The screenshot resource did not answer'
        end
    end

    return shots
end

---Spawns the model, takes the three shots and has the page cut them into layers.
---@param session StudioSession
---@param model string
---@param onLayer? fun(step: integer)
---@return table? layers
---@return string? problem
function shoot.shoot(session, model, onLayer)
    local resource = shoot.screenshotResource()

    if not resource then
        return nil, 'Screenshot resource not running'
    end

    if session.isShooting then
        return nil, 'A photo is being taken'
    end

    local vehicle, problem = car.spawn(session, model)

    if not vehicle then
        return nil, problem
    end

    if state.isStale(session) then
        return nil, 'The menu was closed'
    end

    session.isShooting = true
    local shots, shotProblem = takeShots(session, vehicle, model, resource, onLayer)
    session.isShooting = false

    if not shots then
        if not state.isStale(session) then
            nui.send('shooting', { on = false })
        end

        return nil, shotProblem
    end

    car.paintPreview(session)
    nui.send('shooting', { on = true, layer = CUTTING_STEP, model = model })

    local result = nui.requestFromPage({
        action = 'cut',
        shots = shots,
        width = session.settings.width,
        scene = studioSettings.isOnLocation(session.settings),
        model = model,
        box = session.camera.box,
        foot = session.camera.footprint,
    })

    if not state.isStale(session) then
        nui.send('shooting', { on = false })
    end

    if type(result) ~= 'table' then
        return nil, 'The photo could not be cut out'
    end

    if not result.ok then
        return nil, result.error or 'The photo could not be cut out'
    end

    return result.layers
end

return shoot
