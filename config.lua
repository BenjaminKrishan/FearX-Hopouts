--[[═══════════════════════════════════════════════════════════════════════════
    FearX-Hopouts — ranked street duels (open-source edition)
    QBCore + ox_lib + oxmysql only. Maps live in config_maps.lua.
═══════════════════════════════════════════════════════════════════════════]]--

Config = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  FRAMEWORK
--
--  Uses QBCore player objects directly. Persistent stats are keyed by the
--  character's citizenid. ox_inventory is supported automatically when running;
--  otherwise QBCore's own PlayerData.items inventory is used.
-- ═══════════════════════════════════════════════════════════════════════════

Config.Command = 'hopouts'
Config.LeaveCommand = 'hopoutleave' -- forfeit the match you're in
Config.KeyMapping = { enabled = true, key = 'F7' }

-- ═══════════════════════════════════════════════════════════════════════════
--  BRANDING — logos, images and colours
--  Everything here is pushed straight into the NUI, so a colour change is a
--  config edit + resource restart. Colours accept hex ('#RRGGBB' / '#RGB').
-- ═══════════════════════════════════════════════════════════════════════════

Config.UI = {
    title = 'HOPOUTS',              -- big word in the top-left
    subtitle = 'League',            -- small word under it
    modeName = 'Hop Outs',          -- shown on the launch panel

    -- Images. Paths are relative to html/, or use any nui:// or https:// URL.
    logo = 'img/fearx-watermark.png', -- brand mark in the top nav
    slotBanner = 'img/fearx-banner.png', -- backdrop behind your own party slot
    defaultAvatar = 'img/logo.png', -- fallback player picture
    jackpotIcon = 'img/jackpot.png',
    monthlyTrophy = 'img/trophy.png',
    trophyGold = 'img/trophy-gold.png',
    trophySilver = 'img/trophy-silver.png',
    trophyBronze = 'img/trophy-bronze.png',
    -- Rank badge path. %s is replaced with the tier's `name` below.
    rankBadge = 'img/rank-%s.png',
    -- Where item / weapon pictures are read from (loadout, store, match HUD).
    -- 'auto' = detect ox_inventory or QBCore's item-image path. Or set a full
    -- nui:// path with %s for the item name to force one.
    itemImage = 'auto',
    -- lower · upper · keep  — ox_inventory images are almost always lower-case.
    itemImageCase = 'lower',
    -- Folder each inventory keeps its item pictures in. Edit a path if yours
    -- moved, or add a new resource name if you run something not listed.
    itemImages = {
        ['ox_inventory'] = 'nui://ox_inventory/web/images/%s.png',
        ['qb-inventory'] = 'nui://qb-inventory/html/images/%s.png',
        ['ps-inventory'] = 'nui://ps-inventory/html/images/%s.png',
        ['lj-inventory'] = 'nui://lj-inventory/html/images/%s.png',
        ['qs-inventory'] = 'nui://qs-inventory/html/images/%s.png',
        ['core_inventory'] = 'nui://core_inventory/html/img/%s.png',
        ['codem-inventory'] = 'nui://codem-inventory/html/itemimages/%s.png',
        ['origen_inventory'] = 'nui://origen_inventory/html/images/%s.png',
        ['tgiann-inventory'] = 'nui://tgiann-inventory/inventory_images/images/%s.png',
        ['ak47_inventory'] = 'nui://ak47_inventory/web/images/%s.png',
        ['jpr-inventory'] = 'nui://jpr-inventory/html/images/%s.png',
        ['esx'] = 'nui://ox_inventory/web/images/%s.png',
        ['qb'] = 'nui://qb-inventory/html/images/%s.png',
        ['none'] = 'nui://ox_inventory/web/images/%s.png'
    },

    colors = {
        accent = '#FFFFFF',     -- buttons, active tabs, highlights, glows
        accentText = '#0A0A0A', -- text printed on top of the accent colour
        text = '#EFEFEF',       -- body text
        background = '#0A0A0A', -- scrims and page backdrop
        panel = '#111111',      -- card / panel fill

        teamRed = '#C53131',    -- team 1 + danger states
        teamBlue = '#0D52D5',   -- team 2
        positive = '#22FF00',   -- gains, online dots
        credits = '#FFD700',    -- hopout credits, party crowns, queued state
        ready = '#BAFA25',      -- ready-check accepted colour

        podiumGold = '#FFC828', -- leaderboard #1
        podiumSilver = '#E1E4EB', -- #2
        podiumBronze = '#DE803A'  -- #3
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
--  PAGES — what shows in the top nav
-- ═══════════════════════════════════════════════════════════════════════════

Config.Pages = {
    career = true,      -- your lifetime hopouts record
    leaderboard = true, -- hopouts leaderboard
    ranks = true,       -- rank ladder page (also needs Config.Ranks.enabled)
    loadout = true,     -- unlock / equip match weapons with hopout credits
    store = true        -- hopout credits store (also needs Config.Store.enabled)
}

-- ═══════════════════════════════════════════════════════════════════════════
--  LOBBY
-- ═══════════════════════════════════════════════════════════════════════════

Config.LobbySpot = vector4(-738.25, 259.47, 135.73, 190.60)
Config.ExitSpot = vector4(-3809.38, -2182.99, 2293.04, 359.96) -- where closing hopouts drops you (nil = return to where you opened it)
Config.LobbyFadeMs = 400
Config.RoutingBucketBase = 10000 -- each match gets an isolated instance
Config.MaxParty = 5             -- party slots in the lobby
Config.MaxQueueSize = 3         -- biggest team that can queue (1v1 … 3v3)
Config.PartyInviteCooldown = 10 -- seconds between party invites (per inviter, regardless of target)
Config.Friends = true           -- friends list + party invites panel

Config.LobbyCam = {
    dist = 8.0,
    fov = 45.0,
    height = 1.5,
    aim = 0.6
}
Config.LobbySlotOffsets = {
    [1] = { x = 0.0, y = 0.0 },
    [2] = { x = -1.4, y = 0.0 },
    [3] = { x = -2.8, y = 0.0 },
    [4] = { x = 1.4, y = 0.0 },
    [5] = { x = 2.8, y = 0.0 }
}

-- Ready check: once two groups are paired, every player on BOTH sides has to
-- accept before the match starts. A side where everyone accepted keeps its
-- place at the front of the queue if the check fails; a side that didn't is
-- dropped out of the queue.
Config.ReadyCheck = {
    enabled = true,
    seconds = 25
}

-- ═══════════════════════════════════════════════════════════════════════════
--  MATCH
-- ═══════════════════════════════════════════════════════════════════════════

Config.RoundsToWin = 5
Config.RoundTime = 300000
Config.CountdownMs = 5000
Config.IntermissionMs = 4500
Config.EndScreenMs = 5000
Config.RoundArmor = 100

Config.Match = {
    -- Back up the player's complete QBCore/ox_inventory in fx_hopouts_inv and
    -- restore it after the match. Backups also restore after reconnect/restart.
    -- Turn off only if your server handles match inventories externally.
    clearInventory = true,
    -- Block QBCore/ox_inventory UI for the duration of the match.
    lockInventory = true,
    -- Give match weapons natively (recommended: this is what makes every
    -- player's kit identical).
    nativeWeapons = true,
    unlimitedAmmo = true,
    ammo = {
        primary = 150,
        secondary = 60,
        equipment = 1
    },
    -- Hand the loadout back if an inventory's weapon guard strips it mid-round.
    -- Costs one HasPedGotWeapon check per weapon twice a second.
    loadoutWatchdog = true,
    -- Use qb-ambulancejob's revive event when available, then reset its death
    -- flags. A native resurrect is used when no supported ambulance is running.
    useAmbulanceRevive = true
}

-- Match weapons are given natively (never as inventory items) with unlimited ammo.
-- role: primary (key 1), secondary (key 2), equipment (key 3 — cycles if several)
--
-- Everyone gets the identical kit, so these are picked for feel rather than
-- power. Swap in your own server weapons here; `img` is optional and defaults
-- to the ox_inventory image for that weapon name.
Config.Loadout = {
    { name = 'WEAPON_CARBINERIFLE', role = 'primary', label = 'Carbine Rifle', kind = 'Assault Rifle', ammo = 250 },
    { name = 'WEAPON_PISTOL', role = 'secondary', label = 'Pistol', kind = 'Handgun', ammo = 100 },
    { name = 'WEAPON_SWITCHBLADE', role = 'equipment', label = 'Switchblade', kind = 'Melee' }
}

-- Unlockable match weapons. Starter kit above is always owned. Credits from
-- matches buy the rest; the equipped trio is what you spawn with in a hopout.
-- role: primary (1) · secondary (2) · equipment (3)
Config.LoadoutShop = {
    enabled = true,
    categories = { 'rifles', 'smgs', 'shotguns', 'snipers', 'pistols', 'melee' },
    items = {
        { id = 'WEAPON_CARBINERIFLE', role = 'primary', category = 'rifles', label = 'Carbine Rifle', kind = 'Assault Rifle', ammo = 250, price = 0, rarity = 'neutral', starter = true },
        { id = 'WEAPON_ASSAULTRIFLE', role = 'primary', category = 'rifles', label = 'Assault Rifle', kind = 'Assault Rifle', ammo = 250, price = 80, rarity = 'rare' },
        { id = 'WEAPON_SPECIALCARBINE', role = 'primary', category = 'rifles', label = 'Special Carbine', kind = 'Assault Rifle', ammo = 250, price = 140, rarity = 'epic' },
        { id = 'WEAPON_ADVANCEDRIFLE', role = 'primary', category = 'rifles', label = 'Advanced Rifle', kind = 'Assault Rifle', ammo = 250, price = 160, rarity = 'epic' },
        { id = 'WEAPON_BULLPUPRIFLE', role = 'primary', category = 'rifles', label = 'Bullpup Rifle', kind = 'Assault Rifle', ammo = 250, price = 150, rarity = 'epic' },
        { id = 'WEAPON_COMPACTRIFLE', role = 'primary', category = 'rifles', label = 'Compact Rifle', kind = 'Assault Rifle', ammo = 200, price = 70, rarity = 'rare' },
        { id = 'WEAPON_MILITARYRIFLE', role = 'primary', category = 'rifles', label = 'Military Rifle', kind = 'Assault Rifle', ammo = 250, price = 220, rarity = 'legendary' },
        { id = 'WEAPON_TACTICALRIFLE', role = 'primary', category = 'rifles', label = 'Tactical Rifle', kind = 'Assault Rifle', ammo = 250, price = 240, rarity = 'legendary' },
        { id = 'WEAPON_HEAVYRIFLE', role = 'primary', category = 'rifles', label = 'Heavy Rifle', kind = 'Assault Rifle', ammo = 250, price = 260, rarity = 'legendary' },
        { id = 'WEAPON_BATTLERIFLE', role = 'primary', category = 'rifles', label = 'Battle Rifle', kind = 'Assault Rifle', ammo = 250, price = 280, rarity = 'exotic' },
        { id = 'WEAPON_SMG', role = 'primary', category = 'smgs', label = 'SMG', kind = 'SMG', ammo = 250, price = 90, rarity = 'rare' },
        { id = 'WEAPON_ASSAULTSMG', role = 'primary', category = 'smgs', label = 'Assault SMG', kind = 'SMG', ammo = 250, price = 130, rarity = 'epic' },
        { id = 'WEAPON_COMBATPDW', role = 'primary', category = 'smgs', label = 'Combat PDW', kind = 'SMG', ammo = 250, price = 150, rarity = 'epic' },
        { id = 'WEAPON_MICROSMG', role = 'primary', category = 'smgs', label = 'Micro SMG', kind = 'SMG', ammo = 200, price = 60, rarity = 'neutral' },
        { id = 'WEAPON_MINISMG', role = 'primary', category = 'smgs', label = 'Mini SMG', kind = 'SMG', ammo = 200, price = 70, rarity = 'rare' },
        { id = 'WEAPON_MACHINEPISTOL', role = 'primary', category = 'smgs', label = 'Machine Pistol', kind = 'SMG', ammo = 200, price = 80, rarity = 'rare' },
        { id = 'WEAPON_GUSENBERG', role = 'primary', category = 'smgs', label = 'Gusenberg', kind = 'SMG', ammo = 250, price = 170, rarity = 'legendary' },
        { id = 'WEAPON_PUMPSHOTGUN', role = 'primary', category = 'shotguns', label = 'Pump Shotgun', kind = 'Shotgun', ammo = 80, price = 70, rarity = 'rare' },
        { id = 'WEAPON_SAWNOFFSHOTGUN', role = 'primary', category = 'shotguns', label = 'Sawed-Off', kind = 'Shotgun', ammo = 80, price = 55, rarity = 'neutral' },
        { id = 'WEAPON_BULLPUPSHOTGUN', role = 'primary', category = 'shotguns', label = 'Bullpup Shotgun', kind = 'Shotgun', ammo = 80, price = 140, rarity = 'epic' },
        { id = 'WEAPON_ASSAULTSHOTGUN', role = 'primary', category = 'shotguns', label = 'Assault Shotgun', kind = 'Shotgun', ammo = 80, price = 180, rarity = 'legendary' },
        { id = 'WEAPON_HEAVYSHOTGUN', role = 'primary', category = 'shotguns', label = 'Heavy Shotgun', kind = 'Shotgun', ammo = 80, price = 190, rarity = 'legendary' },
        { id = 'WEAPON_COMBATSHOTGUN', role = 'primary', category = 'shotguns', label = 'Combat Shotgun', kind = 'Shotgun', ammo = 80, price = 210, rarity = 'legendary' },
        { id = 'WEAPON_AUTOSHOTGUN', role = 'primary', category = 'shotguns', label = 'Sweeper Shotgun', kind = 'Shotgun', ammo = 80, price = 200, rarity = 'legendary' },
        { id = 'WEAPON_SNIPERRIFLE', role = 'primary', category = 'snipers', label = 'Sniper Rifle', kind = 'Sniper', ammo = 40, price = 260, rarity = 'legendary' },
        { id = 'WEAPON_HEAVYSNIPER', role = 'primary', category = 'snipers', label = 'Heavy Sniper', kind = 'Sniper', ammo = 30, price = 340, rarity = 'exotic' },
        { id = 'WEAPON_MARKSMANRIFLE', role = 'primary', category = 'snipers', label = 'Marksman Rifle', kind = 'Marksman', ammo = 60, price = 280, rarity = 'exotic' },
        { id = 'WEAPON_PRECISIONRIFLE', role = 'primary', category = 'snipers', label = 'Precision Rifle', kind = 'Marksman', ammo = 50, price = 300, rarity = 'exotic' },
        { id = 'WEAPON_MUSKET', role = 'primary', category = 'snipers', label = 'Musket', kind = 'Marksman', ammo = 20, price = 120, rarity = 'epic' },

        { id = 'WEAPON_PISTOL', role = 'secondary', category = 'pistols', label = 'Pistol', kind = 'Handgun', ammo = 100, price = 0, rarity = 'neutral', starter = true },
        { id = 'WEAPON_COMBATPISTOL', role = 'secondary', category = 'pistols', label = 'Combat Pistol', kind = 'Handgun', ammo = 100, price = 40, rarity = 'rare' },
        { id = 'WEAPON_APPISTOL', role = 'secondary', category = 'pistols', label = 'AP Pistol', kind = 'Handgun', ammo = 120, price = 90, rarity = 'epic' },
        { id = 'WEAPON_PISTOL50', role = 'secondary', category = 'pistols', label = 'Pistol .50', kind = 'Handgun', ammo = 80, price = 80, rarity = 'epic' },
        { id = 'WEAPON_SNSPISTOL', role = 'secondary', category = 'pistols', label = 'SNS Pistol', kind = 'Handgun', ammo = 100, price = 30, rarity = 'neutral' },
        { id = 'WEAPON_HEAVYPISTOL', role = 'secondary', category = 'pistols', label = 'Heavy Pistol', kind = 'Handgun', ammo = 100, price = 70, rarity = 'rare' },
        { id = 'WEAPON_VINTAGEPISTOL', role = 'secondary', category = 'pistols', label = 'Vintage Pistol', kind = 'Handgun', ammo = 80, price = 45, rarity = 'rare' },
        { id = 'WEAPON_CERAMICPISTOL', role = 'secondary', category = 'pistols', label = 'Ceramic Pistol', kind = 'Handgun', ammo = 100, price = 85, rarity = 'epic' },
        { id = 'WEAPON_REVOLVER', role = 'secondary', category = 'pistols', label = 'Heavy Revolver', kind = 'Revolver', ammo = 60, price = 110, rarity = 'legendary' },
        { id = 'WEAPON_DOUBLEACTION', role = 'secondary', category = 'pistols', label = 'Double-Action', kind = 'Revolver', ammo = 60, price = 100, rarity = 'epic' },
        { id = 'WEAPON_NAVYREVOLVER', role = 'secondary', category = 'pistols', label = 'Navy Revolver', kind = 'Revolver', ammo = 50, price = 130, rarity = 'legendary' },
        { id = 'WEAPON_GADGETPISTOL', role = 'secondary', category = 'pistols', label = 'Perico Pistol', kind = 'Handgun', ammo = 80, price = 150, rarity = 'legendary' },
        { id = 'WEAPON_PISTOLXM3', role = 'secondary', category = 'pistols', label = 'WM 29 Pistol', kind = 'Handgun', ammo = 100, price = 160, rarity = 'exotic' },

        { id = 'WEAPON_SWITCHBLADE', role = 'equipment', category = 'melee', label = 'Switchblade', kind = 'Melee', price = 0, rarity = 'neutral', starter = true },
        { id = 'WEAPON_KNIFE', role = 'equipment', category = 'melee', label = 'Knife', kind = 'Melee', price = 20, rarity = 'neutral' },
        { id = 'WEAPON_DAGGER', role = 'equipment', category = 'melee', label = 'Antique Dagger', kind = 'Melee', price = 35, rarity = 'rare' },
        { id = 'WEAPON_MACHETE', role = 'equipment', category = 'melee', label = 'Machete', kind = 'Melee', price = 40, rarity = 'rare' },
        { id = 'WEAPON_BATTLEAXE', role = 'equipment', category = 'melee', label = 'Battle Axe', kind = 'Melee', price = 55, rarity = 'epic' },
        { id = 'WEAPON_HATCHET', role = 'equipment', category = 'melee', label = 'Hatchet', kind = 'Melee', price = 30, rarity = 'neutral' },
        { id = 'WEAPON_STONE_HATCHET', role = 'equipment', category = 'melee', label = 'Stone Hatchet', kind = 'Melee', price = 70, rarity = 'legendary' },
        { id = 'WEAPON_BAT', role = 'equipment', category = 'melee', label = 'Baseball Bat', kind = 'Melee', price = 15, rarity = 'neutral' },
        { id = 'WEAPON_CROWBAR', role = 'equipment', category = 'melee', label = 'Crowbar', kind = 'Melee', price = 15, rarity = 'neutral' },
        { id = 'WEAPON_GOLFCLUB', role = 'equipment', category = 'melee', label = 'Golf Club', kind = 'Melee', price = 15, rarity = 'neutral' },
        { id = 'WEAPON_HAMMER', role = 'equipment', category = 'melee', label = 'Hammer', kind = 'Melee', price = 15, rarity = 'neutral' },
        { id = 'WEAPON_WRENCH', role = 'equipment', category = 'melee', label = 'Pipe Wrench', kind = 'Melee', price = 20, rarity = 'neutral' },
        { id = 'WEAPON_NIGHTSTICK', role = 'equipment', category = 'melee', label = 'Nightstick', kind = 'Melee', price = 20, rarity = 'neutral' },
        { id = 'WEAPON_KNUCKLE', role = 'equipment', category = 'melee', label = 'Knuckle Duster', kind = 'Melee', price = 25, rarity = 'rare' },
        { id = 'WEAPON_BOTTLE', role = 'equipment', category = 'melee', label = 'Broken Bottle', kind = 'Melee', price = 10, rarity = 'neutral' },
        { id = 'WEAPON_POOLCUE', role = 'equipment', category = 'melee', label = 'Pool Cue', kind = 'Melee', price = 15, rarity = 'neutral' }
    }
}

Config.Radio = {
    enabled = true,
    baseChannel = 9100
}

Config.Squad = {
    enabled = true,
    blip = { sprite = 1, color = 2, scale = 0.8 },
    blipRefresh = 2000,
    chatColor = '#22FF00',
    chatMaxLength = 200,
    friendlyFire = false
}

Config.Storm = {
    color = { r = 255, g = 45, b = 45, a = 70 },
    phases = {
        { radiusMult = 0.65, shrink = 52000, hold = 20000, dps = 2 },
        { radiusMult = 0.35, shrink = 52000, hold = 22000, dps = 4 },
        { radiusMult = 0.1, shrink = 50000, hold = 22000, dps = 6 },
        { radiusMult = 0.0, shrink = 45000, hold = 15000, dps = 8 }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
--  RANKS — the ELO ladder
--  Set enabled = false to run hopouts with no rating at all: the Ranks page
--  disappears, ELO is dropped from every screen and the leaderboard sorts by
--  wins instead. Stats, credits and cash rewards all keep working.
-- ═══════════════════════════════════════════════════════════════════════════

Config.Ranks = {
    enabled = true,
    startRating = 1000,
    tiers = {
        { name = 'bronze', label = 'Bronze', min = 0, max = 500, color = '#CD7F32', win = 15, loss = 10 },
        { name = 'silver', label = 'Silver', min = 500, max = 1000, color = '#C0C0C0', win = 15, loss = 10 },
        { name = 'gold', label = 'Gold', min = 1000, max = 1500, color = '#FFD700', win = 20, loss = 25 },
        { name = 'diamond', label = 'Diamond', min = 1500, max = 2000, color = '#B9F2FF', win = 20, loss = 25 },
        { name = 'master', label = 'Master', min = 2000, max = 3000, color = '#9966CC', win = 25, loss = 35 },
        { name = 'celestial', label = 'Celestial', min = 3000, max = 7500, color = '#FF6B6B', win = 25, loss = 40 },
        { name = 'oneabove', label = 'One Above All', min = 7500, color = '#FF0000', win = 30, loss = 50 }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
--  REWARDS — cash and hopout credits
--  Credits are this resource's own currency. They are earned by playing
--  hopouts and are the only thing the store accepts.
-- ═══════════════════════════════════════════════════════════════════════════

Config.Credits = {
    label = 'Hopout Credits',
    short = 'Credits',
    win = 25,
    loss = 2,
    perKill = 0,   -- extra credits for every kill in a match
    perRound = 0   -- extra credits for every round your team wins
}

Config.Cash = {
    enabled = true,
    account = 'cash', -- 'cash' or 'bank' (mapped to each framework's own account name)
    win = 5000,
    loss = 1000
}

-- Bonus applied on top of a win once your streak reaches `wins`.
-- `milestone` is a one-off extra the exact match you hit the streak.
Config.WinStreaks = {
    { wins = 5, credits = 10, elo = 10, milestone = 10 },
    { wins = 20, credits = 15, elo = 15, milestone = 10 },
    { wins = 30, credits = 20, elo = 20, milestone = 20 },
    { wins = 40, credits = 25, elo = 25, milestone = 25 },
    { wins = 50, credits = 30, elo = 30, milestone = 50 }
}

-- ═══════════════════════════════════════════════════════════════════════════
--  STORE — spends hopout credits only
--
--  item.type:
--    'item'    give an inventory item          → item, count, metadata
--    'money'   pay out cash                    → account ('cash'/'bank'), amount
--    'event'   fire a server event             → event, args (source is prepended)
--    'command' run a server console command    → command ("%s" = server id, "%n" = name)
--
--  rarity is cosmetic and drives the card colour:
--    neutral · rare · epic · legendary · exotic · mythic · onepercent
-- ═══════════════════════════════════════════════════════════════════════════

Config.Store = {
    enabled = true,
    -- Category order in the store. Anything not listed lands in its own tab.
    categories = { 'weapons', 'gear', 'cash' },
    items = {
        {
            id = 'armour', label = 'Body Armour', category = 'gear', price = 40,
            rarity = 'rare', type = 'item', item = 'armour', count = 1
        },
        {
            id = 'medkit', label = 'Medkit', category = 'gear', price = 60,
            rarity = 'rare', type = 'item', item = 'medikit', count = 1
        },
        {
            id = 'bandage', label = 'Bandage x5', category = 'gear', price = 20,
            rarity = 'neutral', type = 'item', item = 'bandage', count = 5
        },
        {
            id = 'pistol', label = 'Pistol', category = 'weapons', price = 350,
            rarity = 'epic', type = 'item', item = 'WEAPON_PISTOL', count = 1, featured = true
        },
        {
            id = 'smg', label = 'SMG', category = 'weapons', price = 900,
            rarity = 'legendary', type = 'item', item = 'WEAPON_SMG', count = 1
        },
        {
            id = 'ammo', label = 'Pistol Ammo x50', category = 'weapons', price = 45,
            rarity = 'neutral', type = 'item', item = 'ammo-9', count = 50
        },
        {
            id = 'payout-small', label = '$25,000', category = 'cash', price = 250,
            rarity = 'exotic', type = 'money', account = 'cash', amount = 25000
        },
        {
            id = 'payout-large', label = '$100,000', category = 'cash', price = 900,
            rarity = 'onepercent', type = 'money', account = 'bank', amount = 100000, featured = true
        }
        -- Examples of the other two delivery types:
        -- { id = 'vip', label = 'VIP Tag', category = 'gear', price = 5000, rarity = 'mythic',
        --   type = 'event', event = 'myperks:server:giveVip', args = { 30 } },
        -- { id = 'car', label = 'Elegy', category = 'gear', price = 4000, rarity = 'mythic',
        --   type = 'command', command = 'givecar %s elegy' },
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
--  LEADERBOARD & CAREER
-- ═══════════════════════════════════════════════════════════════════════════

Config.Leaderboard = {
    limit = 25,        -- rows fetched
    showGang = true,   -- the "Gang" column
    -- Where that column's text comes from: QBCore 'gang', 'job' or 'none'.
    gangSource = 'gang',
    showJackpot = true,
    showMonthly = true
}

Config.Jackpot = {
    label = 'Jackpot',
    amount = 'TBA',
    desc = 'Climb the rankings and finish the month at the top to claim cash prizes and exclusive rewards.'
}

Config.Monthly = {
    title = 'Compete Monthly',
    desc = 'Earn a spot in the Top 500 for a chance at gift cards, gear and cash every month.'
}

-- ═══════════════════════════════════════════════════════════════════════════
--  DISCORD AVATARS + NAMES
--  Token lives in sv_config.lua (server-only — never ship a bot token to
--  clients). When enabled, lobby / leaderboard / ready check / in-match
--  squads use Discord avatars and display names.
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
--  MISC
-- ═══════════════════════════════════════════════════════════════════════════

-- Fired server-side whenever a hopouts match ends, for changelogs/webhooks:
--   AddEventHandler('fx_hopouts:server:matchEnded', function(data) end)
Config.Debug = false
