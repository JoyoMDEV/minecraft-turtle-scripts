dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

local mock = newMockTurtle({detect = function() return false end})
assert(mock.detect() == false)
assert(mock.calls[1] == "detect")

local mock2 = newMockTurtle()
assert(mock2.forward() == true)
assert(mock2.calls[1] == "forward")

print("OK")
