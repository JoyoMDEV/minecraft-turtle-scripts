local REPO_RAW_BASE = "https://raw.githubusercontent.com/JoyoMDEV/minecraft-turtle-scripts/main"

-- Each entry lists the lib/ modules a given role's scripts need, since not
-- every role uses all of them (e.g. lumberjack has no resume state to load).
local ROLE_LIB_FILES = {
  mining = {"nav.lua", "fuel.lua", "inventory.lua", "state.lua"},
  ["tree-farm"] = {"nav.lua", "fuel.lua", "inventory.lua"},
}

local function buildFileList(scriptPath)
  local role, scriptName = scriptPath:match("^([^/]+)/([^/]+)$")
  local files = {
    {url = REPO_RAW_BASE .. "/" .. scriptPath .. ".lua", dest = "/" .. scriptName},
  }
  for _, libFile in ipairs(ROLE_LIB_FILES[role] or {}) do
    files[#files + 1] = {url = REPO_RAW_BASE .. "/lib/" .. libFile, dest = "/lib/" .. libFile}
  end
  return files
end

local function install(scriptPath)
  if not scriptPath or not scriptPath:match("^[^/]+/[^/]+$") then
    print("usage: install <folder/script name, e.g. mining/quarry>")
    return
  end

  if not fs.exists("/lib") then
    fs.makeDir("/lib")
  end

  for _, file in ipairs(buildFileList(scriptPath)) do
    print("Downloading " .. file.url .. " ...")
    local ok = shell.run("wget", file.url, file.dest)
    if not ok then
      print("Failed to download " .. file.url)
      return
    end
  end

  local scriptName = scriptPath:match("([^/]+)$")
  print("Installed '" .. scriptName .. "'. Run it with: " .. scriptName)
end

install(({...})[1])

return {buildFileList = buildFileList}
