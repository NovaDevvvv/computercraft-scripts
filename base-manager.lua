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

local activeTab = "home"
local volume = 1.5
local speechText = ""
local statusMessage = ""
local statusUntil = 0

local doorOpen = false
local baseCount = 0
local speakerCount = 0

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

local function getSpeakers()
    local speakers = {}

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "speaker") then
            table.insert(speakers, {
                name = name,
                device = peripheral.wrap(name)
            })
        end
    end

    return speakers
end

local function setStatus(message, duration)
    statusMessage = message
    statusUntil = os.clock() + (duration or 3)
end

local function playPdaChime(speakers)
    speakers = speakers or getSpeakers()

    local notes = { 12, 16, 20 }

    for _, pitch in ipairs(notes) do
        for _, speaker in ipairs(speakers) do
            speaker.device.playNote("bell", volume, pitch)
        end

        sleep(0.15)
    end
end

local function speak(text, shouldChime)
    if text == nil or text == "" then
        setStatus("Enter some text first", 3)
        return false
    end

    local speakers = getSpeakers()

    if #speakers == 0 then
        setStatus("No speakers connected", 3)
        return false
    end

    if shouldChime ~= false then
        playPdaChime(speakers)
        -- Let the final note finish before starting streamed audio on the
        -- same speaker.
        sleep(0.5)
    end
    setStatus("Speaking...", 10)

    local url = TTS_URL .. textutils.urlEncode(text)

    local bytesPlayed = 0
    local success, problem = pcall(function()
        -- TTS returns headerless binary DFPWM. Requesting a binary handle
        -- prevents the encoded audio from being treated as text.
        local response, requestProblem = http.get(
            url,
            {
                ["Accept"] = "application/octet-stream",
                ["Cache-Control"] = "no-cache"
            },
            true
        )

        if not response then
            error(requestProblem or "TTS download failed", 0)
        end

        local decoder = require("cc.audio.dfpwm").make_decoder()
        local speaker = speakers[1].device

        while true do
            local chunk = response.read(16 * 1024)

            if not chunk then
                break
            end

            bytesPlayed = bytesPlayed + #chunk
            local audio = decoder(chunk)

            while not speaker.playAudio(audio, volume) do
                os.pullEvent("speaker_audio_empty")
            end
        end

        response.close()
    end)

    if success then
        if bytesPlayed == 0 then
            setStatus("Speech failed: empty audio", 6)
            return false
        end

        setStatus(
            "Spoke " .. tostring(bytesPlayed) .. " audio bytes",
            4
        )
    else
        setStatus(
            "Speech failed: " .. tostring(problem),
            6
        )
    end

    return success
end

local function queueSpeech(text)
    if text == nil or text == "" then
        setStatus("Enter some text first", 3)
        return false
    end

    os.queueEvent("base_manager_speak", text)
    setStatus("Message queued", 2)
    return true
end

local function playStartupChime()
    playPdaChime()
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

-- peripheral.find returns wrapped peripherals, not their wired names. The
-- monitor_touch event supplies the name, so resolve it from the wrapper.
local monitorName = peripheral.getName(monitor)

monitor.setTextScale(0.5)
monitor.setCursorBlink(false)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local width, height = monitor.getSize()

local function writeAt(x, y, text, foreground, background)
    if y < 1 or y > height then
        return
    end

    text = tostring(text or "")

    monitor.setCursorPos(math.max(1, x), y)
    monitor.setTextColor(foreground or colors.white)
    monitor.setBackgroundColor(background or colors.black)
    monitor.write(text)
end

local function fill(x, y, fillWidth, fillHeight, background)
    monitor.setBackgroundColor(background)

    for row = y, y + fillHeight - 1 do
        if row >= 1 and row <= height then
            monitor.setCursorPos(math.max(1, x), row)
            monitor.write(string.rep(" ", math.max(0, fillWidth)))
        end
    end
end

local function button(x, y, buttonWidth, text, selected)
    local background = selected and colors.cyan or colors.gray
    local foreground = selected and colors.black or colors.white

    fill(x, y, buttonWidth, 1, background)

    local textX =
        x + math.floor((buttonWidth - #text) / 2)

    writeAt(
        textX,
        y,
        text,
        foreground,
        background
    )
end

local function drawTabs()
    local tabWidth = math.floor(width / 2)

    button(
        1,
        height,
        tabWidth,
        "HOME",
        activeTab == "home"
    )

    button(
        tabWidth + 1,
        height,
        width - tabWidth,
        "SOUND",
        activeTab == "sound"
    )
end

local function drawHeader(title)
    fill(1, 1, width, height, colors.black)

    writeAt(
        2,
        2,
        "BASE MANAGER",
        colors.cyan,
        colors.black
    )

    writeAt(
        2,
        3,
        title,
        colors.lightGray,
        colors.black
    )

    writeAt(
        2,
        4,
        string.rep("-", math.max(1, width - 3)),
        colors.gray,
        colors.black
    )
end

local function drawHome()
    drawHeader("HOME")

    writeAt(
        2,
        6,
        DOOR_NAME .. ": ",
        colors.white
    )

    local statusX = 2 + #DOOR_NAME + 2

    if doorOpen then
        writeAt(
            statusX,
            6,
            "OPEN",
            colors.lime
        )
    else
        writeAt(
            statusX,
            6,
            "CLOSED",
            colors.red
        )
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

    writeAt(
        2,
        height - 2,
        "Uptime: " .. formatUptime(),
        colors.gray
    )

    drawTabs()
end

local function getSliderBounds()
    return 4, math.max(5, width - 3)
end

local function drawSlider()
    local sliderStart, sliderEnd = getSliderBounds()
    local sliderWidth = sliderEnd - sliderStart

    writeAt(
        2,
        6,
        "Volume: " .. string.format("%.1f", volume),
        colors.white
    )

    writeAt(
        sliderStart,
        8,
        string.rep("-", sliderWidth + 1),
        colors.gray
    )

    local position =
        sliderStart
        + math.floor((volume / 3) * sliderWidth)

    writeAt(
        position,
        8,
        "#",
        colors.lime
    )

    writeAt(
        sliderStart,
        9,
        "0",
        colors.gray
    )

    writeAt(
        sliderEnd,
        9,
        "3",
        colors.gray
    )
end

local keyboardRows = {
    "QWERTYUIOP",
    "ASDFGHJKL",
    "ZXCVBNM"
}

local function keyboardLayout()
    local startY = 15
    local keyWidth = 3
    local rows = {}

    for rowIndex, characters in ipairs(keyboardRows) do
        local rowWidth = #characters * keyWidth
        local startX = math.max(
            1,
            math.floor((width - rowWidth) / 2) + 1
        )

        rows[rowIndex] = {
            text = characters,
            x = startX,
            y = startY + rowIndex - 1,
            keyWidth = keyWidth
        }
    end

    return rows
end

local function drawKeyboard()
    local rows = keyboardLayout()

    for _, row in ipairs(rows) do
        for index = 1, #row.text do
            local character = row.text:sub(index, index)
            local x = row.x + ((index - 1) * row.keyWidth)

            fill(
                x,
                row.y,
                row.keyWidth - 1,
                1,
                colors.gray
            )

            writeAt(
                x,
                row.y,
                character,
                colors.white,
                colors.gray
            )
        end
    end

    local controlsY = 19

    if controlsY < height then
        button(2, controlsY, 8, "SPACE", false)
        button(11, controlsY, 7, "BACK", false)
        button(19, controlsY, 8, "CLEAR", false)
    end
end

local function drawSound()
    drawHeader("SOUND CONTROL")

    drawSlider()

    writeAt(
        2,
        11,
        "Text:",
        colors.lightGray
    )

    fill(
        2,
        12,
        math.max(1, width - 12),
        1,
        colors.gray
    )

    local visibleText = speechText

    if visibleText == "" then
        visibleText = "Touch keys below"
    end

    writeAt(
        3,
        12,
        visibleText:sub(1, math.max(1, width - 14)),
        speechText == "" and colors.lightGray or colors.white,
        colors.gray
    )

    button(
        math.max(2, width - 8),
        12,
        7,
        "SPEAK",
        false
    )

    drawKeyboard()

    if statusMessage ~= "" and os.clock() < statusUntil then
        writeAt(
            2,
            height - 2,
            statusMessage:sub(1, width - 2),
            colors.yellow
        )
    else
        writeAt(
            2,
            height - 2,
            "Speakers: " .. tostring(speakerCount),
            colors.gray
        )
    end

    drawTabs()
end

local function redraw()
    width, height = monitor.getSize()

    if activeTab == "sound" then
        drawSound()
    else
        drawHome()
    end
end

local function updateBaseState()
    local hallwayPlayers =
        detector.getPlayersInRange(DOOR_RANGE) or {}

    local basePlayers =
        detector.getPlayersInRange(BASE_RANGE) or {}

    doorOpen = #hallwayPlayers > 0
    baseCount = #basePlayers
    speakerCount = #getSpeakers()

    integrator.setOutput(
        OUTPUT_SIDE,
        doorOpen
    )
end

local function inside(x, y, left, top, right, bottom)
    return
        x >= left
        and x <= right
        and y >= top
        and y <= bottom
end

local function handleKeyboardTouch(x, y)
    local rows = keyboardLayout()

    for _, row in ipairs(rows) do
        if y == row.y then
            for index = 1, #row.text do
                local keyX =
                    row.x
                    + ((index - 1) * row.keyWidth)

                if x >= keyX and x <= keyX + row.keyWidth - 2 then
                    local character =
                        row.text:sub(index, index)

                    if #speechText < 100 then
                        speechText = speechText .. character
                    end

                    return true
                end
            end
        end
    end

    local controlsY = 19

    if y == controlsY then
        if x >= 2 and x <= 9 then
            if #speechText < 100 then
                speechText = speechText .. " "
            end

            return true
        elseif x >= 11 and x <= 17 then
            speechText = speechText:sub(
                1,
                math.max(0, #speechText - 1)
            )

            return true
        elseif x >= 19 and x <= 26 then
            speechText = ""
            return true
        end
    end

    return false
end

local function handleTouch(x, y)
    local tabWidth = math.floor(width / 2)

    if y == height then
        if x <= tabWidth then
            activeTab = "home"
        else
            activeTab = "sound"
        end

        redraw()
        return
    end

    if activeTab ~= "sound" then
        return
    end

    local sliderStart, sliderEnd = getSliderBounds()

    if y >= 7 and y <= 9
        and x >= sliderStart
        and x <= sliderEnd then

        volume =
            ((x - sliderStart)
            / math.max(1, sliderEnd - sliderStart))
            * 3

        volume =
            math.floor(volume * 10 + 0.5) / 10

        redraw()
        return
    end

    if inside(
        x,
        y,
        math.max(2, width - 8),
        12,
        width - 2,
        12
    ) then
        queueSpeech(speechText)
        redraw()
        return
    end

    if handleKeyboardTouch(x, y) then
        redraw()
    end
end

local function managerLoop()
    updateBaseState()
    redraw()

    local timer = os.startTimer(UPDATE_RATE)

    while true do
        local event, first, second, third =
            os.pullEvent()

        if event == "timer" and first == timer then
            updateBaseState()
            redraw()
            timer = os.startTimer(UPDATE_RATE)

        elseif event == "monitor_touch"
            and first == monitorName then

            handleTouch(second, third)

        elseif event == "peripheral"
            or event == "peripheral_detach" then

            updateBaseState()
            redraw()
        end
    end
end

local function audioLoop()
    sleep(2)

    speakerCount = #getSpeakers()

    if speakerCount > 0 then
        playStartupChime()
        sleep(0.4)

        speak("All systems online", false)
    end

    while true do
        local _, text = os.pullEvent("base_manager_speak")

        speak(text)
    end
end

local ok, problem = pcall(function()
    -- Keep redstone/player detection responsive while audio streams in its
    -- own event task.
    parallel.waitForAll(
        managerLoop,
        audioLoop
    )
end)

integrator.setOutput(OUTPUT_SIDE, false)

if not ok and tostring(problem) ~= "Terminated" then
    printError(problem)
end
