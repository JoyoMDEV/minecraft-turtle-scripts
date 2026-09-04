dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

-- quarry.lua keeps its own `state` local and never exposes it, so tests
-- can't repoint state.PATH away from the real (repo-root-absolute) save
-- path the normal way. Intercept just that one dofile call and hand back a
-- single shared instance pointed at a tmp file instead.
local realDofile = dofile
local sharedState
_G.dofile = function(path)
  if path == "/lib/state.lua" then
    if not sharedState then
      sharedState = realDofile(path)
      sharedState.PATH = "./tests/tmp_quarry_fuel_state.txt"
    end
    return sharedState
  end
  return realDofile(path)
end

local state = dofile("/lib/state.lua")
state.clear()

-- A 1x1 quarry never takes a single forward step (buildSlicePlan produces no
-- moves for width=1, length=1), so it never runs the per-move fuel check
-- runSlice does. The only fuel spend is the initial 2-block descent and the
-- 3-block descent between slices - both currently unchecked - so a turtle
-- that starts with too little fuel for the full depth should top up from the
-- fuel chest before it stops being able to move, not run dry and get stuck.
local fuelLevel = 25
local sucked = false

_G.turtle = newMockTurtle({
  getFuelLevel = function() return fuelLevel end,
  forward = function()
    if fuelLevel <= 0 then return false end
    fuelLevel = fuelLevel - 1
    return true
  end,
  down = function()
    if fuelLevel <= 0 then return false end
    fuelLevel = fuelLevel - 1
    return true
  end,
  up = function()
    if fuelLevel <= 0 then return false end
    fuelLevel = fuelLevel - 1
    return true
  end,
  suck = function()
    sucked = true
    return true
  end,
  getItemCount = function(slot)
    if slot == 1 and sucked then return 1 end
    return 0
  end,
  refuel = function()
    fuelLevel = fuelLevel + 1000
    return true
  end,
})

local quarry = dofile("/mining/quarry.lua")
quarry.run("1", "1", "30", "false")

local refuelCalls = 0
for _, call in ipairs(_G.turtle.calls) do
  if call == "refuel" then refuelCalls = refuelCalls + 1 end
end
assert(refuelCalls > 0,
  "expected the quarry to refuel from the chest before running out of fuel")

assert(state.load() == nil,
  "quarry should finish (and clear state) instead of getting stuck out of fuel")

state.clear()
print("OK")
