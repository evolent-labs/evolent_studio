local state = require 'client.state'
local util = require 'shared.util'

local nui = {}

local PAGE_REPLY_TIMEOUT_MS = 60000

local pendingReplies = {}
local lastRequestId = 0

---@param kind string
---@param data? table
function nui.send(kind, data)
    data = data or {}
    data.type = kind
    SendNUIMessage(data)
end

---Sends a job to the page and waits for its answer; nil after the timeout.
---@param message table
---@return table?
function nui.requestFromPage(message)
    lastRequestId += 1
    message.id = lastRequestId

    local job = util.expectReply(pendingReplies, lastRequestId, PAGE_REPLY_TIMEOUT_MS, nil)
    SendNUIMessage(message)

    return Citizen.Await(job)
end

RegisterNUICallback('done', function(data, cb)
    cb({ ok = true })

    if type(data) == 'table' then
        util.resolveReply(pendingReplies, data.id, data)
    end
end)

---@param name string
---@param handler fun(data: any, cb: function)
function nui.on(name, handler)
    RegisterNUICallback(name, handler)
end

---A page action that only runs while the studio is open; the page gets its answer at once.
---@param name string
---@param handler fun(session: StudioSession, data: table)
function nui.onStudioAction(name, handler)
    RegisterNUICallback(name, function(data, cb)
        cb({ ok = true })

        local session = state.session

        if session and type(data) == 'table' then
            handler(session, data)
        end
    end)
end

return nui
