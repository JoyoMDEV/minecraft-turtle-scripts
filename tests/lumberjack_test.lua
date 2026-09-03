dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

-- isLog/isSapling are pure name matchers, no turtle interaction needed.
_G.turtle = newMockTurtle()
local pure = dofile("/tree-farm/lumberjack.lua")
assert(pure.isLog("minecraft:oak_log") == true)
assert(pure.isLog("minecraft:birch_log") == true)
assert(pure.isLog("minecraft:oak_sapling") == false)
assert(pure.isSapling("minecraft:jungle_sapling") == true)
assert(pure.isSapling("minecraft:dirt") == false)

-- Nothing in front and a sapling on hand: plants it.
_G.turtle = newMockTurtle({
  inspect = function() return false end,
  getItemDetail = function(slot)
    if slot == 1 then return {name = "minecraft:oak_sapling"} end
    return nil
  end,
})
local plants = dofile("/tree-farm/lumberjack.lua")
assert(plants.checkAndAct() == "planted")
local sawSelect, sawPlace = false, false
for _, call in ipairs(_G.turtle.calls) do
  if call == "select" then sawSelect = true end
  if call == "place" then sawPlace = true end
end
assert(sawSelect and sawPlace)

-- Nothing in front and no sapling on hand: nothing to do yet.
_G.turtle = newMockTurtle({
  inspect = function() return false end,
  getItemDetail = function() return nil end,
})
local idle = dofile("/tree-farm/lumberjack.lua")
assert(idle.checkAndAct() == "idle")

-- A sapling is growing and bone meal is on hand: fertilizes and waits.
_G.turtle = newMockTurtle({
  inspect = function() return true, {name = "minecraft:oak_sapling"} end,
  getItemDetail = function(slot)
    if slot == 2 then return {name = "minecraft:bone_meal"} end
    return nil
  end,
})
local fertilizing = dofile("/tree-farm/lumberjack.lua")
assert(fertilizing.checkAndAct() == "waiting")
local usedBoneMeal = false
for _, call in ipairs(_G.turtle.calls) do
  if call == "place" then usedBoneMeal = true end
end
assert(usedBoneMeal)

-- A sapling is growing but there's no bone meal: just waits, no place call.
_G.turtle = newMockTurtle({
  inspect = function() return true, {name = "minecraft:oak_sapling"} end,
  getItemDetail = function() return nil end,
})
local waitingOnly = dofile("/tree-farm/lumberjack.lua")
assert(waitingOnly.checkAndAct() == "waiting")
for _, call in ipairs(_G.turtle.calls) do
  assert(call ~= "place", "should not place anything without bone meal")
end

-- A grown trunk (2 log blocks above the base) in front: chops the whole
-- column, returns to the starting spot/facing, and replants.
do
  local baseDug = false
  local height = 0
  local duggedAbove = {}

  _G.turtle = newMockTurtle({
    detect = function() return not baseDug end,
    dig = function() baseDug = true; return true end,
    inspect = function()
      if baseDug then return false end
      return true, {name = "minecraft:oak_log"}
    end,
    detectUp = function() return not duggedAbove[height] and height < 2 end,
    inspectUp = function()
      if duggedAbove[height] or height >= 2 then return false end
      return true, {name = "minecraft:oak_log"}
    end,
    digUp = function() duggedAbove[height] = true; return true end,
    up = function() height = height + 1; return true end,
    down = function() height = height - 1; return true end,
    getItemDetail = function(slot)
      if slot == 1 then return {name = "minecraft:oak_sapling"} end
      return nil
    end,
  })

  local chopping = dofile("/tree-farm/lumberjack.lua")
  assert(chopping.checkAndAct() == "chopped")
  assert(height == 0, "should return to ground level, got height " .. height)

  local turnRights, ups, downs = 0, 0, 0
  for _, call in ipairs(_G.turtle.calls) do
    if call == "turnRight" then turnRights = turnRights + 1 end
    if call == "up" then ups = ups + 1 end
    if call == "down" then downs = downs + 1 end
  end
  assert(ups == 2, "expected to climb 2 log blocks, climbed " .. ups)
  assert(downs == 2, "expected to descend the same 2 blocks, descended " .. downs)
  assert(turnRights == 4, "expected two 180-degree turns, got " .. turnRights)
end

-- Resupply: rotates to the chest behind, dumps the inventory, and restocks.
do
  _G.turtle = newMockTurtle({
    getItemCount = function(slot) if slot == 3 then return 64 end return 0 end,
  })
  local resupplying = dofile("/tree-farm/lumberjack.lua")
  resupplying.resupply()

  local turnRights, drops, sucks = 0, 0, 0
  for _, call in ipairs(_G.turtle.calls) do
    if call == "turnRight" then turnRights = turnRights + 1 end
    if call == "drop" then drops = drops + 1 end
    if call == "suck" then sucks = sucks + 1 end
  end
  assert(turnRights == 4, "expected to rotate to the chest and back, got " .. turnRights)
  assert(drops >= 1, "expected the full slot to be dumped")
  assert(sucks >= 1, "expected at least one restock attempt")
end

print("OK")
