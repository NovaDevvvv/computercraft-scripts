local reader = peripheral.wrap("left")
local monitor = peripheral.wrap("top")

if not reader then
    error("No Block Reader found on the left")
end

if not monitor then
    error("No monitor found on top")
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

local function center(y, text)
    local width = monitor.getSize()
    local x = math.floor((width - #text) / 2) + 1

    monitor.setCursorPos(math.max(1, x), y)
    monitor.write(text)
end

local function findNumber(value)
    if type(value) == "number" then
        return value
    end

    if type(value) ~= "table" then
        return tonumber(value)
    end

    local preferredFields = {
        "energy",
        "stored",
        "amount",
        "value",
        "eu",
        "power",
        "output"
    }

    for _, field in ipairs(preferredFields) do
        local result = value[field]

        if type(result) == "number" then
            return result
        end
    end

    for _, result in pairs(value) do
        local number = findNumber(result)

        if number then
            return number
        end
    end

    return nil
end

local function drawSun(width)
    if width >= 15 then
        center(2, "\\  |  /")
        center(3, "  \\ | /")
        center(4, "--- O ---")
        center(5, "  / | \\")
        center(6, "/  |  \\")
    else
        center(2, "\\ | /")
        center(3, "- O -")
        center(4, "/ | \\")
    end
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.clear()

while true do
    local ok, data = pcall(reader.getBlockData)
    local energy = nil

    if ok and type(data) == "table" then
        energy = findNumber(data.energy)
    end

    local width, height = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    monitor.setBackgroundColor(colors.orange)
    monitor.setTextColor(colors.black)
    monitor.setCursorPos(1, 1)
    monitor.write(string.rep(" ", width))
    center(1, " SOLAR POWER ")

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.yellow)

    drawSun(width)

    local valueY = height >= 10 and 8 or 6
    local labelY = valueY + 1
    local statusY = height

    if energy then
        monitor.setTextColor(colors.lime)
        center(valueY, formatNumber(energy) .. " EU")

        monitor.setTextColor(colors.lightGray)
        center(labelY, "Current stored power")

        monitor.setTextColor(colors.green)
        center(statusY, "[ ONLINE ]")
    else
        monitor.setTextColor(colors.red)
        center(valueY, "NO DATA")

        monitor.setTextColor(colors.lightGray)
        center(labelY, "Check Block Reader")

        monitor.setTextColor(colors.red)
        center(statusY, "[ OFFLINE ]")
    end

    sleep(0.5)
end
