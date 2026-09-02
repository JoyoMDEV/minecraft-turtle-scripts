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
