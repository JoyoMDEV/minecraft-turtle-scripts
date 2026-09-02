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
