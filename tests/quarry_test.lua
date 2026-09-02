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
