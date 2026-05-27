local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local env = (getgenv and getgenv()) or _G

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "BaconHub | Bobo Heist",
    LoadingTitle = "BaconHub",
    LoadingSubtitle = "Bobo Heist Controls",
    Theme = "Ocean",
    ConfigurationSaving = {
        Enabled = false,
    },
})

local BaseTab = Window:CreateTab("Base")
local ProgressTab = Window:CreateTab("Progress")
local PlayerTab = Window:CreateTab("Player")
local TargetsTab = Window:CreateTab("Targets")
local SettingsTab = Window:CreateTab("Settings")

local function addSection(tab, name)
    if tab and tab.CreateSection then
        pcall(function()
            tab:CreateSection(name)
        end)
    end
end

local function addDivider(tab)
    if tab and tab.CreateDivider then
        pcall(function()
            tab:CreateDivider()
        end)
    end
end

local rarityRank = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    God = 7,
    Secret = 8,
    Exclusive = 9,
}

local rarityOptions = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "God",
    "Secret",
    "Exclusive",
}

local selectedGrabRarities = {
    Legendary = true,
    Mythic = true,
    God = true,
    Secret = true,
    Exclusive = true,
}

local selectedStealRarities = {
    Epic = true,
    Legendary = true,
    Mythic = true,
    God = true,
    Secret = true,
    Exclusive = true,
}

local desiredWalkSpeed = 16
local autoRejoinEnabled = false
local autoRejoinRunning = false
local antiAfkEnabled = false
local states = {}

local reconnectDisabledList = {
    [Enum.ConnectionError.DisconnectLuaKick] = true,
    [Enum.ConnectionError.DisconnectSecurityKeyMismatch] = true,
    [Enum.ConnectionError.DisconnectNewSecurityKeyMismatch] = true,
    [Enum.ConnectionError.DisconnectDuplicateTicket] = true,
    [Enum.ConnectionError.DisconnectWrongVersion] = true,
    [Enum.ConnectionError.DisconnectProtocolMismatch] = true,
    [Enum.ConnectionError.DisconnectBadhash] = true,
    [Enum.ConnectionError.DisconnectIllegalTeleport] = true,
    [Enum.ConnectionError.DisconnectDuplicatePlayer] = true,
    [Enum.ConnectionError.DisconnectCloudEditKick] = true,
    [Enum.ConnectionError.DisconnectOnRemoteSysStats] = true,
    [Enum.ConnectionError.DisconnectRaknetErrors] = true,
    [Enum.ConnectionError.PlacelaunchFlooded] = true,
    [Enum.ConnectionError.PlacelaunchHashException] = true,
    [Enum.ConnectionError.PlacelaunchHashExpired] = true,
    [Enum.ConnectionError.PlacelaunchUnauthorized] = true,
    [Enum.ConnectionError.PlacelaunchUserLeft] = true,
    [Enum.ConnectionError.PlacelaunchRestricted] = true,
}

local function stopState(key)
    if states[key] then
        states[key].running = false
    end
end

local function newState(key, data)
    stopState(key)
    local state = data or {}
    state.running = true
    states[key] = state
    env[key] = state
    return state
end

local function getMap()
    return Workspace:FindFirstChild("Map")
end

local function getPlots()
    local map = getMap()
    return map and map:FindFirstChild("Plots")
end

local function getMyPlot()
    local plots = getPlots()
    if not plots then
        return nil
    end

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("OwnerName") == player.Name then
            return plot
        end
    end
end

local function getRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function applyWalkSpeed()
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = desiredWalkSpeed
        return true
    end
    return false
end

local function startKeepWalkSpeed()
    local state = newState("BaconHub_BoboKeepWalkSpeed", {
        applies = 0,
        lastError = nil,
    })

    task.spawn(function()
        while state.running do
            local ok, err = pcall(function()
                if applyWalkSpeed() then
                    state.applies += 1
                end
            end)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(0.2)
        end
    end)
end

GuiService.ErrorMessageChanged:Connect(function()
    if not autoRejoinEnabled or autoRejoinRunning then
        return
    end

    local errorCode = GuiService:GetErrorCode()
    local errorType = GuiService:GetErrorType()
    if errorType == Enum.ConnectionError.DisconnectErrors and not reconnectDisabledList[errorCode] then
        autoRejoinRunning = true
        task.spawn(function()
            while autoRejoinEnabled do
                task.wait(5)
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
                end)
            end
            autoRejoinRunning = false
        end)
    end
end)

player.Idled:Connect(function()
    if not antiAfkEnabled then
        return
    end

    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local function triggerPrompt(prompt)
    if not prompt then
        return false
    end

    if fireproximityprompt then
        fireproximityprompt(prompt)
    else
        prompt:InputHoldBegin()
        task.wait((prompt.HoldDuration or 0.5) + 0.15)
        prompt:InputHoldEnd()
    end

    return true
end

local function getInfoFrame(npc)
    local overhead = npc and npc:FindFirstChild("OverheadAttachment")
    local info = overhead and overhead:FindFirstChild("CharacterInfo")
    return info and info:FindFirstChild("Frame")
end

local function getText(frame, name)
    local label = frame and frame:FindFirstChild(name)
    if label and label:IsA("TextLabel") then
        return label.Text
    end
end

local function getNPCPosition(npc)
    if npc:IsA("Model") then
        return npc:GetPivot().Position
    end

    if npc:IsA("BasePart") then
        return npc.Position
    end

    local part = npc:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function getHomeCFrame()
    local plot = getMyPlot()
    local root = getRoot()

    if not plot then
        return root and root.CFrame or nil
    end

    local spawnPoint = plot:FindFirstChild("OwnerSpawnPoint")
    if spawnPoint and spawnPoint:IsA("Attachment") then
        return CFrame.new(spawnPoint.WorldPosition + Vector3.new(0, 3, 0))
    end

    local floor = plot:FindFirstChild("Floor")
    local base = floor and floor:FindFirstChild("Base")
    if base and base:IsA("BasePart") then
        return CFrame.new(base.Position + Vector3.new(0, 5, 0))
    end

    return plot:GetPivot() + Vector3.new(0, 5, 0)
end

local function returnHome()
    local root = getRoot()
    local home = getHomeCFrame()
    if root and home then
        root.CFrame = home
    end
end

local function setFromDropdown(value, target)
    table.clear(target)

    if typeof(value) == "table" then
        for key, enabled in pairs(value) do
            if enabled == true then
                target[key] = true
            elseif typeof(enabled) == "string" then
                target[enabled] = true
            end
        end

        for _, item in ipairs(value) do
            if typeof(item) == "string" then
                target[item] = true
            end
        end
    elseif typeof(value) == "string" then
        target[value] = true
    end
end

local function startAutoCollectCash()
    local state = newState("BaconHub_BoboAutoCollectCash", {
        firedCollectAll = 0,
        firedSlots = 0,
        touchedButtons = 0,
        lastError = nil,
    })

    local plotRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Plot")
    local collectCashRemote = plotRemotes:WaitForChild("CollectCash")
    local collectAllRemote = ReplicatedStorage:WaitForChild("CollectAllCash")

    local function touchButton(part)
        local root = getRoot()
        if not root or not part or not part:IsA("BasePart") then
            return
        end

        if firetouchinterest then
            firetouchinterest(root, part, 0)
            task.wait(0.03)
            firetouchinterest(root, part, 1)
        else
            part.CFrame = root.CFrame
        end

        state.touchedButtons += 1
    end

    local function collectOnce()
        collectAllRemote:FireServer()
        state.firedCollectAll += 1

        local plot = getMyPlot()
        local slots = plot and plot:FindFirstChild("Slots")
        if not slots then
            return
        end

        for _, slot in ipairs(slots:GetChildren()) do
            local slotNumber = tonumber(slot.Name)
            if slotNumber then
                collectCashRemote:FireServer(slotNumber)
                state.firedSlots += 1
            end

            local button = slot:FindFirstChild("Button")
            local top = button and button:FindFirstChild("Top")
            if top and top:IsA("BasePart") and top:FindFirstChild("TouchInterest") then
                touchButton(top)
            end
        end
    end

    task.spawn(function()
        while state.running do
            local ok, err = pcall(collectOnce)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(0.5)
        end
    end)
end

local function startAutoLockBase()
    local state = newState("BaconHub_BoboAutoLockBase", {
        touched = 0,
        lastError = nil,
    })

    local function timerSeconds(text)
        text = tostring(text or ""):lower():gsub("%s+", "")
        local number = tonumber(text:match("([%d%.]+)"))
        if not number then
            return nil
        end
        if text:find("m", 1, true) then
            return number * 60
        end
        if text:find("h", 1, true) then
            return number * 3600
        end
        return number
    end

    local function lockOnce()
        local plot = getMyPlot()
        local lockButton = plot and plot:FindFirstChild("LockButton")
        local attachment = lockButton and lockButton:FindFirstChild("BillboardAttachment")
        local lockGui = attachment and attachment:FindFirstChild("LockGui")
        local timerLabel = lockGui and lockGui:FindFirstChild("TimerLabel")
        local actionLabel = lockGui and lockGui:FindFirstChild("ActionLabel")
        local active = player:GetAttribute("LockBaseActive") == true
        local shouldLock = (actionLabel and actionLabel.Visible) or not active

        if not shouldLock then
            local seconds = timerSeconds(timerLabel and timerLabel.Text)
            shouldLock = seconds ~= nil and seconds <= 3
        end

        local root = getRoot()
        if shouldLock and root and lockButton and lockButton:IsA("BasePart") then
            if firetouchinterest then
                firetouchinterest(root, lockButton, 0)
                task.wait(0.05)
                firetouchinterest(root, lockButton, 1)
            else
                local oldCFrame = root.CFrame
                root.CFrame = lockButton.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.2)
                root.CFrame = oldCFrame
            end
            state.touched += 1
            task.wait(1)
        end
    end

    task.spawn(function()
        while state.running do
            local ok, err = pcall(lockOnce)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(0.5)
        end
    end)
end

local function startAutoUpgradeNPCs()
    local state = newState("BaconHub_BoboAutoUpgradeNPCs", {
        allMaxFires = 0,
        allOneFires = 0,
        lastError = nil,
    })

    local upgradeAllMaxNPCs = ReplicatedStorage:WaitForChild("UpgradeAllMaxNPCs")
    local upgradeAllNPCs = ReplicatedStorage:WaitForChild("UpgradeAllNPCs")

    task.spawn(function()
        while state.running do
            local ok, err = pcall(function()
                upgradeAllMaxNPCs:FireServer()
                state.allMaxFires += 1
                task.wait(0.15)
                upgradeAllNPCs:FireServer()
                state.allOneFires += 1
            end)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(1)
        end
    end)
end

local function startAutoUpgradeBase()
    local state = newState("BaconHub_BoboAutoUpgradeBase", {
        plotFires = 0,
        lastError = nil,
    })

    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local upgradePlotEvent = remotes:WaitForChild("UpgradePlotEvent")

    task.spawn(function()
        while state.running do
            local ok, err = pcall(function()
                upgradePlotEvent:FireServer()
                state.plotFires += 1
            end)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(1)
        end
    end)
end

local function startAutoGrab()
    local state = newState("BaconHub_BoboAutoGrabLegendaries", {
        grabbed = 0,
        lastTarget = nil,
        lastRarity = nil,
        lastError = nil,
    })

    local function getFieldNPCFolder()
        local map = getMap()
        local zones = map and map:FindFirstChild("Zones")
        local field = zones and zones:FindFirstChild("Field")
        return field and field:FindFirstChild("NPC")
    end

    local function getPickupPrompt(npc)
        local prompts = npc:FindFirstChild("Prompts")
        local prompt = prompts and prompts:FindFirstChild("Pickup")
        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            return prompt
        end
    end

    local function grabNPC(npc, prompt)
        local root = getRoot()
        local targetPosition = getNPCPosition(npc)
        if not root or not targetPosition then
            return false
        end

        local oldCFrame = root.CFrame
        root.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
        task.wait(0.15)
        triggerPrompt(prompt)
        task.wait(0.2)
        if root.Parent then
            root.CFrame = oldCFrame
        end
        state.grabbed += 1
        return true
    end

    local function grabOnce()
        local folder = getFieldNPCFolder()
        if not folder then
            return
        end

        local targets = {}
        for _, npc in ipairs(folder:GetChildren()) do
            local frame = getInfoFrame(npc)
            local rarity = getText(frame, "Rarity")
            if rarity and selectedGrabRarities[rarity] then
                local prompt = getPickupPrompt(npc)
                if prompt then
                    table.insert(targets, {
                        npc = npc,
                        prompt = prompt,
                        rarity = rarity,
                        name = getText(frame, "CharacterName") or npc.Name,
                        rank = rarityRank[rarity] or 0,
                    })
                end
            end
        end

        table.sort(targets, function(a, b)
            return a.rank > b.rank
        end)

        local target = targets[1]
        if target then
            state.lastTarget = target.name
            state.lastRarity = target.rarity
            grabNPC(target.npc, target.prompt)
            task.wait(1)
        end
    end

    task.spawn(function()
        while state.running do
            local ok, err = pcall(grabOnce)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(0.5)
        end
    end)
end

local function startAutoSteal()
    local state = newState("BaconHub_BoboAutoSteal", {
        checks = 0,
        attempts = 0,
        steals = 0,
        lastStatus = "Fast checking locks",
        lastError = nil,
    })

    local function isPlotUnlocked(plot)
        local lockButton = plot:FindFirstChild("LockButton")
        local attachment = lockButton and lockButton:FindFirstChild("BillboardAttachment")
        local gui = attachment and attachment:FindFirstChild("LockGui")
        local lockedLabel = gui and gui:FindFirstChild("LockedLabel")
        local timerLabel = gui and gui:FindFirstChild("TimerLabel")
        local actionLabel = gui and gui:FindFirstChild("ActionLabel")

        if lockedLabel and lockedLabel:IsA("TextLabel") and lockedLabel.Visible then
            return false
        end
        if timerLabel and timerLabel:IsA("TextLabel") and timerLabel.Visible then
            return false
        end
        if actionLabel and actionLabel:IsA("TextLabel") and actionLabel.Visible then
            return true
        end
        return true
    end

    local function findFreeStealPrompt(slot)
        for _, inst in ipairs(slot:GetDescendants()) do
            if inst:IsA("ProximityPrompt")
                and inst.Enabled
                and inst.Name == "FreeStealPrompt"
                and inst.ActionText == "Free"
                and inst.KeyboardKeyCode == Enum.KeyCode.R then
                return inst
            end
        end
    end

    local function getBestTargetFromUnlockedPlot(plot)
        local slots = plot:FindFirstChild("Slots")
        if not slots then
            return nil
        end

        local best
        for _, slot in ipairs(slots:GetChildren()) do
            local npc = slot:FindFirstChild("NPCModel")
            local frame = getInfoFrame(npc)
            local rarity = getText(frame, "Rarity")
            local rank = rarityRank[rarity] or 0
            if npc and selectedStealRarities[rarity] and not slot:GetAttribute("StolenBy") then
                local target = {
                    plot = plot,
                    owner = plot:GetAttribute("OwnerName"),
                    slot = slot,
                    npc = npc,
                    name = getText(frame, "CharacterName") or "Unknown",
                    rarity = rarity,
                    rank = rank,
                    pos = getNPCPosition(npc),
                }
                if not best or target.rank > best.rank then
                    best = target
                end
            end
        end
        return best
    end

    local function tryTarget(target)
        local root = getRoot()
        if not root or not target or not target.pos then
            return false
        end

        state.attempts += 1
        state.lastTarget = target.name
        state.lastRarity = target.rarity
        state.lastStatus = "Unlocked base found, loading Free prompt"

        local oldCFrame = root.CFrame
        root.CFrame = CFrame.new(target.pos + Vector3.new(0, 3, 0))

        local prompt
        local started = os.clock()
        while os.clock() - started < 2 and state.running do
            prompt = findFreeStealPrompt(target.slot)
            if prompt then
                break
            end
            task.wait(0.05)
        end

        if prompt and triggerPrompt(prompt) then
            state.steals += 1
            state.lastStatus = "Triggered FreeStealPrompt (R)"
            task.wait(0.4)
            returnHome()
            return true
        end

        state.lastStatus = "Unlocked target had no Free prompt"
        if root.Parent and oldCFrame then
            root.CFrame = oldCFrame
        end
        return false
    end

    local busy = false
    local function fastCheckOnce()
        if busy then
            return
        end
        state.checks += 1

        local plots = getPlots()
        if not plots then
            state.lastStatus = "No plots folder"
            return
        end

        for _, plot in ipairs(plots:GetChildren()) do
            local owner = plot:GetAttribute("OwnerName")
            if owner and owner ~= player.Name and isPlotUnlocked(plot) then
                local best = getBestTargetFromUnlockedPlot(plot)
                if best then
                    busy = true
                    pcall(function()
                        tryTarget(best)
                    end)
                    busy = false
                    return
                end
            end
        end

        state.lastStatus = "Fast checking locks"
    end

    task.spawn(function()
        while state.running do
            local ok, err = pcall(fastCheckOnce)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(0.05)
        end
    end)
end

local function startAutoEquipBest()
    local state = newState("BaconHub_BoboAutoEquipBest", {
        fires = 0,
        lastError = nil,
    })

    local equipBest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Plot"):WaitForChild("EquipBestNPCs")
    task.spawn(function()
        while state.running do
            local ok, err = pcall(function()
                equipBest:FireServer()
                state.fires += 1
            end)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(10)
        end
    end)
end

local function startAutoPlaytimeRewards()
    local state = newState("BaconHub_BoboAutoPlaytimeRewards", {
        checks = 0,
        claims = 0,
        lastError = nil,
    })

    local recv = ReplicatedStorage:WaitForChild("Recv")
    local function getPlayTime()
        local playTime = player:FindFirstChild("PlayTime")
        return playTime and playTime.Value or 0
    end

    local function claimReadyRewards()
        state.checks += 1
        local ok, rewards = pcall(function()
            return recv:InvokeServer("GetTimeRewardsStatus")
        end)
        if not ok or typeof(rewards) ~= "table" then
            state.lastError = not ok and tostring(rewards) or state.lastError
            return
        end

        local playTime = getPlayTime()
        for index, reward in ipairs(rewards) do
            local canClaim = reward.CanClaim == true or (reward.Minutes and playTime >= reward.Minutes * 60)
            if canClaim and reward.ClaimUsed ~= true then
                local claimedOk, result = pcall(function()
                    return recv:InvokeServer("TimeGift", index)
                end)
                if claimedOk and result then
                    state.claims += 1
                    task.wait(0.15)
                elseif not claimedOk then
                    state.lastError = tostring(result)
                end
            end
        end
    end

    task.spawn(function()
        while state.running do
            local ok, err = pcall(claimReadyRewards)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(5)
        end
    end)
end

local function startAutoRebirth()
    local state = newState("BaconHub_BoboAutoRebirth", {
        checks = 0,
        rebirths = 0,
        lastError = nil,
    })

    local rebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth")
    local function getUILevels()
        local gui = player:FindFirstChild("PlayerGui")
        local main = gui and gui:FindFirstChild("MainUI")
        local menus = main and main:FindFirstChild("Menus")
        local frame = menus and menus:FindFirstChild("RebirthFrame")
        local label = frame and frame:FindFirstChild("Bar") and frame.Bar:FindFirstChild("Level")
        local text = label and label.Text or ""
        local current, required = text:match("Level%s*(%d+)%s*/%s*(%d+)")
        return tonumber(current), tonumber(required), text
    end

    task.spawn(function()
        while state.running do
            local ok, err = pcall(function()
                state.checks += 1
                local level, required, rawText = getUILevels()
                state.lastLevel = level
                state.lastRequired = required
                if level and required and level >= required then
                    rebirthRemote:FireServer("REBIRTH")
                    state.rebirths += 1
                    state.lastStatus = "Fired rebirth from " .. tostring(rawText)
                    task.wait(1.5)
                else
                    state.lastStatus = "Waiting for level requirement"
                end
            end)
            if not ok then
                state.lastError = tostring(err)
            end
            task.wait(1)
        end
    end)
end

addSection(BaseTab, "Base")

BaseTab:CreateToggle({
    Name = "Auto Lock",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoLockBase() else stopState("BaconHub_BoboAutoLockBase") end
    end,
})

BaseTab:CreateToggle({
    Name = "Auto Cash",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoCollectCash() else stopState("BaconHub_BoboAutoCollectCash") end
    end,
})

addSection(BaseTab, "Upgrades")

BaseTab:CreateToggle({
    Name = "Auto Upgrade Base",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoUpgradeBase() else stopState("BaconHub_BoboAutoUpgradeBase") end
    end,
})

addSection(ProgressTab, "NPCs")

ProgressTab:CreateToggle({
    Name = "Auto Upgrade NPCs",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoUpgradeNPCs() else stopState("BaconHub_BoboAutoUpgradeNPCs") end
    end,
})

ProgressTab:CreateToggle({
    Name = "Auto Equip Best",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoEquipBest() else stopState("BaconHub_BoboAutoEquipBest") end
    end,
})

addSection(ProgressTab, "Rewards")

ProgressTab:CreateToggle({
    Name = "Auto Playtime Rewards",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoPlaytimeRewards() else stopState("BaconHub_BoboAutoPlaytimeRewards") end
    end,
})

ProgressTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoRebirth() else stopState("BaconHub_BoboAutoRebirth") end
    end,
})

addSection(PlayerTab, "Movement")

PlayerTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {1, 200},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = desiredWalkSpeed,
    Callback = function(value)
        desiredWalkSpeed = tonumber(value) or desiredWalkSpeed
        applyWalkSpeed()
    end,
})

PlayerTab:CreateToggle({
    Name = "Keep WalkSpeed",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startKeepWalkSpeed()
        else
            stopState("BaconHub_BoboKeepWalkSpeed")
        end
    end,
})

PlayerTab:CreateButton({
    Name = "Reset WalkSpeed",
    Callback = function()
        desiredWalkSpeed = 16
        applyWalkSpeed()
    end,
})

addSection(TargetsTab, "Grab")

TargetsTab:CreateDropdown({
    Name = "Grab Rarities",
    Options = rarityOptions,
    CurrentOption = {"Legendary", "Mythic", "God", "Secret", "Exclusive"},
    MultipleOptions = true,
    Callback = function(value)
        setFromDropdown(value, selectedGrabRarities)
    end,
})

TargetsTab:CreateToggle({
    Name = "Auto Grab",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoGrab() else stopState("BaconHub_BoboAutoGrabLegendaries") end
    end,
})

addDivider(TargetsTab)
addSection(TargetsTab, "Steal")

TargetsTab:CreateDropdown({
    Name = "Steal Rarities",
    Options = rarityOptions,
    CurrentOption = {"Epic", "Legendary", "Mythic", "God", "Secret", "Exclusive"},
    MultipleOptions = true,
    Callback = function(value)
        setFromDropdown(value, selectedStealRarities)
    end,
})

TargetsTab:CreateToggle({
    Name = "Auto Steal",
    CurrentValue = false,
    Callback = function(value)
        if value then startAutoSteal() else stopState("BaconHub_BoboAutoSteal") end
    end,
})

addSection(SettingsTab, "Connection")

SettingsTab:CreateToggle({
    Name = "Auto Rejoin",
    CurrentValue = false,
    Callback = function(value)
        autoRejoinEnabled = value
        if not value then
            autoRejoinRunning = false
        end
    end,
})

SettingsTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Callback = function(value)
        antiAfkEnabled = value
    end,
})
