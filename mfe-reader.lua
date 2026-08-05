local monitor = peripheral.find("monitor")
local mfe = peripheral.find("ic2:mfe")

if not monitor then
    error("No monitor found")
end

if not mfe then
    error("No IC2 MFE found")
end

local function callFirst(object, methods)
    for _, method in ipairs(methods) do
        if type(object[method]) == "function" then
            local ok, result = pcall(object[method])

            if ok and type(result) == "number" then
                return result
            end
        end
    end

    return nil
end

local function getStoredEnergy()
    return callFirst(mfe, {
        "getEnergy",
        "getEnergyStored",
        "getStored",
        "getEUStored",
        "getEnergyLevel"
    })
end

local function getMaximumEnergy()
    return callFirst(mfe, {
        "getCapacity",
        "getMaxEnergyStored",
        "getMaxEnergy",
        "getEUCapacity",
        "getMaximumEnergy"
    })
end

local function formatNumber(number)
    local formatted = tostring(math.floor(number))

    while true do
        local replaced
        formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")

        if replaced == 0 then
            break
        end
    end

    return formatted
end

local function centerText(y, text)
    local width = monitor.getSize()
    local x = math.floor((width - #text) / 2) + 1

    monitor.setCursorPos(math.max(1, x), y)
    monitor.write(text)
end

monitor.setTextScale(1)

while true do
    local stored = getStoredEnergy()
    local capacity = getMaximumEnergy()

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    centerText(1, "IC2 MFE")

    if stored and capacity and capacity > 0 then
        local percentage = math.max(0, math.min(100, stored / capacity * 100))

        centerText(3, formatNumber(stored) .. " EU")
        centerText(4, "of " .. formatNumber(capacity) .. " EU")
        centerText(6, string.format("%.1f%%", percentage))

        local width = monitor.getSize()
        local barWidth = math.max(1, width - 2)
        local filledWidth = math.floor(barWidth * percentage / 100)

        monitor.setCursorPos(2, 8)

        for x = 1, barWidth do
            if x <= filledWidth then
                monitor.setBackgroundColor(colors.green)
            else
                monitor.setBackgroundColor(colors.gray)
            end

            monitor.write(" ")
        end

        monitor.setBackgroundColor(colors.black)
    else
        monitor.setTextColor(colors.red)
        centerText(3, "Could not read energy")
        monitor.setTextColor(colors.white)

        centerText(5, "Available methods:")

        local y = 6

        for _, method in ipairs(peripheral.getMethods("left")) do
            if y <= select(2, monitor.getSize()) then
                monitor.setCursorPos(1, y)
                monitor.write(method)
                y = y + 1
            end
        end
    end

    sleep(0.5)
end
