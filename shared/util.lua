local util = {}

local DATA_URL_PREFIX = #'data:image/webp;base64,'

---Natives answer yes with `true` or `1`.
---@param value any
---@return boolean
function util.isTrue(value)
    return value == true or value == 1
end

---@param value any
---@param low number
---@param high number
---@param fallback any
---@param step? number
---@return number|any
function util.clamp(value, low, high, fallback, step)
    value = tonumber(value)

    if not value or value ~= value then
        return fallback
    end

    step = step or 1
    return math.max(low, math.min(high, math.floor(value / step + 0.5) * step))
end

---@param value any
---@return boolean
function util.isHexColour(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

---@param value any
---@param fallback string
---@return string
function util.hexColour(value, fallback)
    return util.isHexColour(value) and value:lower() or fallback
end

---@param hex string
---@return integer r
---@return integer g
---@return integer b
function util.rgbOf(hex)
    local n = tonumber(tostring(hex or ''):match('^#(%x%x%x%x%x%x)$') or '', 16) or 0
    return math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
end

---@param value any
---@return string
function util.modelName(value)
    return tostring(value or ''):lower()
end

---@param model any
---@return boolean
function util.isValidModel(model)
    return type(model) == 'string' and #model <= 64 and model:match('^[%w_%-]+$') ~= nil
end

---@param dataUrlLength integer
---@return number
function util.base64Bytes(dataUrlLength)
    return (dataUrlLength - DATA_URL_PREFIX) * 3 / 4
end

---@param dataUrlLength integer
---@return integer
function util.dataUrlKb(dataUrlLength)
    return math.floor(util.base64Bytes(dataUrlLength) / 1024 + 0.5)
end

---@param kb number
---@return integer
function util.maxDataUrlLength(kb)
    return math.ceil(kb * 1024 * 4 / 3) + 32
end

---@param entries table
---@return integer
function util.count(entries)
    local count = 0

    for _ in pairs(entries) do
        count += 1
    end

    return count
end

---@generic T : { id: any }
---@param list T[]
---@param id any
---@return T[]
function util.withoutId(list, id)
    local kept = {}

    for _, entry in ipairs(list) do
        if entry.id ~= id then
            kept[#kept + 1] = entry
        end
    end

    return kept
end

---@param keys string[]
---@param before table
---@param after table
---@return boolean
function util.changed(keys, before, after)
    for _, key in ipairs(keys) do
        if before[key] ~= after[key] then
            return true
        end
    end

    return false
end

---@param text any
---@param letters integer
---@return string
function util.truncateUtf8(text, letters)
    text = tostring(text or '')

    if not utf8.len(text) then
        text = text:gsub('[\128-\255]', '')
    end

    local cutAt = utf8.offset(text, letters + 1)
    return cutAt and text:sub(1, cutAt - 1) or text
end

---@param text any
---@param letters integer
---@return string
function util.sanitizeText(text, letters)
    local trimmed = (tostring(text or ''):gsub('[%c<>]', '')):match('^%s*(.-)%s*$')
    return util.truncateUtf8(trimmed, letters)
end

---Starts waiting for an answer that `resolveReply` delivers, or for `timeoutValue` after `timeoutMs`.
---@param pending table<any, promise>
---@param key any
---@param timeoutMs integer
---@param timeoutValue any
---@return promise
function util.expectReply(pending, key, timeoutMs, timeoutValue)
    local job = promise.new()
    pending[key] = job

    SetTimeout(timeoutMs, function()
        if pending[key] == job then
            pending[key] = nil
            job:resolve(timeoutValue)
        end
    end)

    return job
end

---@param pending table<any, promise>
---@param key any
---@param value any
function util.resolveReply(pending, key, value)
    local job = pending[key]
    pending[key] = nil

    if job then
        job:resolve(value)
    end
end

return util
