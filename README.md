# minecraft-turtle-scripts

Lua scripts for CC: Tweaked turtles and computers, organized by turtle role.

## Layout

- `mining/` — quarry/strip-mining/ore-detection scripts
- `farming/` — crop farming scripts
- `tree-farm/` — tree farming/lumberjack scripts
- `building/` — construction/schematic-placing scripts
- `item-sorter/` — computer + turtle scripts for sorting storage systems
- `lib/` — shared helper modules required by scripts in the folders above

Each script folder is meant to be pushed/pulled to an in-game turtle as-is
(e.g. via a disk drive, `wget`, or a Pastebin/GitHub pull script), so keep
scripts self-contained aside from `require`-ing modules from `lib/`.

## Testing locally with CraftOS-PC

[CraftOS-PC](https://www.craftos-pc.cc/) is a standalone CC: Tweaked emulator
that runs the real `turtle`, `fs`, `peripheral`, etc. APIs outside of
Minecraft, so most scripts can be smoke-tested without loading the game.

1. Install it: `brew install --cask craftos-pc`
2. Launch CraftOS-PC and use its mounter (Settings → Mounter, or drag a
   folder onto the window) to mount this repo's folder as a drive inside the
   emulator — this avoids copying files back and forth.
3. Run a script from the CraftOS-PC shell, e.g.:
   ```
   cd mining
   strip-mine
   ```

Not everything is emulated (e.g. some block/peripheral interactions specific
to other mods), so treat CraftOS-PC as a fast logic/syntax check and still do
a final pass in-game before relying on a script.
