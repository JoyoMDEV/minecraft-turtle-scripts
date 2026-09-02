dofile("tests/support/bootstrap.lua")
local newMockTurtle = dofile("tests/support/mock_turtle.lua")

-- Junk classification is pure and doesn't need a real mock.
_G.turtle = newMockTurtle()
local inventory = dofile("/lib/inventory.lua")

assert(inventory.isJunk("minecraft:dirt") == true)
assert(inventory.isJunk("minecraft:gravel") == true)
assert(inventory.isJunk("minecraft:diamond_ore") == false)
assert(inventory.isJunk("minecraft:cobblestone") == false)

-- isFull(): true as soon as no slot is completely empty, even if some of the
-- occupied slots still have room in their stack.
_G.turtle = newMockTurtle({getItemCount = function() return 64 end})
inventory = dofile("/lib/inventory.lua")
assert(inventory.isFull() == true)

_G.turtle = newMockTurtle({
  getItemCount = function(slot)
    if slot == 5 then return 1 end
    return 64
  end,
  getItemSpace = function(slot)
    if slot == 5 then return 63 end
    return 0
  end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.isFull() == true, "a partially-filled stack must not keep isFull() false")

_G.turtle = newMockTurtle({
  getItemCount = function(slot)
    if slot == 5 then return 0 end
    return 64
  end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.isFull() == false)

-- voidIfJunk(): drops a junk item in the given slot, leaves others alone.
local selected, dropped = nil, false
_G.turtle = newMockTurtle({
  getItemDetail = function(slot)
    if slot == 3 then return {name = "minecraft:dirt", count = 64} end
    return nil
  end,
  select = function(slot) selected = slot return true end,
  drop = function() dropped = true return true end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.voidIfJunk(3) == true)
assert(selected == 3)
assert(dropped == true)
assert(inventory.voidIfJunk(4) == false)

-- selectSealingItem(): finds and selects cobblestone if present.
local sealingSelected = nil
_G.turtle = newMockTurtle({
  getItemDetail = function(slot)
    if slot == 7 then return {name = "minecraft:cobblestone", count = 10} end
    return nil
  end,
  select = function(slot) sealingSelected = slot return true end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.selectSealingItem() == true)
assert(sealingSelected == 7)

_G.turtle = newMockTurtle({getItemDetail = function() return nil end})
inventory = dofile("/lib/inventory.lua")
assert(inventory.selectSealingItem() == false)

-- dumpToChest(): drops every non-empty slot, then re-selects slot 1.
local calls = {}
_G.turtle = newMockTurtle({
  getItemCount = function(slot)
    if slot == 2 or slot == 9 then return 64 end
    return 0
  end,
  select = function(slot) calls[#calls + 1] = {"select", slot} return true end,
  drop = function() calls[#calls + 1] = {"drop"} return true end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.dumpToChest() == true)
assert(calls[1][1] == "select" and calls[1][2] == 2)
assert(calls[2][1] == "drop")
assert(calls[3][1] == "select" and calls[3][2] == 9)
assert(calls[4][1] == "drop")
assert(calls[5][1] == "select" and calls[5][2] == 1)

-- dumpToChest(): reports false when there was nothing to drop.
_G.turtle = newMockTurtle({getItemCount = function() return 0 end})
inventory = dofile("/lib/inventory.lua")
assert(inventory.dumpToChest() == false)

-- dumpToChest(): reports false when the drops themselves fail (full chest).
_G.turtle = newMockTurtle({
  getItemCount = function() return 64 end,
  drop = function() return false end,
})
inventory = dofile("/lib/inventory.lua")
assert(inventory.dumpToChest() == false)

print("OK")
