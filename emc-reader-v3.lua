local readerSide = "left"
local monitorSide = "top"

local emcPerItem = 466944
local updateRate = 1

local reader = peripheral.wrap(readerSide)
local monitor = peripheral.wrap(monitorSide)

if not reader then
    error("No block reader found on " .. readerSide)
end

if not monitor then
    error("No monitor found on " .. monitorSide)
end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local previousAmount = nil
local previousTime = os.epoch("utc") / 1000
local itemsPerSecond = 0

local function formatNumber(value)
    value = math.floor(value or 0)

    if value >= 1e15 then
        return string.format("%.2fQ", value / 1e15)
    elseif value >= 1e12 then
        return string.format("%.2fT", value / 1e12)
    elseif value >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif value >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif value >= 1e3 then
        return string.format("%.2fK", value / 1e3)
    end

    return tostring(value)
end

local function getItemName(id)
    if not id or id == "minecraft:air" then
        return "Empty"
    end

    local name = id:match(":(.+)") or id
    name = name:gsub("_", " ")

    return name:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest
    end)
end

local function centerText(y, text, color)
    local width = monitor.getSize()
    local x = math.max(1, math.floor((width - #text) / 2) + 1)

    monitor.setCursorPos(x, y)
    monitor.setTextColor(color)
    monitor.write(text)
end

while true do
    local data = reader.getBlockData()

    local slot =
        data
        and data.handler
        and data.handler.BigItems
        and data.handler.BigItems["0"]

    local itemId = "minecraft:air"
    local amount = 0

    if slot then
        amount = slot.Amount or 0

        if slot.Stack then
            itemId = slot.Stack.id or "minecraft:air"
        end
    end

    local currentTime = os.epoch("utc") / 1000
    local elapsed = currentTime - previousTime

    if previousAmount ~= nil and elapsed > 0 then
        local gained = amount - previousAmount

        if gained >= 0 then
            local currentRate = gained / elapsed
            itemsPerSecond = itemsPerSecond * 0.7 + currentRate * 0.3
        else
            itemsPerSecond = 0
        end
    end

    previousAmount = amount
    previousTime = currentTime

    local totalEmc = amount * emcPerItem
    local itemsPerMinute = itemsPerSecond * 60
    local itemsPerHour = itemsPerSecond * 3600
    local emcPerMinute = itemsPerMinute * emcPerItem
    local emcPerHour = itemsPerHour * emcPerItem

    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    centerText(1, "EMC STORAGE", colors.yellow)
    centerText(3, getItemName(itemId), colors.white)

    monitor.setCursorPos(2, 5)
    monitor.setTextColor(colors.lightGray)
    monitor.write("Amount")

    monitor.setCursorPos(2, 6)
    monitor.setTextColor(colors.lime)
    monitor.write(formatNumber(amount))

    monitor.setCursorPos(2, 8)
    monitor.setTextColor(colors.lightGray)
    monitor.write("Total EMC")

    monitor.setCursorPos(2, 9)
    monitor.setTextColor(colors.cyan)
    monitor.write(formatNumber(totalEmc))

    monitor.setCursorPos(2, 11)
    monitor.setTextColor(colors.lightGray)
    monitor.write("Estimated / Minute")

    monitor.setCursorPos(2, 12)
    monitor.setTextColor(colors.orange)
    monitor.write(formatNumber(itemsPerMinute) .. " items")

    monitor.setCursorPos(2, 13)
    monitor.setTextColor(colors.purple)
    monitor.write(formatNumber(emcPerMinute) .. " EMC")

    monitor.setCursorPos(2, 15)
    monitor.setTextColor(colors.lightGray)
    monitor.write("Estimated / Hour")

    monitor.setCursorPos(2, 16)
    monitor.setTextColor(colors.orange)
    monitor.write(formatNumber(itemsPerHour) .. " items")

    monitor.setCursorPos(2, 17)
    monitor.setTextColor(colors.purple)
    monitor.write(formatNumber(emcPerHour) .. " EMC")

    sleep(updateRate)
end
