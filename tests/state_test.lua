dofile("tests/support/bootstrap.lua")

local state = dofile("/lib/state.lua")
state.PATH = "./tests/tmp_state.txt"
state.clear()

local sample = {
  x = 3, y = -6, z = 9, facing = 2,
  sliceY = -6, width = 5, length = 7, depth = 100, voidJunk = true,
}

local encoded = state.encode(sample)
local decoded = state.decode(encoded)
for key, value in pairs(sample) do
  assert(decoded[key] == value, "mismatch on " .. key)
end

assert(state.load() == nil)

state.save(sample)
local loaded = state.load()
for key, value in pairs(sample) do
  assert(loaded[key] == value, "mismatch on " .. key .. " after save/load")
end

state.clear()
assert(state.load() == nil)

print("OK")
