# Titancorp Expansion Arcana

Source project for **[Arcana] Titancorp Expansion / 泰坦重工拓展**, a Starbound mod that expands Titan Corporation content with locations, missions, equipment, drones, vehicles, automation machines, apartments, and credit-related systems.

## Requirements

- Starbound on Windows (the build script uses the installation's `win32/asset_packer.exe`)
- The [Arcana](https://steamcommunity.com/sharedfiles/filedetails/?id=2359135864) mod
- `MWHArcanaAddon`

Install the required dependencies alongside this mod in your Starbound `mods` directory.

## Build

From this directory, run:

```powershell
./build.ps1
```

The package is written to `build/Titancorp-Expansion-Arcana.pak`. The script stages a clean copy of the source before packing, so Git metadata and prior build artifacts are never included in the `.pak`.

To use another asset packer executable:

```powershell
./build.ps1 -AssetPacker 'C:\path\to\asset_packer.exe'
```

## Development

The repository root is itself the Starbound asset root: `_metadata`, asset folders, JSON files, Lua scripts, and patch files retain the paths expected by the game. For local testing, place this directory (or the built `.pak`) under `OpenStarbound/mods`.

## Credits

Original mod author: SVA. This expansion is authored by plantera, with credits and contributor acknowledgements recorded in `_metadata`.
