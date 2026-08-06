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
    else
        return string.format(
            "%02dm %02ds",
            minutes,
            remainingSeconds
        )
    end
end

local function getSpeakers()
    local speakers = {}

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "speaker") then
            local speaker = peripheral.wrap(name)

            if speaker then
                table.insert(speakers, {
                    name = name,
                    device = speaker
                })
            end
        end
    end

    return speakers
end

local function playTTS(text, speakers)
    if #speakers == 0 then
        return false, "No speakers connected"
    end

    local url =
        "https://music.madefor.cc/tts?text="
        .. textutils.urlEncode(text)
        .. "&nocache="
        .. tostring(os.epoch("utc"))

    local response, errorMessage = http.get(url, {
        ["Cache-Control"] = "no-cache",
        ["User-Agent"] = "ComputerCraft-Base-Manager"
    })

    if not response then
        return false, tostring(errorMessage or "TTS request failed")
    end

    if response.getResponseCode() ~= 200 then
        local status = response.getResponseCode()
        response.close()
        return false, "TTS returned HTTP " .. tostring(status)
    end

    local decoder = require("cc.audio.dfpwm").make_decoder()

    while true do
        local chunk = response.read(16 * 1024)

        if not chunk then
            break
        end

        local audio = decoder(chunk)
        local waiting = {}

        for index, speakerData in ipairs(speakers) do
            waiting[index] = true
        end

        while true do
            local remaining = false

            for index, speakerData in ipairs(speakers) do
                if waiting[index] then
                    if speakerData.device.playAudio(audio, 1.5) then
                        waiting[index] = false
                    else
                        remaining = true
                    end
                end
            end

            if not remaining then
                break
            end

            os.pullEvent("speaker_audio_empty")
        end
    end

    response.close()
    return true
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

local speakers = getSpeakers()

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local function clearLine(y)
    local width = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.setCursorPos(1, y)
    monitor.write(string.rep(" ", width))
end

local function drawScreen(doorOpen, baseCount, speakerCount)
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

    monitor.setCursorPos(2, 10)
    monitor.setTextColor(colors.lightBlue)
    monitor.write("Speakers: " .. tostring(speakerCount))

    clearLine(height)

    local uptimeText = "Uptime: " .. formatUptime()

    monitor.setCursorPos(2, height)
    monitor.setTextColor(colors.gray)
    monitor.write(uptimeText:sub(1, math.max(0, width - 1)))
end

local previousDoorState = nil
local previousBaseCount = nil
local previousSpeakerCount = nil
local previousUptime = nil

local function managerLoop()
    while true do
        local hallwayPlayers = detector.getPlayersInRange(DOOR_RANGE) or {}
        local basePlayers = detector.getPlayersInRange(BASE_RANGE) or {}

        speakers = getSpeakers()

        local doorOpen = #hallwayPlayers > 0
        local baseCount = #basePlayers
        local speakerCount = #speakers
        local uptime = formatUptime()

        integrator.setOutput(OUTPUT_SIDE, doorOpen)

        if doorOpen ~= previousDoorState
            or baseCount ~= previousBaseCount
            or speakerCount ~= previousSpeakerCount
            or uptime ~= previousUptime then

            drawScreen(doorOpen, baseCount, speakerCount)

            previousDoorState = doorOpen
            previousBaseCount = baseCount
            previousSpeakerCount = speakerCount
            previousUptime = uptime
        end

        sleep(0.25)
    end
end

local function startupVoice()
    sleep(1)

    speakers = getSpeakers()

    if #speakers > 0 then
        local success, errorMessage = playTTS(
            "All systems online",
            speakers
        )

        if not success then
            print("TTS error: " .. tostring(errorMessage))
        end
    end
end

parallel.waitForAll(managerLoop, startupVoice)
