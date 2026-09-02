local REPO_RAW_BASE = "https://raw.githubusercontent.com/YOUR_GITHUB_USER/minecraft-turtle-scripts/main"

local LIB_FILES = {"nav.lua", "fuel.lua", "inventory.lua", "state.lua"}

local function buildFileList(scriptName)
  local files = {
    {url = REPO_RAW_BASE .. "/mining/" .. scriptName .. ".lua", dest = "/" .. scriptName},
  }
  for _, libFile in ipairs(LIB_FILES) do
    files[#files + 1] = {url = REPO_RAW_BASE .. "/lib/" .. libFile, dest = "/lib/" .. libFile}
  end
  return files
end

local function install(scriptName)
  if not scriptName then
    print("usage: install <script name, e.g. quarry>")
    return
  end

  if not fs.exists("/lib") then
    fs.makeDir("/lib")
  end

  for _, file in ipairs(buildFileList(scriptName)) do
    print("Downloading " .. file.url .. " ...")
    local ok = shell.run("wget", file.url, file.dest)
    if not ok then
      print("Failed to download " .. file.url)
      return
    end
  end

  print("Installed '" .. scriptName .. "'. Run it with: " .. scriptName .. " <width> <length> <depth> <true|false>")
end

install(({...})[1])

return {buildFileList = buildFileList}
