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
