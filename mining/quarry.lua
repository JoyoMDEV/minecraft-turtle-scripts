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

return {
  parseArgs = parseArgs,
  buildSlicePlan = buildSlicePlan,
}
