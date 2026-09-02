dofile("tests/support/bootstrap.lua")

local install = dofile("/install.lua")

local files = install.buildFileList("quarry")
assert(#files == 5)
assert(files[1].url:match("/mining/quarry%.lua$") ~= nil)
assert(files[1].dest == "/quarry")
assert(files[2].dest == "/lib/nav.lua")
assert(files[3].dest == "/lib/fuel.lua")
assert(files[4].dest == "/lib/inventory.lua")
assert(files[5].dest == "/lib/state.lua")

print("OK")
