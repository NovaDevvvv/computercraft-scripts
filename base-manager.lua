local REPOSITORY = "NovaDevvvv/computercraft-scripts"
local BRANCH = "main"
local REMOTE_FILE = "base-manager.lua"

local PROGRAM_PATH = "/base-manager.lua"
local VERSION_PATH = "/base-manager.version"

local DOOR_NAME = "Hallway 1"
local DOOR_RANGE = 10
local BASE_RANGE = 100
local OUTPUT_SIDE = "down"
local UPDATE_RATE = 0.25

local START_TIME = os.epoch("utc")

local function readFile(path)
    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")
    if not file then
        return nil
    end

    local contents = file.readAll()
    file.close()

    return contents
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

local function request(url)
    local response, errorMessage = http.get(url, {
        ["Cache-Control"] = "no-cache, no-store, must-revalidate",
        ["Pragma"] = "no-cache",
        ["User-Agent"] = "ComputerCraft-Base-Manager"
    })

    if not response then
        return nil, tostring(errorMessage or "Request failed")
    end

    local status = response.getResponseCode()
    local body = response.readAll()
    response.close()

    if status ~= 200 then
        return nil, "HTTP " .. tostring(status)
    end

    return body
end

local function checkForUpdates()
    term.clear()
    term.setCursorPos(1, 1)

    if not http then
        print("HTTP is disabled")
        sleep(2)
        return
    end

    print("BASE MANAGER")
    print("")
    print("Checking for updates...")

    local commitURL =
        "https://api.github.com/repos/"
        .. REPOSITORY
        .. "/commits/"
        .. BRANCH
        .. "?nocache="
        .. tostring(os.epoch("utc"))

    local commitBody, commitError = request(commitURL)

    if not commitBody then
        print("Update check failed:")
        print(commitError)
        sleep(2)
        return
    end

    local commitData = textutils.unserializeJSON(commitBody)

    if not commitData or not commitData.sha then
        print("Invalid GitHub response")
        sleep(2)
        return
    end

    local latestVersion = commitData.sha
    local installedVersion = readFile(VERSION_PATH)

    if installedVersion == latestVersion then
        print("Version: " .. latestVersion:sub(1, 7))
        print("Up to date")
        sleep(1)
        return
    end

    print("New version: " .. latestVersion:sub(1, 7))
    print("Downloading...")

    local downloadURL =
        "https://raw.githubusercontent.com/"
        .. REPOSITORY
        .. "/"
        .. latestVersion
        .. "/"
        .. REMOTE_FILE

    local remoteCode, downloadError = request(downloadURL)

    if not remoteCode then
        print("Download failed:")
        print(downloadError)
        sleep(2)
        return
    end

    if #remoteCode < 100 then
        print("Downloaded file is invalid")
        sleep(2)
        return
    end

    local temporaryPath = PROGRAM_PATH .. ".new"

    if fs.exists(temporaryPath) then
        fs.delete(temporaryPath)
    end

    if not writeFile(temporaryPath, remoteCode) then
        print("Could not save update")
        sleep(2)
        return
    end

    if readFile(temporaryPath) ~= remoteCode then
        fs.delete(temporaryPath)
        print("Update verification failed")
        sleep(2)
        return
    end

    if fs.exists(PROGRAM_PATH) then
        fs.delete(PROGRAM_PATH)
    end

    fs.move(temporaryPath, PROGRAM_PATH)
    writeFile(VERSION_PATH, latestVersion)

    print("Update installed")
    print("Restarting...")
    sleep(1)
    os.reboot()
end

local function formatUptime()
    local seconds = math.floor((os.epoch("utc") - START_TIME) / 1000)

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60

    if days > 0 then
        return string.format("%dd %02dh %02dm %02ds", days, hours, minutes, remainingSeconds)
    elseif hours > 0 then
        return string.format("%02dh %02dm %02ds", hours, minutes, remainingSeconds)
    else
        return string.format("%02dm %02ds", minutes, remainingSeconds)
    end
end

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
monitor.setTextColor(colors.white)
monitor.clear()

local function drawScreen(doorOpen, baseCount)
    local width, height = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.cyan)
    monitor.write("BASE MANAGER")

    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.gray)
    monitor.write(string.rep("-", math.max(1, width - 3)))

    monitor.setCursorPos(2, 6)
    monitor.setTextColor(colors.white)
    monitor.write(DOOR_NAME .. ": ")

    if doorOpen then
        monitor.setTextColor(colors.lime)
        monitor.write("OPEN")
    else
        monitor.setTextColor(colors.red)
        monitor.write("CLOSED")
    end

    monitor.setCursorPos(2, 8)
    monitor.setTextColor(colors.yellow)
    monitor.write("Players On Base: " .. tostring(baseCount))

    local uptimeText = "Uptime: " .. formatUptime()

    monitor.setCursorPos(2, height)
    monitor.setTextColor(colors.gray)
    monitor.write(uptimeText:sub(1, math.max(0, width - 1)))
end

local previousDoorState = nil
local previousBaseCount = nil
local previousUptime = nil

while true do
    local hallwayPlayers = detector.getPlayersInRange(DOOR_RANGE) or {}
    local basePlayers = detector.getPlayersInRange(BASE_RANGE) or {}

    local doorOpen = #hallwayPlayers > 0
    local baseCount = #basePlayers
    local uptime = formatUptime()

    integrator.setOutput(OUTPUT_SIDE, doorOpen)

    if doorOpen ~= previousDoorState
        or baseCount ~= previousBaseCount
        or uptime ~= previousUptime then

        drawScreen(doorOpen, baseCount)

        previousDoorState = doorOpen
        previousBaseCount = baseCount
        previousUptime = uptime
    end

    sleep(UPDATE_RATE)
end
