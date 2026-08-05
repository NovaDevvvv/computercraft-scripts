if fs.exists("mfe-reader.lua") then
    fs.delete("mfe-reader.lua")
end

shell.run(
    "wget",
    "https://raw.githubusercontent.com/NovaDevvvv/computercraft-scripts/refs/heads/main/mfe-reader.lua",
    "mfe-reader.lua"
)

shell.run("mfe-reader.lua")
