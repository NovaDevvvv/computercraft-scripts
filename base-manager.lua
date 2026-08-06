local UPDATE_URL = "https://raw.githubusercontent.com/NovaDevvvv/computercraft-scripts/refs/heads/main/base-manager.lua"
local PROGRAM_PATH = shell.getRunningProgram()

local zones = {
    {
        name = "Hallway 1",
        range = 10,
        outputSide = "down"
    }
}

local function update()
    if not http then
        return
    end

    local response = http.get(UPDATE_URL .. "?cache=" .. os.epoch("utc"))

    if not response then
        return
    end

    local code = response.getResponseCode()
    local remoteCode = response.readAll()
    response.close()

    if code ~= 200 or not remoteCode or remoteCode == "" then
        return
    end

    local file = fs.open(PROGRAM_PATH, "r")
    local localCode = file and file.readAll() or ""
    if file then file.close() end

    if remoteCode ~= localCode then
        term.clear()
        term.setCursorPos(1, 1)
        print("Updating Base Manager...")

        local output = fs.open(PROGRAM_PATH, "w")
        output.write(remoteCode)
        output.close()

        print("Update installed. Restarting...")
        sleep(1)
        os.reboot()
    end
end

update()

local detector = peripheral.find("playerDetector")
local integrator = peripheral.find("redstoneIntegrator")
local monitor = peripheral.find("monitor")

if not detector then
    error("No Player Detector found")
end

if not integrator then
    error("No Redstone Integrator found")
end

if not monitor then
    error("No monitor found")
end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

local function center(y, text, color)
    local width = monitor.getSize()
    monitor.setTextColor(color or colors.white)
    monitor.setCursorPos(math.max(1, math.floor((width - #text) / 2) + 1), y)
    monitor.write(text)
end

local function drawZone(zone, isOpen)
    local width, height = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    center(2, "BASE MANAGER", colors.cyan)

    monitor.setTextColor(colors.gray)
    monitor.setCursorPos(2, 4)
    monitor.write(string.rep("-", math.max(1, width - 2)))

    center(math.floor(height / 2) - 1, zone.name, colors.white)

    if isOpen then
        center(math.floor(height / 2) + 1, "OPEN", colors.lime)
    else
        center(math.floor(height / 2) + 1, "CLOSED", colors.red)
    end

    center(math.floor(height / 2) + 3, "Players on base: "..baseCount, colors.yellow)

    center(height - 1, "Range: " .. zone.range .. " blocks", colors.lightGray)
end

local previousState = nil
local zone = zones[1]

while true do
    local players = detector.getPlayersInRange(zone.range)
    local isOpen = #players > 0

    integrator.setOutput(zone.outputSide, isOpen)

    if isOpen ~= previousState then
        drawZone(zone, isOpen)
        previousState = isOpen
    end

    sleep(0.25)
end
