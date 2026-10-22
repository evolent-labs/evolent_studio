local database = require 'server.database'
local kvp = require 'server.kvp'
local util = require 'shared.util'

local catalog = {}

local function isStarted(resource)
    return GetResourceState(resource) == 'started'
end

local function queryRows(sql)
    local ok, rows = pcall(MySQL.query.await, sql)
    return ok and rows or {}
end

local function displayName(brand, name)
    if type(name) ~= 'string' or name == '' then
        return nil
    end

    local hasBrand = type(brand) == 'string' and brand ~= ''

    if hasBrand and name:sub(1, #brand):lower() ~= brand:lower() then
        return brand .. ' ' .. name
    end

    return name
end

local function addModel(names, model, name)
    if type(model) == 'string' and model ~= '' then
        model = model:lower()
        names[model] = names[model] or name or model
    end
end

local function addVehicleTable(names, vehicles)
    for key, entry in pairs(type(vehicles) == 'table' and vehicles or {}) do
        if type(entry) == 'table' then
            addModel(names, entry.model or key, displayName(entry.brand or entry.make, entry.name))
        end
    end
end

local function frameworkModels()
    local names = {}

    if isStarted('qbx_core') then
        local ok, vehicles = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
        addVehicleTable(names, ok and vehicles)
    elseif isStarted('qb-core') then
        local ok, vehicles = pcall(function() return exports['qb-core']:GetCoreObject().Shared.Vehicles end)
        addVehicleTable(names, ok and vehicles)
    end

    if isStarted('es_extended') then
        for _, row in ipairs(queryRows('SELECT `model`, `name` FROM `vehicles`')) do
            addModel(names, row.model, displayName(nil, row.name))
        end
    end

    if isStarted('ox_core') then
        local ok, vehicles = pcall(json.decode, LoadResourceFile('ox_core', 'common/data/vehicles.json') or '')
        addVehicleTable(names, ok and vehicles)
    end

    return names
end

local function unsignedHash(hash)
    hash = tonumber(hash)
    return hash and hash % 0x100000000 or nil
end

local function addOwners(owned, model, count)
    if type(model) == 'string' and model ~= '' then
        model = model:lower()
        owned[model] = (owned[model] or 0) + (tonumber(count) or 0)
    end
end

local function ownerCounts(names)
    local owned = {}

    if isStarted('qbx_core') or isStarted('qb-core') then
        local sql = 'SELECT `vehicle` AS `model`, COUNT(*) AS `n` FROM `player_vehicles` GROUP BY `vehicle`'

        for _, row in ipairs(queryRows(sql)) do
            addOwners(owned, row.model, row.n)
        end
    end

    if isStarted('es_extended') then
        local modelOfHash = {}

        for model in pairs(names) do
            modelOfHash[unsignedHash(GetHashKey(model))] = model
        end

        local sql = [[SELECT JSON_UNQUOTE(JSON_EXTRACT(`vehicle`, '$.model')) AS `model`, COUNT(*) AS `n`
            FROM `owned_vehicles` WHERE JSON_VALID(`vehicle`) GROUP BY 1]]

        for _, row in ipairs(queryRows(sql)) do
            addOwners(owned, modelOfHash[unsignedHash(row.model)], row.n)
        end
    end

    if isStarted('ox_core') then
        for _, row in ipairs(queryRows('SELECT `model`, COUNT(*) AS `n` FROM `vehicles` GROUP BY `model`')) do
            addOwners(owned, row.model, row.n)
        end
    end

    return owned
end

local function statusOf(photo, failure)
    if photo then
        return 'ready'
    end

    if failure then
        return 'failed'
    end

    return 'missing'
end

---Every model the framework, the addons, the failures and the photos know, sorted by name.
---@return { id: string, name: string, owned: integer, status: string, addon?: true, updatedAt?: integer, url?: string, sizeKb?: integer, error?: string }[]
function catalog.vehicleList()
    local names = frameworkModels()
    local addons = kvp.load('addons')
    local failures = kvp.load('failed')

    for model, name in pairs(addons) do
        if util.isValidModel(model) then
            local hasName = type(name) == 'string' and name ~= ''
            names[model] = names[model] or (hasName and name or model)
        end
    end

    for model in pairs(failures) do
        if util.isValidModel(model) then
            names[model] = names[model] or model
        end
    end

    local photoOf = {}

    for _, row in ipairs(database.photoRows()) do
        photoOf[row.model] = row
        names[row.model] = names[row.model] or row.model
    end

    local owned = ownerCounts(names)

    for model in pairs(owned) do
        names[model] = names[model] or model
    end

    local list = {}

    for model, name in pairs(names) do
        local photo = photoOf[model]
        local failure = failures[model]
        local entry = {
            id = model,
            name = name,
            owned = owned[model] or 0,
            status = statusOf(photo, failure),
            addon = addons[model] ~= nil or nil,
        }

        if photo then
            entry.updatedAt = photo.updated_at
            entry.url = photo.url
            entry.sizeKb = math.max(1, util.dataUrlKb(tonumber(photo.size) or 0))
        elseif type(failure) == 'string' then
            entry.error = failure
        end

        list[#list + 1] = entry
    end

    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)

    return list
end

return catalog
