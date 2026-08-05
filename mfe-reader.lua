local monitor = peripheral.find("monitor")
local mfe = peripheral.find("ic2:mfe")

if not mfe and peripheral.isPresent("left") then
    local types = { peripheral.getType("left") }

    for _, peripheralType in ipairs(types) do
        if peripheralType == "ic2:mfe" then
            mfe = peripheral.wrap("left")
            break
        end
    end
end

if not monitor then
    error("No monitor found")
end

if not mfe then
    error("No IC2 MFE found")
end

local function callMethod(methodNames)
    for _, methodName in ipairs(methodNames) do
        local method = mfe[methodName]

        if type(method) == "function" then
            local ok, value = pcall(method)

            if ok and type(value) == "number" then
                return value
            end
        end
    end

    return nil
end

local function getEnergy()
    return callMethod({
        "getEnergy",
        "getEnergyStored",
        "getStored",
        "getEUStored",
        "getEnergyLevel"
    })
end

local function getCapacity()
    return callMethod({
        "getCapacity",
        "getMaxEnergyStored",
        "getMaxEnergy",
        "getEUCapacity",
        "getMaximumEnergy"
    })
end

local function formatNumber(value)
    local text = tostring(math.floor(value))

    while true do
        local replacements
        text, replacements = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")

        if replacements == 0 then
            return text
        end
    end
end

local function center(y, text)
    local width = monitor.getSize()
    local x = math.floor((width - #text) / 2) + 1

    monitor.setCursorPos(math.max(1, x), y)
    monitor.write(text)
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)

while true do
    local energy = getEnergy()
    local capacity = getCapacity()

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    center(1, "IC2 MFE")

    if energy and capacity and capacity > 0 then
        local percentage = math.max(0, math.min(100, energy / capacity * 100))
        local width, height = monitor.getSize()

        center(3, formatNumber(energy) .. " EU")
        center(4, "of " .. formatNumber(capacity) .. " EU")
        center(6, string.format("%.1f%%", percentage))

        if height >= 8 and width >= 3 then
            local barWidth = width - 2
            local filled = math.floor(barWidth * percentage / 100)

            monitor.setCursorPos(2, 8)

            for position = 1, barWidth do
                if position <= filled then
                    monitor.setBackgroundColor(colors.green)
                else
                    monitor.setBackgroundColor(colors.gray)
                end

                monitor.write(" ")
            end

            monitor.setBackgroundColor(colors.black)
        end
    else
        monitor.setTextColor(colors.red)
        center(3, "Cannot read MFE energy")

        monitor.setTextColor(colors.white)
        center(5, "Run: methods left")
    end

    sleep(0.5)
end
