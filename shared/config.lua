local config = require 'config'

local FALLBACK = {
    Ace = 'evolent.studio',
    Command = 'evstudio',
    Accent = '#C3FF00',
    StudioSpot = vector3(-3500.0, -3500.0, 300.0),
    PreviewModel = 'sultanrs',
    MaxLayerKB = 150,
    Studio = {},
    Garages = {},
    Images = {},
}

for key, value in pairs(FALLBACK) do
    if type(config[key]) ~= type(value) then
        config[key] = value
    end
end

return config
