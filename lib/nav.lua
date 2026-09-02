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
