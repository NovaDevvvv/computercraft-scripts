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

local TTS_URL = "https://music.madefor.cc/tts?text="
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
    local response, problem = http.get(url, {
        ["Cache-Control"] = "no-cache, no-store, must-revalidate",
        ["Pragma"] = "no-cache",
        ["User-Agent"] = "ComputerCraft-Base-Manager"
    })

    if not response then
        return nil, tostring(problem or "Request failed")
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
        printError("HTTP is disabled")
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

    local commitBody, commitProblem = request(commitURL)

    if not commitBody then
        printError("Update check failed")
        printError(commitProblem)
        sleep(2)
        return
    end

    local commitData = textutils.unserialiseJSON(commitBody)

    if not commitData or type(commitData.sha) ~= "string" then
        printError("Invalid GitHub response")
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

    local remoteCode, downloadProblem = request(downloadURL)

    if not remoteCode then
        printError("Download failed")
        printError(downloadProblem)
        sleep(2)
        return
    end

    if #remoteCode < 100 then
        printError("Downloaded file is invalid")
        sleep(2)
        return
    end

    local temporaryPath = PROGRAM_PATH .. ".new"

    if fs.exists(temporaryPath) then
        fs.delete(temporaryPath)
    end

    if not writeFile(temporaryPath, remoteCode) then
        printError("Could not save update")
        sleep(2)
        return
    end

    if readFile(temporaryPath) ~= remoteCode then
        fs.delete(temporaryPath)
        printError("Update verification failed")
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
    local seconds = math.floor(
        (os.epoch("utc") - START_TIME) / 1000
    )

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60

    if days > 0 then
        return string.format(
            "%dd %02dh %02dm %02ds",
            days,
            hours,
            minutes,
            remainingSeconds
        )
    elseif hours > 0 then
        return string.format(
            "%02dh %02dm %02ds",
            hours,
            minutes,
            remainingSeconds
        )
    end

    return string.format(
        "%02dm %02ds",
        minutes,
        remainingSeconds
    )
end

local function getSpeakerCount()
    local count = 0

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "speaker") then
            count = count + 1
        end
    end

    return count
end

local function speak(text, description)
    print("Speaking " .. description)

    local url = TTS_URL .. textutils.urlEncode(text)

    if not shell.run("speaker", "play", url) then
        printError("Could not play " .. description)
        return false
    end

    return true
end

checkForUpdates()

local detector = peripheral.find("playerDetector")
local integrator = peripheral.find("redstoneIntegrator")
local monitor = peripheral.find("monitor")

if not detector then
    error("No Player Detector found", 0)
end

if not integrator then
    error("No Redstone Integrator found", 0)
end

if not monitor then
    error("No monitor found", 0)
end

monitor.setTextScale(0.5)
monitor.setCursorBlink(false)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local function writeAt(x, y, text, foreground, background)
    monitor.setCursorPos(x, y)
    monitor.setTextColor(foreground or colors.white)
    monitor.setBackgroundColor(background or colors.black)
    monitor.write(text)
end

local function clearLine(y)
    local width = monitor.getSize()

    monitor.setCursorPos(1, y)
    monitor.setBackgroundColor(colors.black)
    monitor.write(string.rep(" ", width))
end

local function drawScreen(doorOpen, baseCount, speakerCount)
    local width, height = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    writeAt(2, 2, "BASE MANAGER", colors.cyan)

    writeAt(
        2,
        4,
        string.rep("-", math.max(1, width - 3)),
        colors.gray
    )

    writeAt(2, 6, DOOR_NAME .. ": ", colors.white)

    if doorOpen then
        writeAt(2 + #DOOR_NAME + 2, 6, "OPEN", colors.lime)
    else
        writeAt(2 + #DOOR_NAME + 2, 6, "CLOSED", colors.red)
    end

    writeAt(
        2,
        8,
        "Players On Base: " .. tostring(baseCount),
        colors.yellow
    )

    writeAt(
        2,
        10,
        "Speakers: " .. tostring(speakerCount),
        colors.lightBlue
    )

    clearLine(height)

    local uptimeText = "Uptime: " .. formatUptime()

    writeAt(
        2,
        height,
        uptimeText:sub(1, math.max(0, width - 1)),
        colors.gray
    )
end

local previousDoorState = nil
local previousBaseCount = nil
local previousSpeakerCount = nil
local previousUptime = nil

local function managerLoop()
    while true do
        local hallwayPlayers =
            detector.getPlayersInRange(DOOR_RANGE) or {}

        local basePlayers =
            detector.getPlayersInRange(BASE_RANGE) or {}

        local doorOpen = #hallwayPlayers > 0
        local baseCount = #basePlayers
        local speakerCount = getSpeakerCount()
        local uptime = formatUptime()

        integrator.setOutput(OUTPUT_SIDE, doorOpen)

        if doorOpen ~= previousDoorState
            or baseCount ~= previousBaseCount
            or speakerCount ~= previousSpeakerCount
            or uptime ~= previousUptime then

            drawScreen(
                doorOpen,
                baseCount,
                speakerCount
            )

            previousDoorState = doorOpen
            previousBaseCount = baseCount
            previousSpeakerCount = speakerCount
            previousUptime = uptime
        end

        sleep(UPDATE_RATE)
    end
end

local function startupVoice()
    sleep(2)

    if getSpeakerCount() == 0 then
        printError("No speakers connected")
        return
    end

    speak(
        "All systems online",
        "startup announcement"
    )
end

local ok, problem = pcall(function()
    parallel.waitForAll(
        managerLoop,
        startupVoice
    )
end)

integrator.setOutput(OUTPUT_SIDE, false)

if not ok and tostring(problem) ~= "Terminated" then
    printError(problem)
end
