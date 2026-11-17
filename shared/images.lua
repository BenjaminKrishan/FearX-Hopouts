HopImages = {}

local FALLBACK = 'nui://qb-inventory/html/images/%s.png'

function HopImages.Pattern()
    local override = Config.UI and Config.UI.itemImage
    if type(override) == 'string' and override ~= '' and override ~= 'auto' then
        return override
    end
    local map = (Config.UI and Config.UI.itemImages) or {}
    return map['qb'] or map['qb-inventory'] or FALLBACK
end

function HopImages.Url(name)
    if type(name) ~= 'string' or name == '' then return nil end
    local file = name
    local case = Config.UI and Config.UI.itemImageCase or 'lower'
    if case == 'lower' then
        file = name:lower()
    elseif case == 'upper' then
        file = name:upper()
    end
    return HopImages.Pattern():format(file)
end
