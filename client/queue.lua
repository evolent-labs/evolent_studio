local config = require 'shared.config'
local net = require 'shared.net'
local nui = require 'client.nui'
local photos = require 'client.photos'
local shoot = require 'client.shoot'
local state = require 'client.state'
local util = require 'shared.util'

local queue = {}

local SAVE_TIMEOUT_MS = 60000

local active
local pendingSaves = {}

---The queue as the page shows it, or nil when there is none.
---@return table?
function queue.view()
    if not active then
        return nil
    end

    return {
        status = active.status,
        done = active.done,
        total = active.total,
        current = active.current,
        layer = active.layer,
        list = active.list,
        ok = active.ok,
        fail = active.fail,
        failed = active.failed,
    }
end

local function sendToPage()
    nui.send('queue', { queue = queue.view() })
end

---@return string?
function queue.currentModel()
    return active?.current
end

net.on('saved', function(model, ok, problem)
    util.resolveReply(pendingSaves, model, { ok = ok, error = problem })
end)

local function isOverSizeLimit(layers)
    local longest = util.maxDataUrlLength(config.MaxLayerKB)

    for _, layer in pairs(layers) do
        if type(layer) == 'string' and #layer > longest then
            return true
        end
    end

    return false
end

local function biggestLayerKb(layers)
    local biggest = 0

    for _, layer in pairs(layers) do
        if type(layer) == 'string' then
            biggest = math.max(biggest, util.dataUrlKb(#layer))
        end
    end

    return biggest
end

local function photograph(session, job, model)
    local layers, problem = shoot.shoot(session, model, function(step)
        job.layer = step
        sendToPage()
    end)

    if not layers then
        return false, problem
    end

    if isOverSizeLimit(layers) then
        return false, 'Photo over size limit'
    end

    local reply = util.expectReply(pendingSaves, model, SAVE_TIMEOUT_MS, { ok = false })
    net.sendLarge('save', model, layers)
    local answer = Citizen.Await(reply)

    if not answer.ok then
        return false, answer.error or 'Could not be saved'
    end

    photos.forget(model)

    return true, nil, biggestLayerKb(layers)
end

local function recordResult(job, model, ok, problem, sizeKb)
    if ok then
        job.ok += 1
        nui.send('row', { id = model, status = 'ready', updatedAt = GetCloudTimeAsInt(), sizeKb = sizeKb })
    else
        job.fail += 1
        job.failed[#job.failed + 1] = { id = model, error = problem }
        net.send('failed', model, problem)
        nui.send('row', { id = model, status = 'failed', error = problem })
    end

    job.done += 1
    job.current = nil
end

local function run()
    if state.isQueueRunning then
        return
    end

    state.isQueueRunning = true

    CreateThread(function()
        while active?.status == 'running' and state.session do
            local job, session = active, state.session
            local model = table.remove(job.list, 1)

            if not model then
                job.status = 'done'
                break
            end

            job.current = model
            job.layer = 1
            sendToPage()

            while session.isShooting and not state.isStale(session) do
                Wait(100)
            end

            local ran, ok, problem, sizeKb = pcall(photograph, session, job, model)

            if not ran then
                lib.print.error(('photo of %s failed: %s'):format(model, tostring(ok)))
                session.isShooting = false
                ok = false
                problem = 'Something went wrong, see the F8 console'
            end

            if state.isStale(session) then
                table.insert(job.list, 1, model)
                job.current = nil
                break
            end

            recordResult(job, model, ok, problem, sizeKb)
            sendToPage()
        end

        state.isQueueRunning = false

        if state.session then
            sendToPage()

            if active?.status == 'running' then
                run()
            end
        end
    end)
end

---Adds the models to the running queue, or starts a new one.
---@param models any
function queue.start(models)
    local isActive = active ~= nil and active.status ~= 'done'
    local alreadyQueued = {}

    if isActive then
        for _, model in ipairs(active.list) do
            alreadyQueued[model] = true
        end
    end

    if active?.current then
        alreadyQueued[active.current] = true
    end

    local added = {}

    for _, model in ipairs(type(models) == 'table' and models or {}) do
        model = util.modelName(model)

        if util.isValidModel(model) and not alreadyQueued[model] then
            alreadyQueued[model] = true
            added[#added + 1] = model
        end
    end

    if #added == 0 then
        return
    end

    if isActive then
        for _, model in ipairs(added) do
            active.list[#active.list + 1] = model
        end

        active.total += #added
    else
        active = {
            status = 'running',
            list = added,
            done = 0,
            total = #added,
            ok = 0,
            fail = 0,
            failed = {},
            layer = 1,
            current = nil,
        }
    end

    sendToPage()
    run()
end

function queue.pause()
    if active?.status == 'running' then
        active.status = 'paused'
    end
end

local function retryFailed()
    local models = {}

    for _, entry in ipairs(active.failed) do
        models[#models + 1] = entry.id
    end

    active = nil
    queue.start(models)
end

local ACTIONS = {
    pause = function()
        if active.status == 'running' then
            active.status = 'paused'
        end
    end,
    resume = function()
        if active.status == 'paused' then
            active.status = 'running'
            run()
        end
    end,
    stop = function()
        if active.status ~= 'done' then
            active.status = 'done'
            active.list = {}
        end
    end,
    retry = function()
        if active.status == 'done' then
            retryFailed()
        end
    end,
    dismiss = function()
        if active.status == 'done' then
            active = nil
        end
    end,
}

nui.on('queue', function(data, cb)
    cb({ ok = true })

    local act = type(data) == 'table' and ACTIONS[data.action]

    if active and act then
        act()
        sendToPage()
    end
end)

nui.onStudioAction('start', function(_, data)
    queue.start(data.models)
end)

return queue
