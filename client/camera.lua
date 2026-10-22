local nui = require 'client.nui'
local studioSettings = require 'shared.settings'

local camera = {}

local FIT_MARGIN = 1.03
local MIN_STUDIO_DISTANCE = 100
local WALL_GAP = 0.3
local MIN_REACH = 0.5
local REACH_RECOVERY = 2.0
local BEHIND_CAMERA = 0.05
local BOX_MARGIN = 0.01
local BOX_RESEND_MS = 500
local BOX_CHANGED = 0.00002
local BOX_MOVED = 0.001
local FOOT_WIDTH = 0.94
local FOOT_CORNER_SHARE = 0.15
local FOOT_CORNER_MAX = 0.3
local GROUND_RAY_LENGTH = 500.0
local WHOLE_SCREEN = { 0.0, 0.0, 1.0, 1.0 }
local GLIDING = { 'height', 'fov', 'distance', 'shiftX', 'shiftY', 'steer' }
local UP = vector3(0.0, 0.0, 1.0)

local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function cross(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

---The shortest turn in degrees from one heading to another, between -180 and 180.
---@param from number
---@param to number
---@return number
function camera.angleTo(from, to)
    return (to - from + 180.0) % 360.0 - 180.0
end

local function modelMiddle(car)
    local low, high = GetModelDimensions(car.hash)

    return GetOffsetFromEntityInWorldCoords(
        car.entity,
        (low.x + high.x) / 2,
        (low.y + high.y) / 2,
        (low.z + high.z) / 2
    )
end

function camera.create(session)
    local handle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local centre = session.scene.studioCentre

    SetCamCoord(handle, centre.x, centre.y - 6.0, centre.z + 1.0)
    PointCamAtCoord(handle, centre.x, centre.y, centre.z)
    RenderScriptCams(true, false, 0, true, true)
    session.camera.handle = handle

    return handle
end

function camera.destroy(session)
    local handle = session.camera.handle

    if handle then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(handle, false)
    end
end

function camera.keepActive(handle)
    if GetRenderingCam() ~= handle then
        SetCamActive(handle, true)
        RenderScriptCams(true, false, 0, true, true)
    end
end

function camera.viewOf(session)
    local settings, panel = session.settings, session.camera.panel
    local view = {
        rot = settings.rot,
        turned = session.scene.turned,
        panelX = panel.x,
        panelY = panel.y,
        panelScale = panel.scale,
    }

    for _, key in ipairs(GLIDING) do
        view[key] = settings[key]
    end

    return view
end

function camera.glide(session, smoothing)
    local view, settings = session.camera.view, session.settings

    view.rot += camera.angleTo(view.rot, settings.rot) * smoothing
    view.turned += (session.scene.turned - view.turned) * smoothing

    for _, key in ipairs(GLIDING) do
        view[key] += (settings[key] - view[key]) * smoothing
    end

    local panel = session.isShooting and camera.NO_PANEL or session.camera.panel

    view.panelX += (panel.x - view.panelX) * smoothing
    view.panelY += (panel.y - view.panelY) * smoothing
    view.panelScale += (panel.scale - view.panelScale) * smoothing
end

camera.NO_PANEL = { x = 0.0, y = 0.0, scale = 1.0 }

local function reachBeforeWalls(session, middle, from, smoothing)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(
        middle.x, middle.y, middle.z,
        from.x, from.y, from.z,
        1 + 16, session.car.entity, 7
    )
    local _, hit, hitAt = GetShapeTestResult(probe)
    local toCamera = from - middle
    local length = #toCamera
    local free = length

    if hit == 1 then
        free = math.max(MIN_REACH, #(hitAt - middle) - WALL_GAP)
    end

    local reach = session.camera.reach or free

    if free < reach then
        reach = free
    else
        reach += (free - reach) * math.min(1.0, smoothing * REACH_RECOVERY)
    end

    session.camera.reach = reach

    if reach < length and length > 0.01 then
        return middle + toCamera / length * reach
    end

    return from
end

---Where the camera stands and looks for the current view.
---@param session StudioSession
---@param smoothing number
---@return vector3 from
---@return vector3 target
---@return number fov
function camera.frame(session, smoothing)
    local car, view = session.car, session.camera.view
    local low, high = GetModelDimensions(car.hash)
    local middle = modelMiddle(car)
    local fov = view.fov + 0.0
    local halfFov = math.rad(fov / 2)
    local isOnLocation = studioSettings.isOnLocation(session.settings)
    local closeness = isOnLocation and view.distance or math.max(MIN_STUDIO_DISTANCE, view.distance)
    local distance = #(high - low) / 2 / math.sin(halfFov) * FIT_MARGIN * closeness / 100 * view.panelScale

    local yaw, pitch = math.rad(view.rot), math.rad(view.height)
    local carHeading = car.pose?.h or car.goal?.h or GetEntityRotation(car.entity, 2).z
    local heading = math.rad(carHeading - view.turned)
    local localX = -math.sin(yaw) * math.cos(pitch)
    local localY = math.cos(yaw) * math.cos(pitch)
    local toCamera = vector3(
        localX * math.cos(heading) - localY * math.sin(heading),
        localX * math.sin(heading) + localY * math.cos(heading),
        math.sin(pitch))

    local shiftX = view.panelX
    local shiftY = view.panelY

    if isOnLocation then
        shiftX += view.shiftX / 100
        shiftY += view.shiftY / 100
    end

    local screenHeight = 2.0 * distance * math.tan(halfFov)
    local target = middle
    local sideways = vector3(-toCamera.y, toCamera.x, 0.0)

    if #sideways > 0.01 then
        target -= sideways / #sideways * shiftX * screenHeight * GetAspectRatio(false)
    end

    target -= UP * shiftY * screenHeight

    local from = target + toCamera * distance

    if isOnLocation then
        from = reachBeforeWalls(session, middle, from, smoothing)
    end

    return from, target, fov
end

local function screenBasis(from, to, fov)
    local ahead = to - from

    if #ahead < 0.001 then
        return nil
    end

    ahead = ahead / #ahead

    local right = vector3(ahead.y, -ahead.x, 0.0)
    right = #right > 0.001 and right / #right or vector3(1.0, 0.0, 0.0)
    local screenHeight = math.tan(math.rad(fov / 2)) * 2.0

    return {
        from = from,
        ahead = ahead,
        right = right,
        up = cross(right, ahead),
        height = screenHeight,
        width = screenHeight * GetAspectRatio(false),
    }
end

local function projectToScreen(point, basis)
    local offset = point - basis.from
    local depth = dot(offset, basis.ahead)

    if depth < BEHIND_CAMERA then
        return nil
    end

    return 0.5 + dot(offset, basis.right) / depth / basis.width, 0.5 - dot(offset, basis.up) / depth / basis.height
end

local function projectModelBox(car, basis)
    local low, high = GetModelDimensions(car.hash)
    local x0, y0, x1, y1 = 1.0, 1.0, 0.0, 0.0

    for _, x in ipairs({ low.x, high.x }) do
        for _, y in ipairs({ low.y, high.y }) do
            for _, z in ipairs({ low.z, high.z }) do
                local sx, sy = projectToScreen(GetOffsetFromEntityInWorldCoords(car.entity, x, y, z), basis)

                if not sx then
                    return WHOLE_SCREEN
                end

                x0 = math.min(x0, sx)
                x1 = math.max(x1, sx)
                y0 = math.min(y0, sy)
                y1 = math.max(y1, sy)
            end
        end
    end

    return {
        math.max(0.0, x0 - BOX_MARGIN),
        math.max(0.0, y0 - BOX_MARGIN),
        math.min(1.0, x1 + BOX_MARGIN),
        math.min(1.0, y1 + BOX_MARGIN),
    }
end

local function projectFootprint(session, basis)
    local car = session.car
    local low, high = GetModelDimensions(car.hash)
    local left, right = low.x * FOOT_WIDTH, high.x * FOOT_WIDTH
    local rear, front = low.y, high.y
    local corner = math.min(FOOT_CORNER_MAX, (right - left) * FOOT_CORNER_SHARE)
    local outline = {
        { left, rear + corner }, { left + corner, rear }, { right - corner, rear }, { right, rear + corner },
        { right, front - corner }, { right - corner, front }, { left + corner, front }, { left, front - corner },
    }
    local floorZ = not studioSettings.isOnLocation(session.settings) and session.scene.studioCentre.z or nil
    local footprint = {}

    for _, corner2d in ipairs(outline) do
        local at = GetOffsetFromEntityInWorldCoords(car.entity, corner2d[1], corner2d[2], low.z)
        local sx, sy = projectToScreen(vector3(at.x, at.y, floorZ or at.z), basis)

        if not sx then
            return nil
        end

        footprint[#footprint + 1] = { sx, sy }
    end

    return footprint
end

function camera.projectCar(session, from, to, fov)
    local basis = screenBasis(from, to, fov)

    if not basis then
        return WHOLE_SCREEN, nil
    end

    local box = projectModelBox(session.car, basis)

    if box == WHOLE_SCREEN then
        return box, nil
    end

    return box, projectFootprint(session, basis)
end

function camera.sendBox(session, box, footprint)
    local cameraState = session.camera
    local hasChanged = cameraState.box == nil
    local hasMoved = cameraState.movedBox == nil

    for i = 1, 4 do
        hasChanged = hasChanged or math.abs(cameraState.box[i] - box[i]) > BOX_CHANGED
        hasMoved = hasMoved or math.abs(cameraState.movedBox[i] - box[i]) > BOX_MOVED
    end

    if hasMoved then
        cameraState.movedBox = box
    end

    if hasChanged or GetGameTimer() > cameraState.boxSentAt then
        cameraState.box = box
        cameraState.footprint = footprint
        cameraState.boxSentAt = GetGameTimer() + BOX_RESEND_MS
        nui.send('carbox', { box = box, foot = footprint, moved = hasMoved })
    end
end

function camera.screenRay(session, screenX, screenY)
    local handle = session.camera.handle
    local from = GetCamCoord(handle)
    local rotation = GetCamRot(handle, 2)
    local fov = GetCamFov(handle)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local forward = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
    local up = cross(right, forward)
    local halfHeight = math.tan(math.rad(fov / 2))
    local halfWidth = halfHeight * GetAspectRatio(false)
    local direction = forward + right * ((screenX - 0.5) * 2 * halfWidth) + up * ((0.5 - screenY) * 2 * halfHeight)

    return from, direction / #direction
end

function camera.groundAt(session, screenX, screenY)
    local from, direction = camera.screenRay(session, screenX, screenY)
    local to = from + direction * GROUND_RAY_LENGTH
    local probe = StartExpensiveSynchronousShapeTestLosProbe(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        1, session.car.entity, 7
    )
    local _, hit, hitAt = GetShapeTestResult(probe)

    if hit == 1 then
        return hitAt
    end
end

---True when the point on the screen (0 to 1) is over the car's bounding box.
---@param session StudioSession
---@param screenX number
---@param screenY number
---@return boolean
function camera.isOnCar(session, screenX, screenY)
    local car = session.car

    if not car.entity or not DoesEntityExist(car.entity) then
        return false
    end

    local from, direction = camera.screenRay(session, screenX, screenY)
    local origin = GetOffsetFromEntityGivenWorldCoords(car.entity, from.x, from.y, from.z)
    local ahead = GetOffsetFromEntityGivenWorldCoords(
        car.entity,
        from.x + direction.x,
        from.y + direction.y,
        from.z + direction.z
    ) - origin
    local low, high = GetModelDimensions(car.hash)
    local enter, leave = -math.huge, math.huge

    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        local step, start = ahead[axis], origin[axis]

        if math.abs(step) < 1e-6 then
            if start < low[axis] or start > high[axis] then
                return false
            end
        else
            local near = (low[axis] - start) / step
            local far = (high[axis] - start) / step

            if near > far then
                near, far = far, near
            end

            enter = math.max(enter, near)
            leave = math.min(leave, far)

            if enter > leave then
                return false
            end
        end
    end

    return leave > 0
end

return camera
