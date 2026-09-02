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
      -- The lateral turn direction has to alternate: a row is walked in the
      -- opposite heading to the one before it, so the same turn direction
      -- would step back into the column that was just dug. Odd rows head
      -- +z and turn right, even rows head -z and turn left; both end up
      -- stepping +x and reversing the heading.
      local turn = (row % 2 == 1) and "turnRight" or "turnLeft"
      moves[#moves + 1] = turn
      moves[#moves + 1] = "forward"
      moves[#moves + 1] = turn
    end
  end
  return moves
end

local function reportStuck()
  print("Quarry stopped: hit an unbreakable block or got stuck. Delete " ..
    state.PATH .. " to start over instead of resuming.")
end

local function saveProgress(sliceY, args)
  state.save({
    x = nav.pos.x, y = nav.pos.y, z = nav.pos.z, facing = nav.facing,
    sliceY = sliceY, width = args.width, length = args.length,
    depth = args.depth, voidJunk = args.voidJunk,
  })
end

-- Every slice plan assumes it starts at the slice's origin corner facing +z,
-- but a snake always ends at the opposite corner facing outward. Re-home
-- before starting a slice so the plan stays inside the requested volume.
local function homeToSliceOrigin()
  if not nav.goTo({x = 0, y = nav.pos.y, z = 0}) then
    return false
  end
  nav.rotateTo(0)
  return true
end

local function resupply(returnPos, returnFacing)
  -- Work out what this trip is actually for before moving, since the fuel
  -- check depends on the current (deep) position.
  local neededFuel = not fuel.hasEnoughToReturn(nav.pos, turtle.getFuelLevel())
  local neededDump = inventory.isFull()

  if not nav.goTo({x = 0, y = 0, z = 0}) then
    error("quarry: failed to return to the surface")
  end

  nav.rotateTo(2) -- fuel chest, directly behind the start position
  local refuelled = fuel.refuel()
  if neededFuel and not refuelled then
    error("quarry: out of fuel and the fuel chest is empty - refill it and run quarry again to resume")
  end

  nav.rotateTo(3) -- item chest, to the left of the start position
  local dumped = inventory.dumpToChest()
  if neededDump and not dumped then
    error("quarry: inventory is full but nothing could be dropped - is the item chest full or missing?")
  end

  nav.rotateTo(0)
  if not nav.goTo(returnPos) then
    error("quarry: failed to return to the dig position")
  end
  nav.rotateTo(returnFacing)
end

-- Clear the block above and below the current position (the other two layers
-- of the 3-tall slice), then void junk if the run was started with voidJunk.
-- Returns false when a block above or below can't be broken (bedrock).
local function clearColumn(voidJunk)
  if not nav.digUp() then
    return false
  end
  if not nav.digDown() then
    return false
  end
  if voidJunk then
    for slot = 1, 16 do
      inventory.voidIfJunk(slot)
    end
  end
  return true
end

local function runSlice(width, length, args, sliceY)
  local plan = buildSlicePlan(width, length)

  if not clearColumn(args.voidJunk) then
    return false
  end

  for _, move in ipairs(plan) do
    if move == "forward" then
      if not nav.forward() then
        return false
      end
      if not clearColumn(args.voidJunk) then
        return false
      end
    elseif move == "turnRight" then
      nav.turnRight()
    elseif move == "turnLeft" then
      nav.turnLeft()
    end

    if not fuel.hasEnoughToReturn(nav.pos, turtle.getFuelLevel()) or inventory.isFull() then
      resupply({x = nav.pos.x, y = nav.pos.y, z = nav.pos.z}, nav.facing)
    end
  end

  saveProgress(sliceY, args)

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
    -- Progress is only ever saved at a slice boundary, so the saved position
    -- can be the outward-facing corner where the last snake ended. Re-home
    -- before replaying the plan; re-walking an already-dug slice is cheap
    -- (it's all air) and keeps the dig inside the requested volume.
    if not homeToSliceOrigin() then
      reportStuck()
      return
    end
  elseif not parsed then
    print(err)
    return
  else
    -- Descend 2, not 3: the first slice then sits at y=-2 and its
    -- digUp/digDown sweep covers y=-1/-2/-3, leaving no undug ceiling layer
    -- just below the surface.
    for _ = 1, 2 do
      if not nav.down() then break end
    end
  end

  while sliceY > -parsed.depth do
    local ok = runSlice(parsed.width, parsed.length, parsed, sliceY)
    if not ok then
      reportStuck()
      return -- leave the saved state in place so this can be inspected/resumed
    end
    sliceY = sliceY - 3
    if sliceY > -parsed.depth then
      for _ = 1, 3 do
        if not nav.down() then
          reportStuck()
          return
        end
      end
      if not homeToSliceOrigin() then
        reportStuck()
        return
      end
      -- Save again now that the descent is done, so a reboot in this window
      -- doesn't resume with a tracked position above the turtle's real one.
      saveProgress(sliceY, parsed)
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
