# Mining: Quarry Turtle — Design

## Purpose

A CC: Tweaked turtle script that fully excavates a rectangular volume
(`width × length × depth`), collects valuables into a surface storage
system (ME/Mekanism, via a plain chest buffer), and can run unattended for
a deep (100+ block) quarry without running out of inventory or fuel, and
without losing progress across a reboot.

This is the first script for the `mining/` role folder. It also establishes
the shared `lib/` modules, the deployment convention, and the testing
convention that later mining scripts (branch mining, ore-detection mining)
will reuse.

## Out of scope

- Strip mining / branch mining / ore-vein-following scripts — separate
  future designs, reusing the same `lib/` modules.
- Direct peripheral integration with AE2 (Advanced Peripherals ME Bridge)
  or Mekanism — the chest-buffer approach is deliberately mod-agnostic;
  a peripheral-based version can be a later addition, not a rewrite.
- Multi-turtle coordination (e.g. several turtles splitting one quarry).

## Architecture

Shared, reusable modules in `lib/`, kept small and single-purpose:

- **`lib/nav.lua`** — tracks position and facing relative to the turtle's
  start point (`0,0,0`), and exposes safe movement: `forward()`, `up()`,
  `down()`, `turnLeft()`, `turnRight()`. These wrap the raw `turtle.*` API
  calls with hazard handling (see below) so callers never call
  `turtle.forward()` etc. directly.
- **`lib/fuel.lua`** — `hasEnoughFuelToReturn()` (computes distance back to
  the surface chest from the current tracked position and compares to
  `turtle.getFuelLevel()`), and `refuel()` (sucks fuel items from the fuel
  chest and burns them via `turtle.refuel`).
- **`lib/inventory.lua`** — `isFull()`, a junk-block blacklist table
  (cobblestone, dirt, gravel, netherrack, etc.), `voidIfJunk(slot)` (drops
  a matching item immediately after digging), and `dumpToChest()` (empties
  all non-empty slots into the item chest).
- **`lib/state.lua`** — `save(state)` / `load()` against a state file on
  the turtle's own disk, used to resume progress after a reboot.
- **`mining/quarry.lua`** — the main script: parses startup args, drives
  the dig loop, and calls into the libs above at the right points.

Each lib module is usable and testable on its own (e.g. `nav` doesn't know
about mining or inventory; `inventory` doesn't know about navigation).

## Deployment & imports

CC: Tweaked's `require` resolves module paths **relative to the calling
script's own directory**, which breaks as soon as a script lives in a
subfolder (`mining/quarry.lua`) but shared code lives in a sibling folder
(`lib/`). To avoid that pitfall, all cross-folder imports use an absolute
`dofile` path instead of `require`:

```lua
local nav = dofile("/lib/nav.lua")
```

This resolves identically in three places, as long as `lib/` is at the
filesystem root in each case:

1. In this repo (`lib/` at repo root).
2. In CraftOS-PC, when the emulator's computer-0 data folder is pointed at
   the repo root (see Testing below) rather than mounted as a side drive.
3. On a real turtle, once installed (see below).

**Installer script** (`install.lua`, at repo root): a turtle runs this
once to pull down a script and everything it depends on, via CC:Tweaked's
built-in `wget`:

```
wget run https://raw.githubusercontent.com/YOUR_GITHUB_USER/minecraft-turtle-scripts/master/install.lua quarry
```

`YOUR_GITHUB_USER` is a placeholder until this repo is pushed to GitHub and
its real path is known — update `install.lua` and the README once it is.

`install.lua <name>` downloads `mining/<name>.lua` from the repo and saves
it as `/<name>` on the turtle, then downloads every file under `lib/` and
saves each as `/lib/<file>` — so the absolute `dofile("/lib/...")` calls
resolve correctly without preserving the repo's `mining/` subfolder on the
turtle.

## Startup & fixed layout

Run as:

```
quarry <width> <length> <depth> <voidJunk: true|false>
```

Fixed physical setup convention (documented in the README with a simple
diagram, since the people running this may not be programmers):

- Turtle starts at the surface, facing the direction it will dig into.
- The **fuel chest** is placed directly behind the turtle's start
  position.
- The **item chest** is placed directly to the left of the turtle's start
  position.

`quarry.lua` assumes these two fixed relative positions — no separate
config step needed beyond "place these two chests here before running".

## Digging algorithm

1. Dig straight down from the surface to reach the digging start depth
   (skips having the turtle chew through open air above the quarry).
2. Proceed in **3-tall slices**: for each forward step, dig the block at
   turtle height, then up, then down, clearing 3 vertical layers per
   horizontal move. This cuts horizontal passes by 3x versus a naive
   1-tall sweep.
3. Snake (boustrophedon) across the `width × length` footprint for the
   current 3-tall slice, then descend 3 more blocks and repeat.
4. Stop when either `depth` is reached or an undiggable block (bedrock) is
   hit — whichever comes first — finish the current row, then return to
   base and report done.

Junk voiding, when `voidJunk` is `true`, happens immediately after each
dig: if the mined item matches the blacklist in `lib/inventory.lua`, it's
dropped right there instead of kept, so trips back to the surface are
driven by actually-valuable items and fuel, not stone/dirt volume.

## Fuel management

- Before starting, and periodically during the run, `lib/fuel.lua` checks
  whether current fuel covers the trip back to the surface fuel chest from
  the turtle's current tracked position.
- When it doesn't (with a safety margin), the turtle interrupts digging,
  navigates back to the surface, refuels from the fuel chest via
  `turtle.suck` + `turtle.refuel`, optionally dumps inventory at the same
  time (see below), then resumes from its saved position.
- If the fuel chest is empty, the script stops and reports the problem
  rather than stranding the turtle underground.

## Inventory & item offload

- `lib/inventory.lua.isFull()` is checked after each dig alongside the
  fuel check.
- When the inventory is full (or fuel is low — whichever triggers first),
  the turtle returns to the surface, drops all non-empty slots into the
  item chest (`dumpToChest()`), does any needed refueling, then resumes.
- The item chest is expected to be hooked up to the player's ME system
  (ME Interface / Import Bus) or Mekanism network (Logistical Transporter)
  for auto-import — that wiring is the player's responsibility in-world,
  not something the script manages.

## Resume after reboot

After completing each row within a slice, `lib/state.lua.save()` writes:
current position, facing, current slice depth, and the run's original
args (`width`, `length`, `depth`, `voidJunk`) to a file on the turtle's
disk. On startup, `quarry.lua` checks for this file; if present, it
resumes from the saved position/slice instead of restarting the quarry
from the top. The state file is cleared once the quarry finishes.

## Hazard handling

All handled inside `lib/nav.lua`'s safe movement wrappers, not in
`quarry.lua` itself:

- **Gravel/sand**: after digging, if the space is still blocked (a falling
  block landed in it), re-dig and retry in a short loop until the move
  succeeds.
- **Lava/water**: if a dug space reveals a fluid, place a block into it to
  seal the flow before it spreads, then retry the move.
- **Mobs**: if a move fails because an entity occupies the space, attack
  once or twice, then retry the move.

## Documentation

Because some people running these scripts have no programming background,
the README's install/run instructions are written as plain numbered
steps aimed at that audience — what to place where in the world, the exact
command to type and why, and what to expect while it runs — not just a
command reference. Technical/architecture details (this design, module
responsibilities) stay separate from that walkthrough so one doesn't
clutter the other.

## Testing

Local smoke-testing uses CraftOS-PC. Its computer-0 data folder is pointed
at this repo's root (rather than mounting the repo as a secondary drive),
so absolute `/lib/...` paths resolve exactly the way they will on a real
deployed turtle. `mining/quarry.lua` is run directly from there with small
test dimensions (e.g. `quarry 3 3 6 true`) before trying a real large run
in-game. Not everything is emulated faithfully (e.g. some mod-specific
block interactions), so a full run should still be observed in-game at
least once.

## Future work

- Strip mining and branch-mining (with ore detection) scripts reusing
  `lib/nav.lua`, `lib/fuel.lua`, `lib/inventory.lua`, `lib/state.lua`.
- Optional direct ME/Mekanism peripheral push, if a bridge peripheral mod
  is later installed, as an alternative to the chest-buffer offload.
- Multi-turtle quarry splitting for very large areas.
