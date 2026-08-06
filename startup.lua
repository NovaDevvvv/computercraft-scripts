term.clear()
term.setCursorPos(1, 1)

print("Starting Base Manager...")

if not fs.exists("/base-manager.lua") then
    print("ERROR: /base-manager.lua not found")
    print("Run:")
    print('wget "https://raw.githubusercontent.com/NovaDevvvv/computercraft-scripts/refs/heads/main/base-manager.lua?nocache=' .. os.epoch("utc") .. '" /base-manager.lua')
    return
end

local ok, err = pcall(function()
    shell.run("/base-manager.lua")
end)

if not ok then
    print("")
    print("BASE MANAGER CRASHED:")
    print(tostring(err))
end

print("")
print("Press any key to continue")
os.pullEvent("key")
