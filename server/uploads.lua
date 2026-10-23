local kvp = require 'server.kvp'
local studioSettings = require 'shared.settings'
local util = require 'shared.util'

local uploads = {}

local MAX_URL_LENGTH = 500
local MIN_KEY_LENGTH = 8
local MAX_KEY_LENGTH = 200
local SERVICES = { off = true, fivemanage = true, discord = true, folder = true }
local FORMATS = { webp = true, png = true }
local NEEDS_KEY = { fivemanage = true, discord = true }
local SERVICE_NAMES = { fivemanage = 'Fivemanage', discord = 'Discord' }
local FILE_EXTENSION = { webp = 'webp', png = 'png', jpeg = 'jpg' }

local BASE64_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local base64Value = {}

for index = 1, #BASE64_ALPHABET do
    base64Value[BASE64_ALPHABET:byte(index)] = index - 1
end

local function decodeBase64(text)
    text = text:gsub('=', '')

    local chunks = {}
    local count = 0

    for index = 1, #text - 3, 4 do
        local a, b, c, d = text:byte(index, index + 3)
        local bits = base64Value[a] << 18 | base64Value[b] << 12 | base64Value[c] << 6 | base64Value[d]
        count += 1
        chunks[count] = string.char(bits >> 16, bits >> 8 & 255, bits & 255)
    end

    local leftover = #text % 4

    if leftover == 2 then
        local a, b = text:byte(#text - 1, #text)
        chunks[count + 1] = string.char((base64Value[a] << 18 | base64Value[b] << 12) >> 16)
    elseif leftover == 3 then
        local a, b, c = text:byte(#text - 2, #text)
        local bits = base64Value[a] << 18 | base64Value[b] << 12 | base64Value[c] << 6
        chunks[count + 1] = string.char(bits >> 16, bits >> 8 & 255)
    end

    return table.concat(chunks)
end

local function imageBytes(dataUrl)
    return decodeBase64(dataUrl:match(',(.*)$'))
end

local function isDiscordWebhook(link)
    local host, path = link:match('^https://([%a%.]+)(/api/webhooks/%d+/[%w_%-]+)$')

    if not path then
        return false
    end

    local base = host:match('^%a+%.(discord%.com)$') or host:match('^%a+%.(discordapp%.com)$') or host

    return base == 'discord.com' or base == 'discordapp.com'
end

local function isUsableKey(service, key)
    if #key < MIN_KEY_LENGTH or #key > MAX_KEY_LENGTH or key:find('[%c"\\]') then
        return false
    end

    return service ~= 'discord' or isDiscordWebhook(key)
end

local function keyConvar(service)
    return (GetConvar('evolent_studio:' .. service, ''):gsub('%s', ''))
end

local function keyOf(service)
    if not NEEDS_KEY[service] then
        return ''
    end

    local key = keyConvar(service)

    return isUsableKey(service, key) and key or ''
end

for service in pairs(NEEDS_KEY) do
    if keyConvar(service) ~= '' and keyOf(service) == '' then
        lib.print.warn(('evolent_studio:%s in server.cfg is not a valid %s key'):format(service, SERVICE_NAMES[service]))
    end
end

---The upload settings as the menu shows them; the key itself is never sent.
---@return table
function uploads.view()
    local saved = kvp.load('upload')
    local service = SERVICES[saved.service] and saved.service or 'off'
    local key = keyOf(service)

    return {
        service = service,
        auto = saved.auto == true,
        format = FORMATS[saved.format] and saved.format or 'webp',
        primary = util.hexColour(saved.primary, studioSettings.DEFAULT_PRIMARY),
        secondary = util.hexColour(saved.secondary, studioSettings.DEFAULT_SECONDARY),
        hasToken = key ~= '' or service == 'folder',
        tokenEnd = key ~= '' and key:sub(-4) or nil,
    }
end

---@param input table
function uploads.saveSettings(input)
    local current = uploads.view()
    local service = SERVICES[input.service] and input.service or current.service
    local auto = current.auto

    if input.auto ~= nil then
        auto = input.auto == true
    end

    kvp.save('upload', {
        service = service,
        auto = auto,
        format = FORMATS[input.format] and input.format or current.format,
        primary = util.hexColour(input.primary, current.primary),
        secondary = util.hexColour(input.secondary, current.secondary),
    })
end

local function failureText(service, status, reply)
    local name = SERVICE_NAMES[service]

    if status == 401 or status == 403 then
        return name .. ' did not accept the key'
    end

    if status == 404 and service == 'discord' then
        return 'That Discord webhook does not exist any more'
    end

    if status == 413 then
        return 'The picture is too big for ' .. name
    end

    if status == 429 then
        return name .. ' is busy, wait a minute and try again'
    end

    local said = type(reply) == 'table' and (reply.error or reply.message)

    if type(said) == 'string' then
        return util.sanitizeText(said, 80)
    end

    return ('Upload failed (%s)'):format(tostring(status))
end

local function handleUploadResponse(service, status, body, linkFrom, done)
    local isJson, reply = pcall(json.decode, body or '')

    if not isJson or type(reply) ~= 'table' then
        reply = nil
    end

    local url = reply and linkFrom(reply)
    local isSuccess = status == 200 or status == 201

    if isSuccess and type(url) == 'string' and url:match('^https://') and #url <= MAX_URL_LENGTH then
        done(url)
    else
        done(nil, failureText(service, status, reply))
    end
end

local function fivemanageLink(reply)
    return type(reply.data) == 'table' and reply.data.url
end

local function discordLink(reply)
    local attachment = type(reply.attachments) == 'table' and reply.attachments[1]
    return type(attachment) == 'table' and attachment.url
end

local SENDERS = {}

function SENDERS.fivemanage(model, dataUrl, extension, key, done)
    local body = json.encode({
        base64 = dataUrl,
        filename = ('%s.%s'):format(model, extension),
        metadata = json.encode({ name = model, description = 'Evolent Studio' }),
    })

    PerformHttpRequest('https://api.fivemanage.com/api/v3/file/base64', function(status, response, _, errorBody)
        handleUploadResponse('fivemanage', status, response or errorBody, fivemanageLink, done)
    end, 'POST', body, { ['Authorization'] = key, ['Content-Type'] = 'application/json' })
end

function SENDERS.discord(model, dataUrl, extension, webhook, done)
    local base64 = dataUrl:match(',(.*)$')

    exports[cache.resource]:sendToDiscord(webhook, model, extension, base64, function(status, body)
        handleUploadResponse('discord', status, body, discordLink, done)
    end)
end

function SENDERS.folder(model, dataUrl, extension, _, done)
    local bytes = imageBytes(dataUrl)
    local resource = cache.resource
    local file = ('photos/%s.%s'):format(model, extension)

    if util.isTrue(SaveResourceFile(resource, file, bytes, #bytes)) then
        done(('https://cfx-nui-%s/%s'):format(resource, file))
    else
        done(nil, 'Could not write to the photos folder of the resource')
    end
end

---Sends the picture to the chosen service; `done(url)` or `done(nil, problem)` follows.
---@param model string
---@param dataUrl string
---@param done fun(url?: string, problem?: string)
function uploads.send(model, dataUrl, done)
    local format = dataUrl:match('^data:image/(%a+);base64,[%w%+/=]+$')
    local extension = FILE_EXTENSION[format]

    if not extension then
        return done(nil, 'The picture could not be read')
    end

    local service = uploads.view().service
    local send = SENDERS[service]
    local key = keyOf(service)

    if not send or (NEEDS_KEY[service] and key == '') then
        return done(nil, 'Pick where to save in Settings and set its key in server.cfg')
    end

    send(model, dataUrl, extension, key, done)
end

return uploads
