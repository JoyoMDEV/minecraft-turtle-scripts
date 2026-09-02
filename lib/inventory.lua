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

function inventory.isFull()
  for slot = 1, 16 do
    if turtle.getItemSpace(slot) > 0 then
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

function inventory.dumpToChest()
  for slot = 1, 16 do
    if turtle.getItemCount(slot) > 0 then
      turtle.select(slot)
      turtle.drop()
    end
  end
  turtle.select(1)
end

return inventory
