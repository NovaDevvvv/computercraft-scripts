local url = "https://raw.githubusercontent.com/NovaDevvvv/computercraft-scripts/refs/heads/main/mfe-reader.lua"
local file = "mfe-reader.lua"

if fs.exists(file) then
    fs.delete(file)
end

print("Downloading " .. file .. "...")

local success = shell.run("wget", url, file)

if not success or not fs.exists(file) then
    error("Failed to download " .. file)
end

print("Starting " .. file .. "...")
shell.run(file)
