# Quarry Mining Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `mining/quarry.lua` CC: Tweaked turtle script and its supporting `lib/` modules, so a turtle can fully excavate a `width × length × depth` volume, manage its own fuel and inventory via surface chests, survive a reboot mid-run, and be installed onto a real turtle via `wget`.

**Architecture:** Four small, single-purpose `lib/` modules (`inventory.lua`, `nav.lua`, `fuel.lua`, `state.lua`) each expose pure, unit-testable helper functions alongside thin functions that call the CC: Tweaked `turtle`/`io` globals. `mining/quarry.lua` composes them into the dig loop. All cross-file imports use `dofile("/lib/...")` (absolute path) rather than `require`, so the code resolves identically in this repo, in CraftOS-PC, and on a turtle. `install.lua` bootstraps a fresh turtle via `wget`.

**Tech Stack:** Lua (CC: Tweaked's Lua 5.1-based turtle/computer APIs), plain system Lua (via Homebrew) for local unit tests.

**Spec:** `docs/superpowers/specs/2026-09-02-mining-quarry-design.md`

## Global Constraints

- Target runtime is CC: Tweaked's Lua 5.1-based `turtle`/`fs`/`io` APIs — don't use syntax or stdlib features that environment doesn't support.
- Cross-folder imports use `dofile("/lib/<name>.lua")`, never `require`.
- `cobblestone` (`minecraft:cobblestone`) is never voided as junk, even when `voidJunk` is true — it's kept as sealing filler for lava/water (see Task 1).
- User-facing docs (README) must be written in **both German and English**; this plan document and the spec stay English-only (internal/dev docs).
- No formatter/linter is configured — match surrounding code style.

---

## Task 0: Local test environment

**Files:**
- Create: `tests/support/bootstrap.lua`
- Create: `tests/support/mock_turtle.lua`
- Create: `tests/run_all.sh`
- Test: `tests/bootstrap_smoke_test.lua`

**Interfaces:**
- Produces: `dofile("tests/support/bootstrap.lua")` (rewrites a leading `/` in any `dofile` path to `./`, so `/lib/x.lua`-style absolute imports resolve against the repo root when tests run under plain Lua). `dofile("tests/support/mock_turtle.lua")` returns a factory function `newMockTurtle(script)` — `script` is a table of `{methodName = function(...) ... end}` overrides; every CC turtle method not overridden returns `true` and is still recorded. The mock exposes `mock.calls` (an array of method names called, in order).

CC: Tweaked's `dofile` resolves a leading `/` against the computer's own virtual filesystem root. A plain system `lua` interpreter treats a leading `/` as the real OS root, which is wrong for local testing — the bootstrap shim fixes that mismatch so the exact same `lib/*.lua` source files work unmodified in both places.

- [ ] **Step 1: Check for / install a local Lua interpreter**

Run: `lua -v`

If that fails with "command not found", install one:

```bash
brew install lua
lua -v
```

Expected: version output (any Lua 5.x is fine — we only rely on standard, version-stable syntax).

- [ ] **Step 2: Write the bootstrap shim**

Create `tests/support/bootstrap.lua`:

```lua
local realDofile = dofile

_G.dofile = function(path)
  if path:sub(1, 1) == "/" then
    path = "." .. path
  end
  return realDofile(path)
end
```

- [ ] **Step 3: Write the mock turtle factory**

Create `tests/support/mock_turtle.lua`:

```lua
local TURTLE_METHODS = {
  "detect", "detectUp", "detectDown",
  "dig", "digUp", "digDown",
  "inspect", "inspectUp", "inspectDown",
  "place", "placeUp", "placeDown",
  "forward", "up", "down",
  "turnLeft", "turnRight",
  "attack", "attackUp", "attackDown",
  "suck", "refuel", "select",
  "getItemDetail", "getItemCount", "getItemSpace",
  "getFuelLevel", "drop",
}

local function newMockTurtle(script)
  script = script or {}
  local mock = {calls = {}}

  local function record(name)
    return function(...)
      mock.calls[#mock.calls + 1] = name
      local handler = script[name]
      if type(handler) == "function" then
        return handler(...)
      end
      if handler == nil then
        return true
      end
      return handler
    end
  end

  for _, name in ipairs(TURTLE_METHODS) do
    mock[name] = record(name)
  end

  return mock
end

return newMockTurtle
```

- [ ] **Step 4: Write the smoke test**

Create `tests/bootstrap_smoke_test.lua`:

```lua
dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

local mock = newMockTurtle({detect = function() return false end})
assert(mock.detect() == false)
assert(mock.calls[1] == "detect")

local mock2 = newMockTurtle()
assert(mock2.forward() == true)
assert(mock2.calls[1] == "forward")

print("OK")
```

- [ ] **Step 5: Run the smoke test**

Run: `lua tests/bootstrap_smoke_test.lua`
Expected: `OK`

- [ ] **Step 6: Write the test runner**

Create `tests/run_all.sh`:

```bash
#!/bin/sh
set -e
cd "$(dirname "$0")/.."

status=0
for test_file in tests/*_test.lua; do
  echo "== $test_file =="
  if lua "$test_file"; then
    :
  else
    echo "FAILED: $test_file"
    status=1
  fi
done
exit $status
```

Run: `chmod +x tests/run_all.sh && ./tests/run_all.sh`
Expected: the smoke test's `== tests/bootstrap_smoke_test.lua ==` / `OK` output, exit code 0.

- [ ] **Step 7: Commit**

```bash
git add tests/support/bootstrap.lua tests/support/mock_turtle.lua tests/run_all.sh tests/bootstrap_smoke_test.lua
git commit -m "Add local Lua test harness (mock turtle + dofile shim)"
```

---

## Task 1: `lib/inventory.lua`

**Files:**
- Create: `lib/inventory.lua`
- Test: `tests/inventory_test.lua`

**Interfaces:**
- Produces: `inventory.SEALING_ITEM` (string, `"minecraft:cobblestone"`). `inventory.isJunk(itemName: string) -> boolean`. `inventory.isFull() -> boolean`. `inventory.voidIfJunk(slot: integer) -> boolean` (true if it dropped something). `inventory.selectSealingItem() -> boolean` (true if a sealing item was found and selected). `inventory.dumpToChest()` (drops every non-empty slot forward, re-selects slot 1 when done).
- Consumes: global `turtle` (real on a turtle; a `tests/support/mock_turtle.lua` instance in tests).

- [ ] **Step 1: Write the failing tests**

Create `tests/inventory_test.lua`:

```lua
dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

-- Junk classification is pure and doesn't need a real mock.
_G.turtle = newMockTurtle()
local inventory = dofile("/lib/inventory.lua")

assert(inventory.isJunk("minecraft:dirt") == true)
assert(inventory.isJunk("minecraft:gravel") == true)
assert(inventory.isJunk("minecraft:diamond_ore") == false)
assert(inventory.isJunk("minecraft:cobblestone") == false)

-- isFull(): true only when every slot is completely full.
_G.turtle = newMockTurtle({getItemSpace = function() return 0 end})
inventory = dofile("/lib/inventory.lua")
assert(inventory.isFull() == true)

_G.turtle = newMockTurtle({
  getItemSpace = function(slot)
    if slot == 5 then return 10 end
    return 0
  end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.isFull() == false)

-- voidIfJunk(): drops a junk item in the given slot, leaves others alone.
local selected, dropped = nil, false
_G.turtle = newMockTurtle({
  getItemDetail = function(slot)
    if slot == 3 then return {name = "minecraft:dirt", count = 64} end
    return nil
  end,
  select = function(slot) selected = slot return true end,
  drop = function() dropped = true return true end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.voidIfJunk(3) == true)
assert(selected == 3)
assert(dropped == true)
assert(inventory.voidIfJunk(4) == false)

-- selectSealingItem(): finds and selects cobblestone if present.
local sealingSelected = nil
_G.turtle = newMockTurtle({
  getItemDetail = function(slot)
    if slot == 7 then return {name = "minecraft:cobblestone", count = 10} end
    return nil
  end,
  select = function(slot) sealingSelected = slot return true end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.selectSealingItem() == true)
assert(sealingSelected == 7)

_G.turtle = newMockTurtle({getItemDetail = function() return nil end})
inventory = dofile("/lib/inventory.lua")
assert(inventory.selectSealingItem() == false)

-- dumpToChest(): drops every non-empty slot, then re-selects slot 1.
local calls = {}
_G.turtle = newMockTurtle({
  getItemCount = function(slot)
    if slot == 2 or slot == 9 then return 64 end
    return 0
  end,
  select = function(slot) calls[#calls + 1] = {"select", slot} return true end,
  drop = function() calls[#calls + 1] = {"drop"} return true end,
})
inventory = dofile("/lib/inventory.lua")
inventory.dumpToChest()
assert(calls[1][1] == "select" and calls[1][2] == 2)
assert(calls[2][1] == "drop")
assert(calls[3][1] == "select" and calls[3][2] == 9)
assert(calls[4][1] == "drop")
assert(calls[5][1] == "select" and calls[5][2] == 1)

print("OK")
```

- [ ] **Step 2: Run the tests, confirm they fail**

Run: `lua tests/inventory_test.lua`
Expected: an error such as `cannot open /lib/inventory.lua` (the file doesn't exist yet).

- [ ] **Step 3: Implement `lib/inventory.lua`**

```lua
local inventory = {}

inventory.SEALING_ITEM = "minecraft:cobblestone"

local JUNK_BLOCKS = {
  ["minecraft:dirt"] = true,
  ["minecraft:gravel"] = true,
  ["minecraft:sand"] = true,
  ["minecraft:netherrack"] = true,
  ["minecraft:diorite"] = true,
  ["minecraft:andesite"] = true,
  ["minecraft:granite"] = true,
  ["minecraft:stone"] = true,
  ["minecraft:deepslate"] = true,
  ["minecraft:cobbled_deepslate"] = true,
}

function inventory.isJunk(itemName)
  if itemName == inventory.SEALING_ITEM then
    return false
  end
  return JUNK_BLOCKS[itemName] == true
end

function inventory.isFull()
  for slot = 1, 16 do
    if turtle.getItemSpace(slot) > 0 then
      return false
    end
  end
  return true
end

function inventory.voidIfJunk(slot)
  local detail = turtle.getItemDetail(slot)
  if detail and inventory.isJunk(detail.name) then
    turtle.select(slot)
    turtle.drop()
    return true
  end
  return false
end

function inventory.selectSealingItem()
  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and detail.name == inventory.SEALING_ITEM then
      turtle.select(slot)
      return true
    end
  end
  return false
end

function inventory.dumpToChest()
  for slot = 1, 16 do
    if turtle.getItemCount(slot) > 0 then
      turtle.select(slot)
      turtle.drop()
    end
  end
  turtle.select(1)
end

return inventory
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `lua tests/inventory_test.lua`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add lib/inventory.lua tests/inventory_test.lua
git commit -m "Add lib/inventory.lua: junk voiding, sealing item, chest dump"
```

---

## Task 2: `lib/nav.lua`

**Files:**
- Create: `lib/nav.lua`
- Test: `tests/nav_test.lua`

**Interfaces:**
- Consumes: `lib/inventory.lua`'s `inventory.selectSealingItem()` (Task 1), via `dofile("/lib/inventory.lua")`.
- Produces: `nav.pos` (`{x, y, z}`, starts at `{0,0,0}`), `nav.facing` (integer 0-3, starts `0`). `nav.turnLeftFacing(facing) -> integer`, `nav.turnRightFacing(facing) -> integer` (pure). `nav.stepForward(pos, facing) -> {x,y,z}` (pure). `nav.setPosition(pos, facing)` (overwrites tracked state, no movement — used to resync after a reboot). `nav.forward() -> boolean`, `nav.up() -> boolean`, `nav.down() -> boolean` (dig-and-move, with hazard handling; update `nav.pos` on success). `nav.digUp() -> boolean`, `nav.digDown() -> boolean` (clear without moving). `nav.turnLeft()`, `nav.turnRight()` (turn and update `nav.facing`). `nav.rotateTo(targetFacing)` (turns right repeatedly until `nav.facing == targetFacing`). `nav.goTo(target: {x,y,z}) -> boolean` (navigates y then x then z to reach `target`).

Facing convention (0-3, absolute — never reset except via `setPosition`): `0` moves `+z`, `1` moves `+x`, `2` moves `-z`, `3` moves `-x`. `y` increases going up.

- [ ] **Step 1: Write the failing tests**

Create `tests/nav_test.lua`:

```lua
dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

-- Pure facing/position math.
_G.turtle = newMockTurtle()
local nav = dofile("/lib/nav.lua")

assert(nav.turnLeftFacing(0) == 3)
assert(nav.turnRightFacing(0) == 1)
assert(nav.turnRightFacing(3) == 0)

local forwardPos = nav.stepForward({x = 0, y = 0, z = 0}, 0)
assert(forwardPos.x == 0 and forwardPos.y == 0 and forwardPos.z == 1)

local eastPos = nav.stepForward({x = 0, y = 0, z = 0}, 1)
assert(eastPos.x == 1 and eastPos.y == 0 and eastPos.z == 0)

-- forward(): a clear path just moves and updates pos.
_G.turtle = newMockTurtle({
  detect = function() return false end,
  forward = function() return true end,
})
nav = dofile("/lib/nav.lua")
assert(nav.forward() == true)
assert(nav.pos.z == 1)

-- forward(): digs through a plain block that's in the way.
local dugCount = 0
_G.turtle = newMockTurtle({
  detect = function() return dugCount == 0 end,
  inspect = function() return true, {name = "minecraft:stone"} end,
  dig = function()
    dugCount = dugCount + 1
    return true
  end,
  forward = function() return true end,
})
nav = dofile("/lib/nav.lua")
assert(nav.forward() == true)
assert(dugCount == 1)

-- forward(): stops permanently on an undiggable block (bedrock), pos unchanged.
_G.turtle = newMockTurtle({
  detect = function() return true end,
  inspect = function() return true, {name = "minecraft:bedrock"} end,
  dig = function() return false end,
})
nav = dofile("/lib/nav.lua")
assert(nav.forward() == false)
assert(nav.pos.z == 0)

-- forward(): seals water with cobblestone before digging through it.
local placedCount = 0
local sealed = false
_G.turtle = newMockTurtle({
  detect = function() return not sealed end,
  inspect = function()
    if not sealed then
      return true, {name = "minecraft:water"}
    end
    return true, {name = "minecraft:cobblestone"}
  end,
  getItemDetail = function(slot)
    if slot == 1 then
      return {name = "minecraft:cobblestone", count = 10}
    end
    return nil
  end,
  select = function() return true end,
  place = function()
    placedCount = placedCount + 1
    sealed = true
    return true
  end,
  dig = function() return true end,
  forward = function() return true end,
})
nav = dofile("/lib/nav.lua")
assert(nav.forward() == true)
assert(placedCount == 1)

-- turnLeft/turnRight update tracked facing.
_G.turtle = newMockTurtle()
nav = dofile("/lib/nav.lua")
nav.turnLeft()
assert(nav.facing == 3)
nav.turnRight()
nav.turnRight()
assert(nav.facing == 1)

-- rotateTo turns until facing matches the target.
_G.turtle = newMockTurtle()
nav = dofile("/lib/nav.lua")
nav.rotateTo(2)
assert(nav.facing == 2)

-- setPosition overwrites tracked state without moving.
_G.turtle = newMockTurtle()
nav = dofile("/lib/nav.lua")
nav.setPosition({x = 5, y = -6, z = 7}, 3)
assert(nav.pos.x == 5 and nav.pos.y == -6 and nav.pos.z == 7)
assert(nav.facing == 3)

-- goTo drives forward/up/down and turns to reach a target position.
_G.turtle = newMockTurtle({detect = function() return false end})
nav = dofile("/lib/nav.lua")
assert(nav.goTo({x = 2, y = -1, z = 1}) == true)
assert(nav.pos.x == 2 and nav.pos.y == -1 and nav.pos.z == 1)

print("OK")
```

- [ ] **Step 2: Run the tests, confirm they fail**

Run: `lua tests/nav_test.lua`
Expected: an error such as `cannot open /lib/nav.lua`.

- [ ] **Step 3: Implement `lib/nav.lua`**

```lua
local inventory = dofile("/lib/inventory.lua")

local nav = {}

local DELTA = {
  [0] = {x = 0, y = 0, z = 1},
  [1] = {x = 1, y = 0, z = 0},
  [2] = {x = 0, y = 0, z = -1},
  [3] = {x = -1, y = 0, z = 0},
}

function nav.turnLeftFacing(facing)
  return (facing + 3) % 4
end

function nav.turnRightFacing(facing)
  return (facing + 1) % 4
end

function nav.stepForward(pos, facing)
  local d = DELTA[facing]
  return {x = pos.x + d.x, y = pos.y + d.y, z = pos.z + d.z}
end

nav.pos = {x = 0, y = 0, z = 0}
nav.facing = 0

function nav.setPosition(pos, facing)
  nav.pos = {x = pos.x, y = pos.y, z = pos.z}
  nav.facing = facing
end

local MAX_CLEAR_ATTEMPTS = 50
local MOVE_RETRY_LIMIT = 3

local function digOnly(detect, dig, inspect, place)
  local attempts = 0
  while detect() do
    attempts = attempts + 1
    if attempts > MAX_CLEAR_ATTEMPTS then
      return false
    end
    local hasBlock, data = inspect()
    if hasBlock and (data.name == "minecraft:water" or data.name == "minecraft:lava") then
      if inventory.selectSealingItem() then
        place()
      end
    elseif not dig() then
      return false
    end
  end
  return true
end

local function clearAndMove(detect, dig, inspect, place, move, attack)
  if not digOnly(detect, dig, inspect, place) then
    return false
  end
  for _ = 1, MOVE_RETRY_LIMIT do
    if move() then
      return true
    end
    attack()
  end
  return false
end

function nav.digUp()
  return digOnly(turtle.detectUp, turtle.digUp, turtle.inspectUp, turtle.placeUp)
end

function nav.digDown()
  return digOnly(turtle.detectDown, turtle.digDown, turtle.inspectDown, turtle.placeDown)
end

function nav.forward()
  local ok = clearAndMove(turtle.detect, turtle.dig, turtle.inspect, turtle.place, turtle.forward, turtle.attack)
  if ok then
    nav.pos = nav.stepForward(nav.pos, nav.facing)
  end
  return ok
end

function nav.up()
  local ok = clearAndMove(turtle.detectUp, turtle.digUp, turtle.inspectUp, turtle.placeUp, turtle.up, turtle.attackUp)
  if ok then
    nav.pos = {x = nav.pos.x, y = nav.pos.y + 1, z = nav.pos.z}
  end
  return ok
end

function nav.down()
  local ok = clearAndMove(turtle.detectDown, turtle.digDown, turtle.inspectDown, turtle.placeDown, turtle.down, turtle.attackDown)
  if ok then
    nav.pos = {x = nav.pos.x, y = nav.pos.y - 1, z = nav.pos.z}
  end
  return ok
end

function nav.turnLeft()
  turtle.turnLeft()
  nav.facing = nav.turnLeftFacing(nav.facing)
end

function nav.turnRight()
  turtle.turnRight()
  nav.facing = nav.turnRightFacing(nav.facing)
end

function nav.rotateTo(targetFacing)
  while nav.facing ~= targetFacing do
    nav.turnRight()
  end
end

local function facingForAxis(axis, sign)
  for facing = 0, 3 do
    if DELTA[facing][axis] == sign then
      return facing
    end
  end
end

function nav.goTo(target)
  while nav.pos.y < target.y do
    if not nav.up() then return false end
  end
  while nav.pos.y > target.y do
    if not nav.down() then return false end
  end

  local dx = target.x - nav.pos.x
  if dx ~= 0 then
    nav.rotateTo(facingForAxis("x", dx > 0 and 1 or -1))
    for _ = 1, math.abs(dx) do
      if not nav.forward() then return false end
    end
  end

  local dz = target.z - nav.pos.z
  if dz ~= 0 then
    nav.rotateTo(facingForAxis("z", dz > 0 and 1 or -1))
    for _ = 1, math.abs(dz) do
      if not nav.forward() then return false end
    end
  end

  return true
end

return nav
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `lua tests/nav_test.lua`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add lib/nav.lua tests/nav_test.lua
git commit -m "Add lib/nav.lua: position tracking, hazard-safe movement, goTo"
```

---

## Task 3: `lib/fuel.lua`

**Files:**
- Create: `lib/fuel.lua`
- Test: `tests/fuel_test.lua`

**Interfaces:**
- Produces: `fuel.SAFETY_MARGIN` (integer, `20`). `fuel.distanceTo(pos: {x,y,z}, target?: {x,y,z}) -> integer` (Manhattan distance; `target` defaults to `{0,0,0}`; pure). `fuel.hasEnoughToReturn(pos: {x,y,z}, fuelLevel: integer|"unlimited") -> boolean` (pure). `fuel.refuel() -> boolean` (sucks from the chest in front, finds whichever slot's count increased, selects and burns it).
- Consumes: global `turtle`.

- [ ] **Step 1: Write the failing tests**

Create `tests/fuel_test.lua`:

```lua
dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

_G.turtle = newMockTurtle()
local fuel = dofile("/lib/fuel.lua")

assert(fuel.distanceTo({x = 3, y = -4, z = 2}) == 9)
assert(fuel.hasEnoughToReturn({x = 3, y = 0, z = 0}, 3 + fuel.SAFETY_MARGIN) == true)
assert(fuel.hasEnoughToReturn({x = 3, y = 0, z = 0}, 3 + fuel.SAFETY_MARGIN - 1) == false)
assert(fuel.hasEnoughToReturn({x = 100, y = 0, z = 0}, "unlimited") == true)

-- refuel(): finds whichever slot's count increased after sucking from the
-- chest, selects it, and burns it.
local selectedSlot = nil
local refueled = false
local sucked = false
_G.turtle = newMockTurtle({
  getItemCount = function(slot)
    if slot == 4 and sucked then return 1 end
    return 0
  end,
  suck = function()
    sucked = true
    return true
  end,
  select = function(slot)
    selectedSlot = slot
    return true
  end,
  refuel = function()
    refueled = true
    return true
  end,
})
fuel = dofile("/lib/fuel.lua")
assert(fuel.refuel() == true)
assert(selectedSlot == 4)
assert(refueled == true)

-- refuel(): nothing came in (empty chest) -> false, no select/refuel.
local selectCalledAgain = false
_G.turtle = newMockTurtle({
  getItemCount = function() return 0 end,
  suck = function() return false end,
  select = function() selectCalledAgain = true return true end,
})
fuel = dofile("/lib/fuel.lua")
assert(fuel.refuel() == false)
assert(selectCalledAgain == false)

print("OK")
```

- [ ] **Step 2: Run the tests, confirm they fail**

Run: `lua tests/fuel_test.lua`
Expected: an error such as `cannot open /lib/fuel.lua`.

- [ ] **Step 3: Implement `lib/fuel.lua`**

```lua
local fuel = {}

fuel.SAFETY_MARGIN = 20

function fuel.distanceTo(pos, target)
  target = target or {x = 0, y = 0, z = 0}
  return math.abs(pos.x - target.x) + math.abs(pos.y - target.y) + math.abs(pos.z - target.z)
end

function fuel.hasEnoughToReturn(pos, fuelLevel)
  if fuelLevel == "unlimited" then
    return true
  end
  return fuelLevel >= fuel.distanceTo(pos) + fuel.SAFETY_MARGIN
end

function fuel.refuel()
  local before = {}
  for slot = 1, 16 do
    before[slot] = turtle.getItemCount(slot)
  end

  turtle.suck()

  for slot = 1, 16 do
    if turtle.getItemCount(slot) > before[slot] then
      turtle.select(slot)
      return turtle.refuel()
    end
  end

  return false
end

return fuel
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `lua tests/fuel_test.lua`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add lib/fuel.lua tests/fuel_test.lua
git commit -m "Add lib/fuel.lua: fuel-to-return check and chest refueling"
```

---

## Task 4: `lib/state.lua`

**Files:**
- Create: `lib/state.lua`
- Test: `tests/state_test.lua`

**Interfaces:**
- Produces: `state.PATH` (string, default `"/quarry_state.txt"`, overridable). `state.encode(t: table) -> string` (pure). `state.decode(text: string) -> table` (pure). `state.save(t: table)` (writes `state.encode(t)` to `state.PATH`). `state.load() -> table|nil` (nil if the file doesn't exist). `state.clear()` (deletes the file if present; uses `fs.delete` on a turtle, `os.remove` under plain Lua).
- Consumes: global `io` (present in both plain Lua and CC: Tweaked), and `fs`/`os.remove` for `clear()`.

The saved fields are exactly: `x, y, z, facing, sliceY, width, length, depth, voidJunk`.

- [ ] **Step 1: Write the failing tests**

Create `tests/state_test.lua`:

```lua
dofile("tests/support/bootstrap.lua")

local state = dofile("/lib/state.lua")
state.PATH = "./tests/tmp_state.txt"
state.clear()

local sample = {
  x = 3, y = -6, z = 9, facing = 2,
  sliceY = -6, width = 5, length = 7, depth = 100, voidJunk = true,
}

local encoded = state.encode(sample)
local decoded = state.decode(encoded)
for key, value in pairs(sample) do
  assert(decoded[key] == value, "mismatch on " .. key)
end

assert(state.load() == nil)

state.save(sample)
local loaded = state.load()
for key, value in pairs(sample) do
  assert(loaded[key] == value, "mismatch on " .. key .. " after save/load")
end

state.clear()
assert(state.load() == nil)

print("OK")
```

- [ ] **Step 2: Run the tests, confirm they fail**

Run: `lua tests/state_test.lua`
Expected: an error such as `cannot open /lib/state.lua`.

- [ ] **Step 3: Implement `lib/state.lua`**

```lua
local state = {}

state.PATH = "/quarry_state.txt"

local FIELDS = {"x", "y", "z", "facing", "sliceY", "width", "length", "depth", "voidJunk"}

function state.encode(t)
  local lines = {}
  for _, key in ipairs(FIELDS) do
    lines[#lines + 1] = key .. "=" .. tostring(t[key])
  end
  return table.concat(lines, "\n")
end

function state.decode(text)
  local t = {}
  for line in text:gmatch("[^\n]+") do
    local key, value = line:match("^(%a+)=(.-)$")
    if value == "true" or value == "false" then
      t[key] = value == "true"
    else
      t[key] = tonumber(value)
    end
  end
  return t
end

function state.save(t)
  local file = io.open(state.PATH, "w")
  file:write(state.encode(t))
  file:close()
end

function state.load()
  local file = io.open(state.PATH, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return state.decode(text)
end

function state.clear()
  if fs then
    if fs.exists(state.PATH) then
      fs.delete(state.PATH)
    end
  else
    os.remove(state.PATH)
  end
end

return state
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `lua tests/state_test.lua`
Expected: `OK`

- [ ] **Step 5: Ignore the runtime state file**

Add a line to `.gitignore`:

```
quarry_state.txt
```

This is the file `state.save()` writes at the filesystem root (`state.PATH`'s default) — on a turtle, and locally too whenever CraftOS-PC's computer-0 folder is pointed at this repo (Task 9). It's per-run local state, not something to commit.

- [ ] **Step 6: Commit**

```bash
git add lib/state.lua tests/state_test.lua .gitignore
git commit -m "Add lib/state.lua: progress persistence for resuming after reboot"
```

---

## Task 5: `mining/quarry.lua` — argument parsing and the slice movement plan

**Files:**
- Create: `mining/quarry.lua`
- Test: `tests/quarry_test.lua`

**Interfaces:**
- Produces (this task only defines and tests these two pure pieces; `run`/`runSlice`/`resupply` are added in Task 6 in the same file): `quarry.parseArgs(args: {string}) -> (table|nil, string|nil)` — on success returns `{width, length, depth, voidJunk}` (numbers/boolean) and `nil`; on failure returns `nil` and an error string. `quarry.buildSlicePlan(width: integer, length: integer) -> {string}` — an ordered list of `"forward"`/`"turnRight"` moves that snakes across a `width × length` footprint (turn right twice = 180°, to reverse direction between rows).

This task creates the file with just these two functions plus a temporary `return {parseArgs = parseArgs, buildSlicePlan = buildSlicePlan}` — Task 6 replaces that final block once `run` exists.

- [ ] **Step 1: Write the failing tests**

Create `tests/quarry_test.lua`:

```lua
dofile("tests/support/bootstrap.lua")

_G.turtle = dofile("tests/support/mock_turtle.lua")()
local quarry = dofile("/mining/quarry.lua")

local parsed, err = quarry.parseArgs({"5", "7", "100", "true"})
assert(err == nil)
assert(parsed.width == 5)
assert(parsed.length == 7)
assert(parsed.depth == 100)
assert(parsed.voidJunk == true)

local missing, missingErr = quarry.parseArgs({"5", "7"})
assert(missing == nil)
assert(missingErr ~= nil)

local badBool, badBoolErr = quarry.parseArgs({"5", "7", "100", "maybe"})
assert(badBool == nil)
assert(badBoolErr ~= nil)

local plan = quarry.buildSlicePlan(2, 3)
local expected = {"forward", "forward", "turnRight", "forward", "turnRight", "forward", "forward"}
assert(#plan == #expected)
for i, move in ipairs(expected) do
  assert(plan[i] == move, "mismatch at move " .. i)
end

local singleRow = quarry.buildSlicePlan(1, 4)
assert(#singleRow == 3)
for _, move in ipairs(singleRow) do
  assert(move == "forward")
end

print("OK")
```

- [ ] **Step 2: Run the tests, confirm they fail**

Run: `lua tests/quarry_test.lua`
Expected: an error such as `cannot open /mining/quarry.lua`.

- [ ] **Step 3: Implement the parsing and plan-building parts of `mining/quarry.lua`**

```lua
local inventory = dofile("/lib/inventory.lua")
local nav = dofile("/lib/nav.lua")
local fuel = dofile("/lib/fuel.lua")
local state = dofile("/lib/state.lua")

local function parseArgs(args)
  local width = tonumber(args[1])
  local length = tonumber(args[2])
  local depth = tonumber(args[3])
  local voidJunkArg = args[4]

  if not width or not length or not depth then
    return nil, "usage: quarry <width> <length> <depth> <voidJunk: true|false>"
  end
  if voidJunkArg ~= "true" and voidJunkArg ~= "false" then
    return nil, "voidJunk must be 'true' or 'false'"
  end

  return {width = width, length = length, depth = depth, voidJunk = voidJunkArg == "true"}
end

local function buildSlicePlan(width, length)
  local moves = {}
  for row = 1, width do
    for _ = 1, length - 1 do
      moves[#moves + 1] = "forward"
    end
    if row < width then
      moves[#moves + 1] = "turnRight"
      moves[#moves + 1] = "forward"
      moves[#moves + 1] = "turnRight"
    end
  end
  return moves
end

return {
  parseArgs = parseArgs,
  buildSlicePlan = buildSlicePlan,
}
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `lua tests/quarry_test.lua`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add mining/quarry.lua tests/quarry_test.lua
git commit -m "Add quarry.lua argument parsing and slice movement plan"
```

---

## Task 6: `mining/quarry.lua` — dig loop, resupply, and resume

**Files:**
- Modify: `mining/quarry.lua` (replaces the trailing `return {...}` block from Task 5, adds `runSlice`, `resupply`, `run`, and the auto-run line)

**Interfaces:**
- Consumes: everything from Tasks 1-5 (`inventory`, `nav`, `fuel`, `state`, `parseArgs`, `buildSlicePlan`).
- Produces: `quarry.run(...)` — parses args (or resumes from `state.load()` if present), then digs 3-tall slices downward until `depth` is reached or a slice reports being blocked, saving state after each slice and dumping/refueling at the surface whenever fuel is low or the inventory is full. `quarry.parseArgs` / `quarry.buildSlicePlan` remain exported as before.

Physical layout assumed (from the spec): turtle starts at the surface facing into the quarry (`nav.facing == 0`); the fuel chest is directly behind that start position (absolute facing `2`); the item chest is directly to its left (absolute facing `3`).

No automated test covers `run`/`runSlice`/`resupply` themselves — they're thin orchestration over already-tested pieces, and their real behavior (does the turtle actually end up in the right place in a real or emulated world) can only be verified by running it, which Task 9 does in CraftOS-PC. This task's verification step is a manual dry-read plus confirming the file still loads and exports what Task 5's tests expect.

- [ ] **Step 1: Replace the final block of `mining/quarry.lua`**

Remove the `return {parseArgs = parseArgs, buildSlicePlan = buildSlicePlan}` line from the end of the file and replace it with:

```lua
local function resupply(returnPos, returnFacing)
  if not nav.goTo({x = 0, y = 0, z = 0}) then
    error("quarry: failed to return to the surface")
  end

  nav.rotateTo(2) -- fuel chest, directly behind the start position
  fuel.refuel()

  nav.rotateTo(3) -- item chest, to the left of the start position
  inventory.dumpToChest()

  nav.rotateTo(0)
  if not nav.goTo(returnPos) then
    error("quarry: failed to return to the dig position")
  end
  nav.rotateTo(returnFacing)
end

local function runSlice(width, length, args, sliceY)
  local plan = buildSlicePlan(width, length)

  nav.digUp()
  nav.digDown()
  for slot = 1, 16 do
    inventory.voidIfJunk(slot)
  end

  for _, move in ipairs(plan) do
    if move == "forward" then
      if not nav.forward() then
        return false
      end
      nav.digUp()
      nav.digDown()
      for slot = 1, 16 do
        inventory.voidIfJunk(slot)
      end
    elseif move == "turnRight" then
      nav.turnRight()
    end

    if not fuel.hasEnoughToReturn(nav.pos, turtle.getFuelLevel()) or inventory.isFull() then
      resupply({x = nav.pos.x, y = nav.pos.y, z = nav.pos.z}, nav.facing)
    end
  end

  state.save({
    x = nav.pos.x, y = nav.pos.y, z = nav.pos.z, facing = nav.facing,
    sliceY = sliceY, width = args.width, length = args.length,
    depth = args.depth, voidJunk = args.voidJunk,
  })

  return true
end

local function run(...)
  local parsed, err = parseArgs({...})
  local sliceY = 0

  local saved = state.load()
  if saved then
    parsed = {width = saved.width, length = saved.length, depth = saved.depth, voidJunk = saved.voidJunk}
    nav.setPosition({x = saved.x, y = saved.y, z = saved.z}, saved.facing)
    sliceY = saved.sliceY
    print("Resuming quarry from saved progress.")
  elseif not parsed then
    print(err)
    return
  else
    for _ = 1, 3 do
      if not nav.down() then break end
    end
  end

  while sliceY > -parsed.depth do
    local ok = runSlice(parsed.width, parsed.length, parsed, sliceY)
    if not ok then
      print("Quarry stopped: hit an unbreakable block or got stuck.")
      return -- leave the saved state in place so this can be inspected/resumed
    end
    sliceY = sliceY - 3
    if sliceY > -parsed.depth then
      nav.down()
      nav.down()
      nav.down()
    end
  end

  state.clear()
  print("Quarry finished.")
end

run(...)

return {
  parseArgs = parseArgs,
  buildSlicePlan = buildSlicePlan,
  run = run,
}
```

- [ ] **Step 2: Confirm Task 5's tests still pass**

Run: `lua tests/quarry_test.lua`
Expected: `OK` (the auto `run(...)` call at load time gets no args when the file is `dofile`d without any, so `parseArgs({})` fails fast, prints the usage string, and returns immediately — before `state.load()`/`nav`/`turtle` are touched further, since `state.load()` also returns `nil` when there's no state file in the test working directory).

- [ ] **Step 3: Commit**

```bash
git add mining/quarry.lua
git commit -m "Add quarry.lua dig loop, resupply trip, and reboot resume"
```

---

## Task 7: `install.lua`

**Files:**
- Create: `install.lua` (repo root)
- Test: `tests/install_test.lua`

**Interfaces:**
- Produces: `install.buildFileList(scriptName: string) -> {{url: string, dest: string}}` (pure — one entry for `mining/<scriptName>.lua` → `/<scriptName>`, then one entry per file in `lib/` → `/lib/<file>`). The file's top level also calls `install(args[1])`, which downloads each listed file via `wget` (only meaningful on a turtle, where `fs`/`shell` exist).

- [ ] **Step 1: Write the failing test**

Create `tests/install_test.lua`:

```lua
dofile("tests/support/bootstrap.lua")

local install = dofile("/install.lua")

local files = install.buildFileList("quarry")
assert(#files == 5)
assert(files[1].url:match("/mining/quarry%.lua$") ~= nil)
assert(files[1].dest == "/quarry")
assert(files[2].dest == "/lib/nav.lua")
assert(files[3].dest == "/lib/fuel.lua")
assert(files[4].dest == "/lib/inventory.lua")
assert(files[5].dest == "/lib/state.lua")

print("OK")
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `lua tests/install_test.lua`
Expected: an error such as `cannot open /install.lua`.

- [ ] **Step 3: Implement `install.lua`**

```lua
local REPO_RAW_BASE = "https://raw.githubusercontent.com/YOUR_GITHUB_USER/minecraft-turtle-scripts/main"

local LIB_FILES = {"nav.lua", "fuel.lua", "inventory.lua", "state.lua"}

local function buildFileList(scriptName)
  local files = {
    {url = REPO_RAW_BASE .. "/mining/" .. scriptName .. ".lua", dest = "/" .. scriptName},
  }
  for _, libFile in ipairs(LIB_FILES) do
    files[#files + 1] = {url = REPO_RAW_BASE .. "/lib/" .. libFile, dest = "/lib/" .. libFile}
  end
  return files
end

local function install(scriptName)
  if not scriptName then
    print("usage: install <script name, e.g. quarry>")
    return
  end

  if not fs.exists("/lib") then
    fs.makeDir("/lib")
  end

  for _, file in ipairs(buildFileList(scriptName)) do
    print("Downloading " .. file.url .. " ...")
    local ok = shell.run("wget", file.url, file.dest)
    if not ok then
      print("Failed to download " .. file.url)
      return
    end
  end

  print("Installed '" .. scriptName .. "'. Run it with: " .. scriptName .. " <width> <length> <depth> <true|false>")
end

install(({...})[1])

return {buildFileList = buildFileList}
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `lua tests/install_test.lua`
Expected: `OK` (the `install(({...})[1])` call gets `nil` since the test's `dofile` passes no varargs, so it just prints the usage line and returns before touching `fs`/`shell`, which don't exist under plain Lua).

- [ ] **Step 5: Run the full local test suite**

Run: `./tests/run_all.sh`
Expected: every `tests/*_test.lua` file prints `OK`, script exits 0.

- [ ] **Step 6: Commit**

```bash
git add install.lua tests/install_test.lua
git commit -m "Add install.lua: wget-based bootstrap for a fresh turtle"
```

**Note:** `YOUR_GITHUB_USER` is a placeholder (see the spec) — once this repo is pushed to GitHub, update `REPO_RAW_BASE` and the README's install command with the real owner/repo path.

---

## Task 8: README (bilingual)

**Files:**
- Modify: `README.md`

**Interfaces:** none (documentation only).

Per `CLAUDE.md`'s documentation-language convention, this is user-facing, so it needs both German and English, written for someone with no programming background: what to physically place where, the exact command to type, and what to expect. Keep the existing "Layout" and "Testing locally with CraftOS-PC" sections (still developer-facing/English), and add a new bilingual "Quarry" walkthrough section.

- [ ] **Step 1: Add the bilingual quarry walkthrough**

Insert a new section into `README.md`, after the existing "Testing locally with CraftOS-PC" section:

```markdown
## Running the quarry script (Deutsch / English)

### Deutsch

1. **Zwei Truhen aufstellen.** Stelle dich an die Stelle, wo die Turtle
   starten soll, mit Blick in die Richtung, in die der Steinbruch gehen
   soll. Stelle direkt **hinter** dir eine Truhe auf — das ist die
   Treibstoff-Truhe, dort hinein kommt Kohle o. ä. Stelle direkt **links**
   von dir eine zweite Truhe auf — das ist die Item-Truhe, dort landen die
   abgebauten Materialien.
2. **Turtle aufstellen und Skript installieren.** Stelle die Turtle genau
   an deine Position (mit derselben Blickrichtung) und gib in ihrem
   Terminal ein:
   ```
   wget run https://raw.githubusercontent.com/YOUR_GITHUB_USER/minecraft-turtle-scripts/main/install.lua quarry
   ```
   Das lädt das Skript und alles, was es braucht, einmalig herunter.
3. **Steinbruch starten.** Gib ein:
   ```
   quarry <Breite> <Länge> <Tiefe> <true|false>
   ```
   Zum Beispiel `quarry 8 8 64 true` gräbt ein 8×8 Feld 64 Blöcke tief
   und wirft dabei nutzlose Blöcke (Erde, Kies, Stein usw.) direkt weg,
   statt sie mitzuschleppen. Mit `false` statt `true` wird stattdessen
   alles behalten.
4. **Fertig warten lassen.** Die Turtle kehrt von selbst zur Oberfläche
   zurück, wenn Treibstoff oder Platz im Inventar knapp werden, tankt/leert
   sich an den beiden Truhen und macht danach automatisch weiter. Startet
   der Server neu oder die Turtle geht aus, reicht ein erneutes `quarry`
   ohne Argumente — sie merkt sich, wo sie war.

### English

1. **Place two chests.** Stand where the turtle should start, facing the
   direction the quarry should dig into. Place a chest directly **behind**
   you — that's the fuel chest, put coal or similar fuel in it. Place a
   second chest directly to your **left** — that's the item chest, mined
   materials end up there.
2. **Place the turtle and install the script.** Put the turtle exactly at
   your position (facing the same way), and in its terminal type:
   ```
   wget run https://raw.githubusercontent.com/YOUR_GITHUB_USER/minecraft-turtle-scripts/main/install.lua quarry
   ```
   That downloads the script and everything it needs, once.
3. **Start the quarry.** Type:
   ```
   quarry <width> <length> <depth> <true|false>
   ```
   For example, `quarry 8 8 64 true` digs an 8×8 area 64 blocks deep,
   dropping useless blocks (dirt, gravel, stone, etc.) immediately instead
   of hauling them, rather than keeping everything if you pass `false`.
4. **Let it run.** The turtle returns to the surface on its own whenever
   fuel or inventory space runs low, refuels/empties itself at the two
   chests, then keeps going automatically. If the server restarts or the
   turtle loses power, just run `quarry` again with no arguments — it
   remembers where it left off.
```

- [ ] **Step 2: Review by reading it aloud / through once**

Confirm both language versions cover the same four steps in the same order, and that the placeholder `YOUR_GITHUB_USER` matches the one used in `install.lua`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Document the quarry script setup and usage in German and English"
```

---

## Task 9: Manual CraftOS-PC verification

**Files:** none (this is a manual, out-of-session verification step — it needs CraftOS-PC, which isn't installed in this environment).

**Interfaces:** none.

This is the integration-level check the spec calls for: the unit tests in Tasks 0-7 cover the pure logic and the impure functions' turtle-call sequences via mocks, but not whether the whole thing actually behaves correctly in a (simulated) world. Hand this task to whoever has CraftOS-PC installed (see `README.md`'s "Testing locally with CraftOS-PC" section for setup).

- [ ] **Step 1: Point CraftOS-PC's computer-0 folder at this repo**

In CraftOS-PC's settings, set computer 0's data directory to this repo's root, so `/lib/...` resolves the same way it will on a real turtle.

- [ ] **Step 2: Run a small test quarry**

From the CraftOS-PC shell:

```
cd mining
quarry 3 3 6 true
```

Confirm: the turtle digs straight down, then clears a 3×3 area in 3-tall slices down to depth 6, voids junk blocks, and prints "Quarry finished." at the end.

- [ ] **Step 3: Force a resupply trip**

Run a bigger test (e.g. `quarry 3 3 30 true`) with a turtle that starts with low fuel (a handful of coal) and a nearly-full inventory, with both a fuel chest and an item chest placed per the README's layout. Confirm the turtle actually stops, returns to the origin, refuels/dumps, and resumes digging from where it left off (not from the top).

- [ ] **Step 4: Force a reboot mid-run**

Mid-quarry, reboot the CraftOS-PC computer (or terminate and restart it) and re-run `quarry` with no arguments. Confirm it resumes from the saved slice/position instead of restarting.

- [ ] **Step 5: Note any calibration fixes needed**

The exact fencepost behavior around slice boundaries and the initial descent (how many blocks down before the first slice starts) is the one part of this design not proven by the unit tests — if it's off by one slice in practice, adjust the initial `nav.down()` count and/or the `sliceY > -parsed.depth` loop condition in `mining/quarry.lua`'s `run` function, and add a one-line comment noting why, then commit the fix.

- [ ] **Step 6: Clean up leftover state file**

Since CraftOS-PC's computer-0 folder is pointed at this repo's root, a finished or interrupted test run writes `/quarry_state.txt` at the repo root (matching `state.PATH`'s default). It's already covered by the `.gitignore` entry added in Task 4, but confirm it's actually gone (`git status` shouldn't show it) before wrapping up.

