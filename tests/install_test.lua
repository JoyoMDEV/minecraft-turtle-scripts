dofile("tests/support/bootstrap.lua")

local install = dofile("/install.lua")

local files = install.buildFileList("mining/quarry")
assert(#files == 5)
assert(files[1].url:match("/mining/quarry%.lua$") ~= nil)
assert(files[1].dest == "/quarry")
assert(files[2].dest == "/lib/nav.lua")
assert(files[3].dest == "/lib/fuel.lua")
assert(files[4].dest == "/lib/inventory.lua")
assert(files[5].dest == "/lib/state.lua")

local treeFarmFiles = install.buildFileList("tree-farm/lumberjack")
assert(#treeFarmFiles == 4)
assert(treeFarmFiles[1].url:match("/tree%-farm/lumberjack%.lua$") ~= nil)
assert(treeFarmFiles[1].dest == "/lumberjack")

print("OK")
