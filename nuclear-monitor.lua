local reader = peripheral.wrap("left")
local monitor = peripheral.wrap("top")

if not reader then
    error("No Block Reader on the left")
end

if not monitor then
    error("No monitor on top")
end

monitor.setTextScale(1)

local function center(y, text)
    local width = monitor.getSize()
    local x = math.floor((width - #text) / 2) + 1

    monitor.setCursorPos(math.max(1, x), y)
    monitor.write(text)
end

local function formatNumber(value)
    value = tonumber(value) or 0

    if value >= 1000000000 then
        return string.format("%.2fB", value / 1000000000)
    elseif value >= 1000000 then
        return string.format("%.2fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end

    return tostring(math.floor(value))
end

while true do
    local ok, data = pcall(reader.getBlockData)
    local energy = ok and data and tonumber(data.energy) or nil

    local width, height = monitor.getSize()

    monitor.setBackgroundColor(colors.white)
    monitor.setTextColor(colors.black)
    monitor.clear()

    monitor.setBackgroundColor(colors.yellow)
    monitor.setTextColor(colors.black)
    monitor.setCursorPos(1, 1)
    monitor.write(string.rep(" ", width))
    center(1, " NUCLEAR POWER ")

    monitor.setBackgroundColor(colors.white)
    monitor.setTextColor(colors.orange)

    if height >= 9 then
        center(3, "\\  |  /")
        center(4, " \\ | / ")
        center(5, "--- O ---")
        center(6, " / | \\ ")
        center(7, "/  |  \\")
    else
        center(3, "\\ | /")
        center(4, "- O -")
        center(5, "/ | \\")
    end

    local energyY = height >= 11 and 9 or 7
    local labelY = math.min(height - 1, energyY + 1)

    if energy then
        monitor.setTextColor(colors.green)
        center(energyY, formatNumber(energy) .. " EU")

        monitor.setTextColor(colors.gray)
        center(labelY, "Nuclear energy")

        monitor.setBackgroundColor(colors.lime)
        monitor.setTextColor(colors.black)
        monitor.setCursorPos(1, height)
        monitor.write(string.rep(" ", width))
        center(height, " ONLINE ")
    else
        monitor.setTextColor(colors.red)
        center(energyY, "NO DATA")

        monitor.setTextColor(colors.gray)
        center(labelY, "Check reader")

        monitor.setBackgroundColor(colors.red)
        monitor.setTextColor(colors.white)
        monitor.setCursorPos(1, height)
        monitor.write(string.rep(" ", width))
        center(height, " OFFLINE ")
    end

    sleep(0.5)
end
