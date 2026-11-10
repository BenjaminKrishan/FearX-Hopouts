# FearX-Hopouts — Open Source QBCore Edition

A complete, editable FiveM PvP hopouts resource for **QBCore**, **ox_lib**, and **oxmysql**. The former FXAP/escrow Lua files have been replaced with readable source; no bridge resource, asset-pack subscription, ESX, Qbox, or escrow runtime is used.

## Features

- Solo and party matchmaking, with equal-size 1v1, 2v2, and 3v3 matches
- Persistent friend requests and party invitations
- Server-owned ready checks and queue state
- Isolated routing bucket per match, configurable maps, staged vehicles, and team spawns
- First-to-five elimination rounds, countdowns, intermissions, round draws, and forfeit handling
- Shrinking storm with configurable phases and damage
- Persistent ELO, ranks, wins/losses, K/D, headshots, playtime, and win streaks
- Career and leaderboard pages
- Unlockable primary, secondary, and melee loadouts
- Credit store supporting QBCore items, money, custom events, and commands
- Optional pma-voice/saltychat/mumble radio integration
- Squad health/armor HUD and teammate blips
- Inventory backup before a match and restoration afterwards, on reconnect, and after a resource restart
- Server-side validation for queue actions, purchases, deaths, match IDs, rounds, and killers
- Existing FearX NUI, maps, images, and configuration retained

## Requirements

- A current FiveM server with Lua 5.4 enabled
- [`qb-core`](https://github.com/qbcore-framework/qb-core)
- [`ox_lib`](https://github.com/overextended/ox_lib)
- [`oxmysql`](https://github.com/overextended/oxmysql)
- MySQL/MariaDB configured through oxmysql
- Optional: `ox_inventory` (automatically detected) or QBCore's default item inventory
- Optional: `qb-ambulancejob`, `pma-voice`

## Installation

1. Remove/disable the old encrypted `FearX-Hopouts` resource and any `fearx_bridge` dependency used only by it.
2. Copy this folder to `resources/[custom]/FearX-Hopouts`.
3. Import the database schema:

   ```sql
   SOURCE sql/install.sql;
   ```

   Or open `sql/install.sql` in HeidiSQL/phpMyAdmin and run all three `CREATE TABLE` statements in your QBCore database.

4. Review `config.lua` and `config_maps.lua`. In particular, set:
   - `Config.LobbySpot` to a safe, normally inaccessible lobby location.
   - `Config.ExitSpot`, or set it to `nil` to use the position where the lobby was opened.
   - `Config.RoutingBucketBase` so it does not collide with other instancing resources.
   - Store item names/prices to match your server.
5. Ensure resources in this order:

   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure qb-core
   ensure ox_inventory # only if your server uses it
   ensure FearX-Hopouts
   ```

6. Restart the server, connect two characters, and press **F7** or use `/hopouts` on both. Queue with matching party sizes and accept the ready check.

## Commands

| Command / key | Action |
| --- | --- |
| `/hopouts` or `F7` | Open/close the lobby |
| `/hopoutleave` | Forfeit an active match, or close the lobby |

## Inventory safety

With `Config.Match.clearInventory = true`, the complete inventory is serialized into `fx_hopouts_inv` **before** it is cleared. The row is deleted only after a successful restore.

- `ox_inventory`: item names, counts, metadata, and slots are retained.
- QBCore inventory: the complete slot-based `PlayerData.items` table is retained.
- A failed restore keeps the database backup for another attempt.
- An older backup is never overwritten by a new match.
- Players who disconnect receive their backup after their next character load.

**Back up your database before the first installation and test inventory restoration with disposable items.** Inventory behavior can be changed by other server resources, so a staging-server test is strongly recommended.

## Configuration notes

- `Config.ReadyCheck.enabled = false` starts paired matches immediately.
- `Config.Ranks.enabled = false` keeps stats/rewards but disables rating changes and rank UI.
- `Config.Match.clearInventory = false` disables the backup/clear lifecycle; match weapons are still native.
- `Config.Match.unlimitedAmmo = true` is recommended for PvP rounds.
- Weapon unlocks are stored as JSON in `fx_hopouts_stats`; starter weapons are always repaired into the owned/equipped list.
- Set `Config.Debug = true` while testing for additional diagnostics.
- Discord avatars are optional and disabled by default in `sv_config.lua`. The core game loop does not require Discord.

## Match end integration

Other server resources can listen for:

```lua
AddEventHandler('fx_hopouts:server:matchEnded', function(data)
    -- data.id, data.map, data.winner, data.score, data.forfeiter, data.players
end)
```

Do not trust this event from clients; register it as a server event handler only.

## Validation checklist

Before a production PvP launch, test:

1. Solo queue, party queue, accept/decline/timeout, and cancelling the queue.
2. A full match, repeated rounds, timeout draw, disconnect, and `/hopoutleave`.
3. Inventory items, weapon metadata, cash rewards, and reconnect during a match.
4. Loadout purchase/equip and every enabled store delivery type.
5. Simultaneous matches to verify routing buckets, radios, vehicles, and storm zones do not overlap.
6. Your ambulance/death resource and any anti-cheat rules for native match weapons/revives.

## Source layout

- `bridge/`: small QBCore-only adapters and inventory persistence
- `client/`: lobby, NUI, combat, storm, radio, and squad logic
- `server/`: authoritative matchmaking, matches, stats, purchases, and squad replication
- `config.lua`, `config_maps.lua`, `sv_config.lua`: editable configuration
- `html/`: unencrypted NUI
- `sql/`: install/uninstall schema

## License

MIT — see [LICENSE](LICENSE). Existing FearX images/fonts remain part of the supplied asset set; confirm any third-party asset redistribution rights before publishing a derived package.
