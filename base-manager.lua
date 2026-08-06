local UPDATE_URL = "https://raw.githubusercontent.com/NovaDevvvv/computercraft-scripts/refs/heads/main/base-manager.lua"
local PROGRAM_PATH = shell.getRunningProgram()

local DOOR_NAME = "Hallway 1"
local DOOR_RANGE = 10
local BASE_RANGE = 100
local OUTPUT_SIDE = "down"
local UPDATE_RATE = 0.25

local function readFile(path)
    if not fs.exists(path) then
        return ""
    end

    local file = fs.open(path, "r")
    if not file then
        return ""
    end

    local contents = file.readAll()
    file.close()
    return contents or ""
end

local function writeFile(path, contents)
    local file = fs.open(path, "w")

    if not file then
        return false
    end

    file.write(contents)
    file.close()
    return true
end

local function checkForUpdates()
    if not http then
        print("HTTP is disabled")
        sleep(1)
        return
    end

    print("Checking for updates...")

    local cacheKey = tostring(os.epoch("utc")) .. "-" .. tostring(math.random(100000, 999999))
    local url = UPDATE_URL .. "?nocache=" .. cacheKey

    local response, errorMessage = http.get(url, {
        ["Cache-Control"] = "no-cache, no-store, must-revalidate",
        ["Pragma"] = "no-cache",
        ["Expires"] = "0",
        ["User-Agent"] = "CC-Base-Manager"
    })

    if not response then
        print("Update check failed")
        print(tostring(errorMessage or "Unknown error"))
        sleep(1)
        return
    end

    local responseCode = response.getResponseCode()
    local remoteCode = response.readAll()
    response.close()

    if responseCode ~= 200 then
        print("GitHub returned HTTP " .. tostring(responseCode))
        sleep(1)
        return
    end

    if not remoteCode or #remoteCode < 100 then
        print("Downloaded update was invalid")
        sleep(1)
        return
    end

    local localCode = readFile(PROGRAM_PATH)

    if remoteCode == localCode then
        print("Base Manager is up to date")
        sleep(1)
        return
    end

    local temporaryPath = PROGRAM_PATH .. ".new"

    if fs.exists(temporaryPath) then
        fs.delete(temporaryPath)
    end

    if not writeFile(temporaryPath, remoteCode) then
        print("Could not write update")
        sleep(1)
        return
    end

    local downloadedCode = readFile(temporaryPath)

    if downloadedCode ~= remoteCode then
        fs.delete(temporaryPath)
        print("Update verification failed")
        sleep(1)
        return
    end

    print("New version found")
    print("Installing update...")

    if fs.exists(PROGRAM_PATH .. ".old") then
        fs.delete(PROGRAM_PATH .. ".old")
    end

    if fs.exists(PROGRAM_PATH) then
        fs.move(PROGRAM_PATH, PROGRAM_PATH .. ".old")
    end

    fs.move(temporaryPath, PROGRAM_PATH)

    print("Update installed")
    print("Restarting...")
    sleep(1)
    os.reboot()
end

math.randomseed(os.epoch("utc"))
checkForUpdates()

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

local function centeredText(y, text, color)
    local width = monitor.getSize()
    local x = math.floor((width - #text) / 2) + 1

    monitor.setCursorPos(math.max(1, x), y)
    monitor.setTextColor(color or colors.white)
    monitor.write(text)
end

local function drawScreen(doorOpen, baseCount, hallwayCount)
    local width, height = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    centeredText(2, "BASE MANAGER", colors.cyan)

    monitor.setTextColor(colors.gray)
    monitor.setCursorPos(2, 4)
    monitor.write(string.rep("-", math.max(1, width - 2)))

    centeredText(6, DOOR_NAME, colors.white)

    if doorOpen then
        centeredText(8, "OPEN", colors.lime)
    else
        centeredText(8, "CLOSED", colors.red)
    end

    centeredText(11, "Hallway Players: " .. tostring(hallwayCount), colors.lightGray)
    centeredText(13, "Players On Base: " .. tostring(baseCount), colors.yellow)

    monitor.setTextColor(colors.gray)
    monitor.setCursorPos(2, height - 1)
    monitor.write("Range: " .. tostring(BASE_RANGE) .. " blocks")
end

local previousDoorState = nil
local previousBaseCount = nil
local previousHallwayCount = nil

while true do
    local hallwayPlayers = detector.getPlayersInRange(DOOR_RANGE) or {}
    local basePlayers = detector.getPlayersInRange(BASE_RANGE) or {}

    local hallwayCount = #hallwayPlayers
    local baseCount = #basePlayers
    local doorOpen = hallwayCount > 0

    integrator.setOutput(OUTPUT_SIDE, doorOpen)

    if doorOpen ~= previousDoorState
        or baseCount ~= previousBaseCount
        or hallwayCount ~= previousHallwayCount then

        drawScreen(doorOpen, baseCount, hallwayCount)

        previousDoorState = doorOpen
        previousBaseCount = baseCount
        previousHallwayCount = hallwayCount
    end

    sleep(UPDATE_RATE)
end
