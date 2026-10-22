local kvp = {}

---Reads a JSON table saved under `key`, or an empty table.
---@param key string
---@return table
function kvp.load(key)
    local ok, value = pcall(json.decode, GetResourceKvpString(key) or '')

    if ok and type(value) == 'table' then
        return value
    end

    return {}
end

---@param key string
---@param value table
function kvp.save(key, value)
    SetResourceKvp(key, json.encode(value))
end

return kvp
