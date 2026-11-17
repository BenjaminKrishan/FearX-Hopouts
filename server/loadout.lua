-- Persistent weapon unlocks/equipment and the credit store.
LoadoutServer = {}
local purchaseLocks = {}

local itemById = {}
for _, item in ipairs(Config.LoadoutShop.items) do
    if not itemById[item.id] then itemById[item.id] = item end
end

local function starterItems()
    local owned = {}
    for id, item in pairs(itemById) do
        if item.starter or (item.price or 0) <= 0 then owned[#owned + 1] = id end
    end
    table.sort(owned)
    return owned
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or fallback
end

function LoadoutServer.Default()
    local equipped = {}
    for _, id in ipairs(starterItems()) do
        local item = itemById[id]
        if not equipped[item.role] then equipped[item.role] = id end
    end
    return starterItems(), equipped
end

function LoadoutServer.Read(stats)
    local defaultOwned, defaultEquipped = LoadoutServer.Default()
    local owned = decode(stats.loadout_owned, defaultOwned)
    local equipped = decode(stats.loadout_eq, defaultEquipped)
    local validOwned, seen = {}, {}
    for _, id in ipairs(defaultOwned) do
        if not seen[id] then seen[id] = true; validOwned[#validOwned + 1] = id end
    end
    for _, id in ipairs(owned) do
        if itemById[id] and not seen[id] then
            seen[id] = true; validOwned[#validOwned + 1] = id
        end
    end
    for role, id in pairs(equipped) do
        if not itemById[id] or itemById[id].role ~= role or not seen[id] then equipped[role] = nil end
    end
    for role, id in pairs(defaultEquipped) do
        if not equipped[role] then equipped[role] = id end
    end
    return validOwned, equipped
end

local function publicItem(item)
    return {
        id = item.id, role = item.role, category = item.category, label = item.label,
        kind = item.kind, price = item.price or 0, rarity = item.rarity or 'neutral',
        starter = item.starter == true, image = item.img or HopImages.Url(item.id)
    }
end

function LoadoutServer.Get(src)
    local stats = Hopouts.GetStats(src)
    local owned, equipped = LoadoutServer.Read(stats)
    local items = {}
    for _, item in ipairs(Config.LoadoutShop.items) do items[#items + 1] = publicItem(item) end
    return { ok = true, items = items, owned = owned, equipped = equipped, credits = stats.credits or 0 }
end

local function save(src, owned, equipped)
    MySQL.update.await('UPDATE fx_hopouts_stats SET loadout_owned = ?, loadout_eq = ? WHERE identifier = ?', {
        json.encode(owned), json.encode(equipped), Bridge.GetIdentifier(src)
    })
end

function LoadoutServer.Buy(src, id)
    if purchaseLocks[src] then return { ok = false, reason = 'A purchase is already being processed.' } end
    purchaseLocks[src] = true
    local stats, item = Hopouts.GetStats(src), itemById[id]
    local owned, equipped = LoadoutServer.Read(stats)
    for _, ownedId in ipairs(owned) do
        if ownedId == id then purchaseLocks[src] = nil; return LoadoutServer.Get(src) end
    end
    if not item or not Config.LoadoutShop.enabled then
        purchaseLocks[src] = nil; return { ok = false, reason = 'This weapon is unavailable.' }
    end
    local changed = MySQL.update.await('UPDATE fx_hopouts_stats SET credits = credits - ? WHERE identifier = ? AND credits >= ?', {
        item.price, Bridge.GetIdentifier(src), item.price
    })
    if not changed or changed < 1 then
        purchaseLocks[src] = nil
        return { ok = false, reason = 'Not enough credits.', credits = Hopouts.GetStats(src).credits }
    end
    owned[#owned + 1] = id; equipped[item.role] = id
    save(src, owned, equipped)
    Hopouts.RefreshStats(src)
    purchaseLocks[src] = nil
    local result = LoadoutServer.Get(src); result.ok = true
    return result
end

function LoadoutServer.Equip(src, id)
    local stats, item = Hopouts.GetStats(src), itemById[id]
    local owned, equipped = LoadoutServer.Read(stats)
    local has = false
    for _, ownedId in ipairs(owned) do if ownedId == id then has = true; break end end
    if not item or not has then return { ok = false, reason = 'Unlock this weapon first.' } end
    equipped[item.role] = id
    save(src, owned, equipped)
    return LoadoutServer.Get(src)
end

function LoadoutServer.Kit(src)
    local stats = Hopouts.GetStats(src)
    local _, equipped = LoadoutServer.Read(stats)
    local kit = {}
    for _, role in ipairs({ 'primary', 'secondary', 'equipment' }) do
        local item = equipped[role] and itemById[equipped[role]]
        if item then
            kit[#kit + 1] = {
                name = item.id, role = role, label = item.label, kind = item.kind,
                ammo = item.ammo or Config.Match.ammo[role] or 1,
                img = item.img or HopImages.Url(item.id)
            }
        end
    end
    return kit
end

local function storeItem(item)
    return {
        id = item.id, label = item.label, category = item.category, price = item.price,
        rarity = item.rarity, count = item.count or 1, featured = item.featured,
        image = item.image or (item.item and HopImages.Url(item.item)), icon = item.icon
    }
end

function LoadoutServer.Store(src)
    local items = {}
    if Config.Store.enabled then
        for _, item in ipairs(Config.Store.items) do items[#items + 1] = storeItem(item) end
    end
    return { items = items, credits = Hopouts.GetStats(src).credits or 0 }
end

local function deliver(src, item)
    if item.type == 'money' then
        return Bridge.AddMoney(src, item.account or 'cash', item.amount), 'Money delivery failed.'
    elseif item.type == 'event' and type(item.event) == 'string' then
        TriggerEvent(item.event, src, table.unpack(item.args or {})); return true
    elseif item.type == 'command' and type(item.command) == 'string' then
        local command = item.command:gsub('%%s', tostring(src)):gsub('%%n', GetPlayerName(src) or '')
        ExecuteCommand(command); return true
    end
    return false, 'Invalid store item configuration.'
end

function LoadoutServer.BuyStore(src, id)
    if purchaseLocks[src] then return { ok = false, reason = 'A purchase is already being processed.' } end
    purchaseLocks[src] = true
    local item
    for _, entry in ipairs(Config.Store.items) do if entry.id == id then item = entry; break end end
    if not item or not Config.Store.enabled then
        purchaseLocks[src] = nil; return { ok = false, reason = 'This item is unavailable.' }
    end
    local identifier = Bridge.GetIdentifier(src)
    local changed = MySQL.update.await('UPDATE fx_hopouts_stats SET credits = credits - ? WHERE identifier = ? AND credits >= ?', {
        item.price, identifier, item.price
    })
    if not changed or changed < 1 then
        purchaseLocks[src] = nil
        return { ok = false, reason = 'Not enough credits.', credits = Hopouts.GetStats(src).credits }
    end
    local delivered, reason = deliver(src, item)
    if not delivered then
        MySQL.update.await('UPDATE fx_hopouts_stats SET credits = credits + ? WHERE identifier = ?', { item.price, identifier })
        purchaseLocks[src] = nil
        return { ok = false, reason = reason or 'Delivery failed; your credits were refunded.' }
    end
    Hopouts.RefreshStats(src)
    Bridge.Notify(src, 'Hopouts', ('Purchased %s.'):format(item.label), 'success')
    purchaseLocks[src] = nil
    return { ok = true, credits = Hopouts.GetStats(src).credits }
end
