local nav = dofile("/lib/nav.lua")
local fuel = dofile("/lib/fuel.lua")
local inventory = dofile("/lib/inventory.lua")

local lumberjack = {}

lumberjack.POLL_INTERVAL_SECONDS = 30
lumberjack.BONE_MEAL_ITEM = "minecraft:bone_meal"

-- The chest sits directly behind the start position, mirroring the quarry
-- script's fuel-chest convention.
local BEHIND_FACING = 2
local FORWARD_FACING = 0
local RESTOCK_SUCK_ATTEMPTS = 3

function lumberjack.isLog(name)
  return name ~= nil and name:match("_log$") ~= nil
end

function lumberjack.isSapling(name)
  return name ~= nil and name:match("_sapling$") ~= nil
end

local function findItemSlot(predicate)
  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and predicate(detail.name) then
      return slot
    end
  end
  return nil
end

function lumberjack.plantSapling()
  local slot = findItemSlot(lumberjack.isSapling)
  if not slot then
    return false
  end
  turtle.select(slot)
  return turtle.place()
end

function lumberjack.applyBoneMeal()
  local slot = findItemSlot(function(name) return name == lumberjack.BONE_MEAL_ITEM end)
  if not slot then
    return false
  end
  turtle.select(slot)
  return turtle.place()
end

-- Climbs the trunk one block at a time for as long as there's a log
-- directly above, then returns to the ground position it started from.
-- Leaves are left untouched once no more log blocks are found, matching
-- the thin-trunk assumption (oak/birch/spruce/jungle) this script targets.
function lumberjack.chopTrunk()
  if not nav.forward() then
    return false
  end

  local climbed = 0
  while true do
    local hasBlock, data = turtle.inspectUp()
    if not (hasBlock and lumberjack.isLog(data.name)) then
      break
    end
    if not nav.up() then
      break
    end
    climbed = climbed + 1
  end

  for _ = 1, climbed do
    nav.down()
  end

  nav.turnRight()
  nav.turnRight()
  nav.forward()
  nav.turnRight()
  nav.turnRight()

  return true
end

-- Looks at the block in front and does the one thing it calls for: plant,
-- fertilize/wait, or chop a finished trunk and replant. Returns a status
-- ("planted", "idle", "waiting", "chopped") so the caller knows whether to
-- pause before checking again.
function lumberjack.checkAndAct()
  local hasBlock, data = turtle.inspect()

  if not hasBlock then
    if lumberjack.plantSapling() then
      return "planted"
    end
    return "idle"
  end

  if lumberjack.isLog(data.name) then
    lumberjack.chopTrunk()
    lumberjack.plantSapling()
    return "chopped"
  end

  lumberjack.applyBoneMeal()
  return "waiting"
end

-- Dumps the inventory into the chest behind, then restocks fuel and
-- saplings/bone meal from the same chest, mirroring the quarry script's
-- resupply pattern but with a single chest instead of two.
function lumberjack.resupply()
  nav.rotateTo(BEHIND_FACING)
  inventory.dumpToChest()
  fuel.refuel()
  for _ = 1, RESTOCK_SUCK_ATTEMPTS do
    turtle.suck()
  end
  nav.rotateTo(FORWARD_FACING)
end

local function needsResupply()
  return inventory.isFull()
    or not fuel.hasEnoughToReturn(nav.pos, turtle.getFuelLevel())
    or not findItemSlot(lumberjack.isSapling)
end

local function run()
  while true do
    if needsResupply() then
      lumberjack.resupply()
    end
    local status = lumberjack.checkAndAct()
    if status == "waiting" or status == "idle" then
      sleep(lumberjack.POLL_INTERVAL_SECONDS)
    end
  end
end

-- `fs` only exists in the real CC:Tweaked environment, not under the plain
-- `lua` interpreter the test suite runs under, so this is a safe way to skip
-- the infinite loop when the file is just being dofile'd for its functions.
if fs then
  run()
end

return lumberjack
