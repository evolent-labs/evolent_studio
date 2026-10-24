local config = require 'config'
local util = require 'shared.util'

local net = {}

local PREFIX = 'evolent_studio:'
local LATENT_BPS = 200000

---@param name string
---@param handler function
function net.on(name, handler)
    RegisterNetEvent(PREFIX .. name, handler)
end

if lib.context == 'server' then
    ---@param playerId integer
    ---@return boolean
    function net.isAdmin(playerId)
        return util.isTrue(IsPlayerAceAllowed(playerId, config.Ace))
    end

    ---A net event that only players with the ace can trigger.
    ---@param name string
    ---@param handler fun(playerId: integer, ...)
    function net.onAdmin(name, handler)
        RegisterNetEvent(PREFIX .. name, function(...)
            local playerId = source

            if net.isAdmin(playerId) then
                handler(playerId, ...)
            end
        end)
    end

    ---A callback that only players with the ace get an answer from; anyone else gets `false`.
    ---@param name string
    ---@param handler fun(playerId: integer, ...): ...
    function net.onAdminCallback(name, handler)
        lib.callback.register(PREFIX .. name, function(playerId, ...)
            if not net.isAdmin(playerId) then return false end

            return handler(playerId, ...)
        end)
    end

    ---@param playerId integer
    ---@param name string
    function net.send(playerId, name, ...)
        TriggerClientEvent(PREFIX .. name, playerId, ...)
    end

    ---For payloads too big for a normal event: photo layers, lists.
    ---@param playerId integer
    ---@param name string
    function net.sendLarge(playerId, name, ...)
        TriggerLatentClientEvent(PREFIX .. name, playerId, LATENT_BPS, ...)
    end
else
    ---@param name string
    function net.send(name, ...)
        TriggerServerEvent(PREFIX .. name, ...)
    end

    ---For payloads too big for a normal event: photo layers, uploads.
    ---@param name string
    function net.sendLarge(name, ...)
        TriggerLatentServerEvent(PREFIX .. name, LATENT_BPS, ...)
    end

    ---Asks the server and waits for its answer.
    ---@param name string
    ---@return ...
    function net.await(name, ...)
        return lib.callback.await(PREFIX .. name, false, ...)
    end
end

return net
