local fuel = {}

fuel.SAFETY_MARGIN = 20

function fuel.distanceTo(pos, target)
  target = target or {x = 0, y = 0, z = 0}
  return math.abs(pos.x - target.x) + math.abs(pos.y - target.y) + math.abs(pos.z - target.z)
end

function fuel.hasEnoughToReturn(pos, fuelLevel)
  if fuelLevel == "unlimited" then
    return true
  end
  return fuelLevel >= fuel.distanceTo(pos) + fuel.SAFETY_MARGIN
end

function fuel.refuel()
  local before = {}
  for slot = 1, 16 do
    before[slot] = turtle.getItemCount(slot)
  end

  turtle.suck()

  for slot = 1, 16 do
    if turtle.getItemCount(slot) > before[slot] then
      turtle.select(slot)
      return turtle.refuel()
    end
  end

  return false
end

return fuel
