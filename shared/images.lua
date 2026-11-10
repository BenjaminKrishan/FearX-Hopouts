HopImages = {}

local SCAN = {
    'ox_inventory',
    'qb-inventory',
    'ps-inventory',
    'lj-inventory',
    'qs-inventory',
    'core_inventory',
    'codem-inventory',
    'origen_inventory',
    'tgiann-inventory',
    'ak47_inventory',
    'jpr-inventory'
}

local FALLBACK = 'nui://ox_inventory/web/images/%s.png'

local function imageMap()
    return (Config.UI and Config.UI.itemImages) or {}
end

local function fromBridge()
    if Bridge and Bridge.InventoryName then
        local name = Bridge.InventoryName()
        if type(name) == 'string' and name ~= '' then return name end
    end
    if Bridge and Bridge.GetInventory then
        local name = Bridge.GetInventory()
        if type(name) == 'string' and name ~= '' then return name end
    end
    local ok, name = pcall(function() return exports.fearx_bridge:GetInventory() end)
    if ok and type(name) == 'string' and name ~= '' then return name end
    return nil
end

local function fromRunning()
    for i = 1, #SCAN do
        if GetResourceState(SCAN[i]) == 'started' then return SCAN[i] end
    end
    return 'ox_inventory'
end

function HopImages.Inventory()
    local name = fromBridge()
    if name and name ~= 'none' and name ~= 'auto' then return name end
    return fromRunning()
end

function HopImages.Pattern()
    local override = Config.UI and Config.UI.itemImage
    if type(override) == 'string' and override ~= '' and override ~= 'auto' then
        return override
    end
    local map = imageMap()
    local inv = HopImages.Inventory()
    return map[inv] or map['ox_inventory'] or FALLBACK
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
