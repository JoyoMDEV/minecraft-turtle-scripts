local TURTLE_METHODS = {
  "detect", "detectUp", "detectDown",
  "dig", "digUp", "digDown",
  "inspect", "inspectUp", "inspectDown",
  "place", "placeUp", "placeDown",
  "forward", "up", "down",
  "turnLeft", "turnRight",
  "attack", "attackUp", "attackDown",
  "suck", "refuel", "select",
  "getItemDetail", "getItemCount", "getItemSpace",
  "getFuelLevel", "drop",
}

local function newMockTurtle(script)
  script = script or {}
  local mock = {calls = {}}

  local function record(name)
    return function(...)
      mock.calls[#mock.calls + 1] = name
      local handler = script[name]
      if type(handler) == "function" then
        return handler(...)
      end
      if handler == nil then
        return true
      end
      return handler
    end
  end

  for _, name in ipairs(TURTLE_METHODS) do
    mock[name] = record(name)
  end

  return mock
end

return newMockTurtle
