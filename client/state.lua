---@class StudioSession
---@field settings StudioSettings
---@field places table[]
---@field primary string
---@field secondary string
---@field isShooting boolean
---@field drag? { isSpin?: boolean, dx?: number, dy?: number }
---@field car table
---@field camera table
---@field scene table
---@field cache table

local state = {
    ---@type StudioSession?
    session = nil,
    isQueueRunning = false,
}

---True once the menu was closed or opened again since `session` started.
---@param session StudioSession
---@return boolean
function state.isStale(session)
    return state.session ~= session
end

---True while a photo is taken or the queue runs, when the studio must not change.
---@param session StudioSession
---@return boolean
function state.isLocked(session)
    return session.isShooting or state.isQueueRunning
end

return state
