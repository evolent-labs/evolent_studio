local studioSettings = require 'shared.settings'
local util = require 'shared.util'

local database = {}

local RETRY_MS = 5000
local LAYER_CACHE_LIMIT = 20
local LAYER_KEYS = { 'black', 'primary', 'secondary' }
local LATER_COLUMNS = {
    { name = 'size', definition = 'INT NOT NULL DEFAULT 0' },
    { name = 'fix', definition = 'VARCHAR(120) NULL' },
    { name = 'url', definition = 'VARCHAR(500) NULL' },
}

local versionOf = {}
local urlOf = {}
local modelOfHash = {}
local layerCache = {}
local isReady = false

database.LAYER_KEYS = LAYER_KEYS

local function rememberPhoto(model, version)
    versionOf[model] = version
    modelOfHash[GetHashKey(model)] = model
end

local function tableExists(name)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = ?',
        { name }
    )

    return (count or 0) > 0
end

local function migrate()
    if tableExists('evolent_vehicle_photos') and not tableExists('evolent_studio_photos') then
        MySQL.query.await('RENAME TABLE `evolent_vehicle_photos` TO `evolent_studio_photos`')
    end

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `evolent_studio_photos` (
        `model` VARCHAR(64) NOT NULL PRIMARY KEY,
        `black` MEDIUMTEXT NOT NULL,
        `primary_layer` MEDIUMTEXT NOT NULL,
        `secondary_layer` MEDIUMTEXT NOT NULL,
        `updated_at` INT NOT NULL,
        `size` INT NOT NULL DEFAULT 0,
        `fix` VARCHAR(120) NULL,
        `url` VARCHAR(500) NULL
    )]])

    local existing = {}
    local columns = MySQL.query.await([[SELECT `COLUMN_NAME` AS `name` FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'evolent_studio_photos']])

    for _, column in ipairs(columns or {}) do
        existing[column.name] = true
    end

    for _, column in ipairs(LATER_COLUMNS) do
        if not existing[column.name] then
            local sql = 'ALTER TABLE `evolent_studio_photos` ADD COLUMN `%s` %s'
            MySQL.query.await(sql:format(column.name, column.definition))
        end
    end

    MySQL.query.await('ALTER TABLE `evolent_studio_photos` MODIFY COLUMN `url` VARCHAR(500) NULL')
    MySQL.query.await([[UPDATE `evolent_studio_photos` SET `size` = GREATEST(LENGTH(`black`), LENGTH(`primary_layer`),
        LENGTH(`secondary_layer`)) WHERE `size` = 0]])
end

local function loadPhotoIndex()
    local rows = MySQL.query.await('SELECT `model`, `updated_at`, `url` FROM `evolent_studio_photos`')

    for _, row in ipairs(rows or {}) do
        rememberPhoto(row.model, row.updated_at)
        urlOf[row.model] = row.url
    end
end

CreateThread(function()
    while true do
        local ok, problem = pcall(function()
            migrate()
            loadPhotoIndex()
        end)

        if ok then
            break
        end

        lib.print.warn(('database not ready, trying again: %s'):format(problem))
        Wait(RETRY_MS)
    end

    isReady = true
end)

---Waits until the table exists and the photo index is loaded.
function database.waitReady()
    lib.waitFor(function() return isReady or nil end, nil, false)
end

---@param model string
---@return integer?
function database.versionOf(model)
    return versionOf[model]
end

local function modelFromHash(hash)
    return modelOfHash[hash] or modelOfHash[hash - 0x100000000] or modelOfHash[hash + 0x100000000]
end

local function modelFrom(nameOrHash)
    if type(nameOrHash) == 'number' then
        nameOrHash = modelFromHash(nameOrHash)
    end

    return util.modelName(nameOrHash)
end

---@return { model: string, updated_at: integer, size: integer, url: string? }[]
function database.photoRows()
    local ok, rows = pcall(MySQL.query.await, 'SELECT `model`, `updated_at`, `size`, `url` FROM `evolent_studio_photos`')
    return ok and rows or {}
end

---@param model string
---@param layers { black: string, primary: string, secondary: string, fix?: table }
---@return boolean
function database.savePhoto(model, layers)
    local version = math.max(os.time(), (versionOf[model] or 0) + 1)
    local size = math.max(#layers.black, #layers.primary, #layers.secondary)
    local fix = studioSettings.sanitizeFix(layers.fix)

    local ok = pcall(MySQL.query.await, [[INSERT INTO `evolent_studio_photos`
        (`model`, `black`, `primary_layer`, `secondary_layer`, `updated_at`, `size`, `fix`) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `black` = VALUES(`black`), `primary_layer` = VALUES(`primary_layer`),
        `secondary_layer` = VALUES(`secondary_layer`), `updated_at` = VALUES(`updated_at`), `size` = VALUES(`size`),
        `fix` = VALUES(`fix`), `url` = NULL]],
        { model, layers.black, layers.primary, layers.secondary, version, size, fix and json.encode(fix) or nil })

    if not ok then
        return false
    end

    rememberPhoto(model, version)
    urlOf[model] = nil

    return true
end

---@param model string
function database.deletePhoto(model)
    MySQL.query.await('DELETE FROM `evolent_studio_photos` WHERE `model` = ?', { model })

    versionOf[model] = nil
    layerCache[model] = nil
    urlOf[model] = nil
end

---@param model string
---@param url string
function database.setUrl(model, url)
    MySQL.update('UPDATE `evolent_studio_photos` SET `url` = ? WHERE `model` = ?', { url, model })
    urlOf[model] = url
end

local function dropOldestCached()
    local oldest

    for model, entry in pairs(layerCache) do
        if not oldest or entry.usedAt < layerCache[oldest].usedAt then
            oldest = model
        end
    end

    layerCache[oldest] = nil
end

local function readLayers(model)
    local sql = 'SELECT `black`, `primary_layer`, `secondary_layer`, `fix` FROM `evolent_studio_photos` WHERE `model` = ?'
    local ok, row = pcall(MySQL.single.await, sql, { model })

    if not ok then
        return nil
    end

    if not row then
        return false
    end

    local fix

    if row.fix then
        local decoded, value = pcall(json.decode, row.fix)
        fix = decoded and studioSettings.sanitizeFix(value) or nil
    end

    return { black = row.black, primary = row.primary_layer, secondary = row.secondary_layer, fix = fix }
end

---The stored layers, `false` when the model has none, `nil` when the database did not answer.
---@param model string
---@return table|false|nil
function database.layersOf(model)
    local version = versionOf[model]
    local cached = layerCache[model]

    if cached and cached.version == version then
        cached.usedAt = GetGameTimer()
        return cached.layers
    end

    local layers = readLayers(model)

    if layers == nil then
        return nil
    end

    layerCache[model] = { version = version, layers = layers, usedAt = GetGameTimer() }

    if util.count(layerCache) > LAYER_CACHE_LIMIT then
        dropOldestCached()
    end

    return layers
end

exports('GetVersion', function(model)
    return versionOf[modelFrom(model)]
end)

exports('HasPhoto', function(model)
    return versionOf[modelFrom(model)] ~= nil
end)

exports('GetUrl', function(model)
    return urlOf[modelFrom(model)]
end)

return database
