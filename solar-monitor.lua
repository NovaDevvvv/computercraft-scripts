local reader = peripheral.wrap("left")
local monitor = peripheral.wrap("top")

if not reader then
    error("No Block Reader on left")
end

if not monitor then
    error("No monitor on top")
end

monitor.setTextScale(1)

local function center(y, text)
    local width = monitor.getSize()
    monitor.setCursorPos(math.max(1, math.floor((width - #text) / 2) + 1), y)
    monitor.write(text)
end

while true do
    local ok, data = pcall(reader.getBlockData)
    local energy = ok and data and data.energy or nil

    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setBackgroundColor(colors.orange)
    monitor.setTextColor(colors.black)

    local width, height = monitor.getSize()

    monitor.setCursorPos(1, 1)
    monitor.write(string.rep(" ", width))
    center(1, "SOLAR POWER")

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.yellow)
    center(3, "\\  |  /")
    center(4, "-- O --")
    center(5, "/  |  \\")

    if type(energy) == "number" then
        monitor.setTextColor(colors.lime)
        center(7, tostring(math.floor(energy)) .. " EU")

        monitor.setTextColor(colors.green)
        center(height, "[ ONLINE ]")
    else
        monitor.setTextColor(colors.red)
        center(7, "NO ENERGY DATA")
        center(height, "[ OFFLINE ]")
    end

    sleep(0.5)
end
