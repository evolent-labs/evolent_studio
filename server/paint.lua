local PALETTE = {
    [0] = '080808', '0F0F0F', '1C1E21', '292C2E', '5A5E66', '777C87', '515459', '323B47', '333333', '1F2226',
    '23292E', '121110', '050505', '121212', '2F3233', '080808', '121212', '202224', '575961', '23292E',
    '323B47', '0F1012', '212121', '5B5D5E', '888A99', '697187', '3B4654', '690000', '8A0B00', '6B0000',
    '611009', '4A0A0A', '470E0E', '380C00', '26030B', '630012', '802800', '6E4F2D', 'BD4800', '780000',
    '360000', 'AB3F00', 'DE7E00', '520000', '8C0404', '4A1000', '592525', '754231', '210804', '001207',
    '001A0B', '00211E', '1F261E', '003805', '0B4145', '418503', '0F1F15', '023613', '162419', '2A3625',
    '455C56', '000D14', '001029', '1C2F4F', '001B57', '3B4E78', '272D3B', '95B2DB', '3E627A', '1C3140',
    '0055C4', '1A182E', '161629', '0E316D', '395A83', '09142E', '0F1021', '152A52', '324654', '152563',
    '223BA1', '1F1FA1', '030E2E', '0F1E73', '001C32', '2A3754', '303C5E', '3B6796', 'F5890F', 'D9A600',
    '4A341B', 'A2A827', '568F00', '57514B', '291B06', '262117', '120D07', '332111', '3D3023', '5E5343',
    '37382B', '221918', '575036', '241309', '3B1700', '6E6246', '998D73', 'CFC0A5', '1F1709', '3D311D',
    '665847', 'F0F0F0', 'B3B9C9', '615F55', '241E1A', '171413', '3B372F', '3B4045', '1A1E21', '5E646B',
    '000000', 'B0B0B0', '999999', 'B56519', 'C45C33', '47783C', 'BA8425', '2A77A1', '243022', '6B5F54',
    'C96E34', 'D9D9D9', 'F0F0F0', '3F4228', 'FFFFFF', 'B01259', 'F69799', '8F2F55', 'C26610', '69BD45',
    '00AEEF', '000108', '050008', '080000', '565751', '320642', '00080F', '080808', '320642', '050008',
    '6B0B00', '121710', '323325', '3B352D', '706656', '2B302B', '414347', '6690B5', '47391B', '47391B',
    'FFD859',
}

local function toByte(value)
    return math.max(0, math.min(255, math.floor(value)))
end

local function colourOf(paint)
    if type(paint) == 'number' then
        local colour = PALETTE[math.floor(paint)]
        return colour and ('#' .. colour) or nil
    end

    if type(paint) == 'table' then
        local r = tonumber(paint.r or paint[1])
        local g = tonumber(paint.g or paint[2])
        local b = tonumber(paint.b or paint[3])

        if r and g and b then
            return ('#%02X%02X%02X'):format(toByte(r), toByte(g), toByte(b))
        end
    end

    return nil
end

---Reads the paint of saved vehicle properties (a table or its JSON).
---@param properties table|string|nil
---@return { primary: string, secondary: string }?
local function paintOf(properties)
    if type(properties) == 'string' then
        local ok, decoded = pcall(json.decode, properties)
        properties = ok and decoded or nil
    end

    if type(properties) ~= 'table' then
        return nil
    end

    local primary = colourOf(properties.customPrimaryColor) or colourOf(properties.color1)
    local secondary = colourOf(properties.customSecondaryColor) or colourOf(properties.color2)

    if not primary then
        return nil
    end

    return { primary = primary, secondary = secondary or primary }
end

exports('GetPaint', paintOf)
