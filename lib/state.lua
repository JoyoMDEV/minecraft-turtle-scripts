local state = {}

state.PATH = "/quarry_state.txt"

local FIELDS = {"x", "y", "z", "facing", "sliceY", "width", "length", "depth", "voidJunk"}

function state.encode(t)
  local lines = {}
  for _, key in ipairs(FIELDS) do
    lines[#lines + 1] = key .. "=" .. tostring(t[key])
  end
  return table.concat(lines, "\n")
end

function state.decode(text)
  local t = {}
  for line in text:gmatch("[^\n]+") do
    local key, value = line:match("^(%a+)=(.-)$")
    if value == "true" or value == "false" then
      t[key] = value == "true"
    else
      t[key] = tonumber(value)
    end
  end
  return t
end

function state.save(t)
  local file = io.open(state.PATH, "w")
  file:write(state.encode(t))
  file:close()
end

function state.load()
  local file = io.open(state.PATH, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return state.decode(text)
end

function state.clear()
  if fs then
    if fs.exists(state.PATH) then
      fs.delete(state.PATH)
    end
  else
    os.remove(state.PATH)
  end
end

return state
