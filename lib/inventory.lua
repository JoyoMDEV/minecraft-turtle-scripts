local inventory = {}

inventory.SEALING_ITEM = "minecraft:cobblestone"

local JUNK_BLOCKS = {
  ["minecraft:dirt"] = true,
  ["minecraft:gravel"] = true,
  ["minecraft:sand"] = true,
  ["minecraft:netherrack"] = true,
  ["minecraft:diorite"] = true,
  ["minecraft:andesite"] = true,
  ["minecraft:granite"] = true,
  ["minecraft:stone"] = true,
  ["minecraft:deepslate"] = true,
  ["minecraft:cobbled_deepslate"] = true,
}

function inventory.isJunk(itemName)
  if itemName == inventory.SEALING_ITEM then
    return false
  end
  return JUNK_BLOCKS[itemName] == true
end

-- Full means "no completely empty slot left". Waiting for every slot to have
-- zero *space* is too lenient with mixed loot: one partially-filled stack
-- keeps that false forever while newly mined blocks that fit nowhere are
-- simply lost.
function inventory.isFull()
  for slot = 1, 16 do
    if turtle.getItemCount(slot) == 0 then
      return false
    end
  end
  return true
end

function inventory.voidIfJunk(slot)
  local detail = turtle.getItemDetail(slot)
  if detail and inventory.isJunk(detail.name) then
    turtle.select(slot)
    turtle.drop()
    return true
  end
  return false
end

function inventory.selectSealingItem()
  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and detail.name == inventory.SEALING_ITEM then
      turtle.select(slot)
      return true
    end
  end
  return false
end

-- Returns true if at least one slot was actually dropped, false if there was
-- nothing to drop (or nothing could be dropped), so callers can tell an
-- offload trip that achieved nothing from a successful one.
function inventory.dumpToChest()
  local dropped = false
  for slot = 1, 16 do
    if turtle.getItemCount(slot) > 0 then
      turtle.select(slot)
      if turtle.drop() then
        dropped = true
      end
    end
  end
  turtle.select(1)
  return dropped
end

return inventory
