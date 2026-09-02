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

-- width=3 is the first width where the lateral turn direction has to
-- alternate: reusing turnRight at the end of row 2 would step back into the
-- column just dug. width=2 can't catch that, so assert width=3 explicitly.
local wide = quarry.buildSlicePlan(3, 3)
local wideExpected = {
  "forward", "forward", "turnRight", "forward", "turnRight",
  "forward", "forward", "turnLeft", "forward", "turnLeft",
  "forward", "forward",
}
assert(#wide == #wideExpected)
for i, move in ipairs(wideExpected) do
  assert(wide[i] == move, "mismatch at move " .. i)
end

-- Walk a plan through nav's own facing/position math and check the footprint
-- it actually covers. This is the assertion that catches a snake folding back
-- onto itself without needing an emulator.
local nav = dofile("/lib/nav.lua")

local function walkPlan(width, length)
  local plan = quarry.buildSlicePlan(width, length)
  local pos, facing = {x = 0, y = 0, z = 0}, 0
  local visits, cellCount = {}, 0

  local function visit()
    local key = pos.x .. "," .. pos.z
    if not visits[key] then
      visits[key] = 0
      cellCount = cellCount + 1
    end
    visits[key] = visits[key] + 1
  end

  visit()
  for i, move in ipairs(plan) do
    if move == "forward" then
      pos = nav.stepForward(pos, facing)
      visit()
    elseif move == "turnRight" then
      facing = nav.turnRightFacing(facing)
    elseif move == "turnLeft" then
      facing = nav.turnLeftFacing(facing)
    else
      error("unknown move '" .. tostring(move) .. "' at index " .. i)
    end
  end

  return visits, cellCount
end

local footprints = {{1, 4}, {2, 3}, {3, 3}, {4, 5}}
for _, dims in ipairs(footprints) do
  local width, length = dims[1], dims[2]
  local label = width .. "x" .. length
  local visits, cellCount = walkPlan(width, length)

  assert(cellCount == width * length,
    label .. ": visited " .. cellCount .. " cells, expected " .. width * length)

  for x = 0, width - 1 do
    for z = 0, length - 1 do
      local key = x .. "," .. z
      assert(visits[key] == 1,
        label .. ": cell " .. key .. " visited " .. tostring(visits[key]) .. " times, expected 1")
    end
  end
end

print("OK")
