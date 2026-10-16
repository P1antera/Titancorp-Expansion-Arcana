# Titancorp Expansion Arcana

Source project for **[Arcana] Titancorp Expansion / 泰坦重工拓展**, a Starbound mod that expands Titan Corporation content with locations, missions, equipment, drones, vehicles, automation machines, apartments, and credit-related systems.

## Requirements

- Starbound on Windows
- The [Arcana](https://steamcommunity.com/sharedfiles/filedetails/?id=2359135864) mod

Install the required dependencies alongside this mod in your Starbound `mods` directory.

## Development

The repository root is itself the Starbound asset root: `_metadata`, asset folders, JSON files, Lua scripts, and patch files retain the paths expected by the game. For local testing, place this directory (or the built `.pak`) under `OpenStarbound/mods`.

## Administrator mission skip

On OpenStarbound, an administrator can complete the Titancorp main-mission sequence on a fresh character with:

```
/run player.setProperty("at_ext_mission_skip_request", true)
```

The skip includes the two required setup quests, then completes d1–d7, d9, d8, d10, and d11 in dependency order. It preserves normal quest rewards and will stop without changing anything if one of those quests is already active.

## Credits

Original mod author: SVA. This expansion is authored by plantera, with credits and contributor acknowledgements recorded in `_metadata`.
