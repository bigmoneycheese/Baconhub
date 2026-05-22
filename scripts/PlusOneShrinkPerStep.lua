local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("Events")

local itemLib = require(ReplicatedStorage.Modules:WaitForChild("ItemLib"))
local tableLib = require(ReplicatedStorage.Modules:WaitForChild("TableLib"))
local giftLib = require(ReplicatedStorage.Modules:WaitForChild("GiftLib"))
local levelHandler = require(ReplicatedStorage.Modules:WaitForChild("LevelHandler"))

local getPlayerData = events:WaitForChild("GetPlayerData")
local rebirthRemote = events:WaitForChild("Rebirth")
local claimPlaytimeRemote = events:WaitForChild("ClaimPlaytime")

local state = {
	autoBestTable = false,
	autoWalk = false,
	autoWin = false,
	autoProgressCycle = false,
	autoBuyBestCube = false,
	autoRebirth = false,
	autoClaimPlaytime = false,
	bestTableDelay = 2,
	autoWinDelay = 1,
	progressCycleDelay = 1,
	progressCycleTargetLevel = 50,
	autoBuyCubeDelay = 2,
	autoRebirthDelay = 1,
	claimPlaytimeDelay = 2,
	autoWalkTurnRate = 0.085,
	progressCycleWalkTurnRate = 0.085,
}

local Window = Rayfield:CreateWindow({
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "+1 Shrink per Step",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "PlusOneShrinkPerStep",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local MovementTab = Window:CreateTab("Movement", 0)
local WinsTab = Window:CreateTab("Wins", 0)
local ProgressionTab = Window:CreateTab("Progression", 0)
local UpgradesTab = Window:CreateTab("Upgrades", 0)
local RewardsTab = Window:CreateTab("Rewards", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

local function notify(title, content)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 3,
		Image = 0,
	})
end

local function getCharacterParts()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")

	return character, humanoid, rootPart
end

local function getStats()
	local ok, data = pcall(function()
		return getPlayerData:InvokeServer()
	end)

	if ok and data and data.Stats then
		return data.Stats
	end

	return nil
end

local function hasRequiredGamepass(tableInfo)
	if not tableInfo.RequiredGamepass then
		return true
	end

	return player:GetAttribute("GamePass_" .. tableInfo.RequiredGamepass) == true
end

local function getBestTable()
	local stats = getStats()

	if not stats then
		return nil
	end

	local bestTable = nil
	local bestInfo = nil

	for tableName, tableInfo in pairs(tableLib) do
		local tableModel = workspace.Tables:FindFirstChild(tableName)

		if tableModel and tableModel:FindFirstChild("Main") then
			local hasRebirths = (stats.Rebirths or 0) >= (tableInfo.RequiredRebirths or 0)

			if hasRebirths and hasRequiredGamepass(tableInfo) then
				if not bestInfo or tableInfo.Increase > bestInfo.Increase then
					bestTable = tableModel
					bestInfo = tableInfo
				end
			end
		end
	end

	return bestTable, bestInfo
end

local function teleportToBestTable()
	local bestTable, bestInfo = getBestTable()

	if bestTable and bestTable:FindFirstChild("Main") then
		local character, _, rootPart = getCharacterParts()
		rootPart.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(bestTable.Main.CFrame + Vector3.new(0, 4, -3))
		return true, bestTable.Name, bestInfo.Increase
	end

	return false
end

local function getBestEligibleWinPart()
	local rooms = workspace:WaitForChild("Rooms")
	local stats = getStats()
	local playerLevel = stats and stats.Level or 0
	local productLevel = player:GetAttribute("_ProductLevel") or 0
	local bestRoom = nil
	local highestCost = -math.huge

	for _, room in ipairs(rooms:GetChildren()) do
		local primaryPart = room.PrimaryPart
		local cost = primaryPart and primaryPart:GetAttribute("_Cost")

		if typeof(cost) == "number" and cost - 1 < playerLevel and cost > highestCost then
			highestCost = cost
			bestRoom = room
		elseif typeof(cost) == "number" and productLevel >= cost and cost > highestCost then
			highestCost = cost
			bestRoom = room
		end
	end

	return bestRoom and bestRoom:FindFirstChild("Win"), bestRoom, playerLevel
end

local function crossWinPart(character, humanoid, rootPart, winPart, shouldContinue)
	local forward = winPart.CFrame.LookVector
	local startPosition = winPart.Position - forward * 7 + Vector3.new(0, 3, 0)
	local endPosition = winPart.Position + forward * 7 + Vector3.new(0, 3, 0)

	rootPart.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.new(startPosition, endPosition))
	task.wait(0.1)

	humanoid:MoveTo(endPosition)
	humanoid.WalkToPoint = endPosition
	task.wait(0.65)

	if not shouldContinue or shouldContinue() then
		rootPart.AssemblyLinearVelocity = forward * 18
		character:PivotTo(CFrame.new(winPart.Position + Vector3.new(0, 2.5, 0), endPosition))
		task.wait(0.2)
		rootPart.AssemblyLinearVelocity = Vector3.zero
	end
end

local function runAutoWin(shouldContinue)
	local winPart, room = getBestEligibleWinPart()

	if winPart and winPart:IsA("BasePart") then
		local character, humanoid, rootPart = getCharacterParts()
		crossWinPart(character, humanoid, rootPart, winPart, shouldContinue)
		return true, room and room.Name
	end

	return false
end

local function getCubeNode(cubeName)
	local nodes = workspace:WaitForChild("Nodes")

	for _, node in ipairs(nodes:GetChildren()) do
		local model = node:FindFirstChild("Model")
		local main = model and model:FindFirstChild("Main")
		local attachment = main and main:FindFirstChild("Attachment")
		local prompt = attachment and attachment:FindFirstChild("Buy")
		local displayAttachment = main and main:FindFirstChild("Attachment2")

		if displayAttachment and displayAttachment:GetAttribute("Name") == cubeName and prompt then
			return main, prompt
		end
	end

	return nil
end

local function getBestAffordableCube(stats)
	local bestName = nil
	local bestInfo = nil

	for cubeName, cubeInfo in pairs(itemLib) do
		local cost = cubeInfo.Cost

		if typeof(cost) == "number" and cost >= 0 and cost <= stats.Wins then
			if not bestInfo or cubeInfo.Multiplier > bestInfo.Multiplier then
				bestName = cubeName
				bestInfo = cubeInfo
			end
		end
	end

	return bestName, bestInfo
end

local function triggerPrompt(prompt)
	if typeof(fireproximityprompt) == "function" then
		fireproximityprompt(prompt)
		return
	end

	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.15)
	prompt:InputHoldEnd()
end

local function buyBestCube()
	local stats = getStats()

	if not stats then
		return false
	end

	local cubeName, cubeInfo = getBestAffordableCube(stats)

	if not cubeName then
		return false
	end

	if stats.EquippedItem == cubeName then
		return true, cubeName
	end

	local main, prompt = getCubeNode(cubeName)

	if not main or not prompt then
		return false
	end

	local character, _, rootPart = getCharacterParts()
	rootPart.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(main.CFrame + Vector3.new(0, 4, 0))
	task.wait(0.2)
	triggerPrompt(prompt)

	return true, cubeName, cubeInfo.Multiplier
end

local isRebirthing = false

local function tryRebirth()
	if isRebirthing then
		return false
	end

	local stats = getStats()

	if not stats then
		return false
	end

	local rebirths = stats.Rebirths or 0
	local level = stats.Level or 0
	local requiredLevel = levelHandler.getLevelCap(rebirths)

	if level < requiredLevel then
		return false
	end

	isRebirthing = true

	local ok, success = pcall(function()
		return rebirthRemote:InvokeServer()
	end)

	task.wait(0.5)
	isRebirthing = false

	return ok and success == true
end

local claimingPlaytime = false

local function claimReadyPlaytimeRewards()
	if claimingPlaytime then
		return 0
	end

	local loginTime = player:GetAttribute("Login")

	if not loginTime then
		return 0
	end

	local claimedCount = 0
	local serverTime = workspace:GetServerTimeNow()
	claimingPlaytime = true

	for index, giftInfo in ipairs(giftLib) do
		local alreadyClaimed = player:GetAttribute("__Gift" .. index)
		local ready = serverTime >= loginTime + giftInfo.Time

		if ready and not alreadyClaimed then
			pcall(function()
				claimPlaytimeRemote:InvokeServer(index)
			end)

			claimedCount += 1
			task.wait(0.2)
		end
	end

	claimingPlaytime = false
	return claimedCount
end

local progressCycleWalkAngle = 0

local function walkForProgressCycle(duration)
	local stopAt = os.clock() + duration

	while state.autoProgressCycle and os.clock() < stopAt do
		local _, humanoid, rootPart = getCharacterParts()

		if humanoid.Health > 0 then
			progressCycleWalkAngle += state.progressCycleWalkTurnRate

			local right = rootPart.CFrame.RightVector
			local forward = rootPart.CFrame.LookVector
			local moveDirection = right * math.cos(progressCycleWalkAngle) + forward * math.sin(progressCycleWalkAngle)

			humanoid:Move(moveDirection.Unit, false)
		end

		RunService.Heartbeat:Wait()
	end
end

task.spawn(function()
	while true do
		if state.autoBestTable then
			teleportToBestTable()
			task.wait(state.bestTableDelay)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	local angle = 0

	while true do
		if state.autoWalk then
			local _, humanoid, rootPart = getCharacterParts()

			if humanoid.Health > 0 then
				angle += state.autoWalkTurnRate

				local right = rootPart.CFrame.RightVector
				local forward = rootPart.CFrame.LookVector
				local moveDirection = right * math.cos(angle) + forward * math.sin(angle)

				humanoid:Move(moveDirection.Unit, false)
			end

			RunService.Heartbeat:Wait()
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoWin then
			runAutoWin(function()
				return state.autoWin
			end)
			task.wait(state.autoWinDelay)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoProgressCycle then
			local stats = getStats()

			if stats then
				local level = stats.Level or 0
				local rebirths = stats.Rebirths or 0
				local requiredLevel = levelHandler.getLevelCap(rebirths)
				local targetLevel = math.min(state.progressCycleTargetLevel, requiredLevel)

				if level >= requiredLevel then
					tryRebirth()
				elseif level >= targetLevel then
					runAutoWin(function()
						return state.autoProgressCycle
					end)
				else
					teleportToBestTable()
					walkForProgressCycle(state.progressCycleDelay)
				end
			end

			task.wait(0.05)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoBuyBestCube then
			buyBestCube()
			task.wait(state.autoBuyCubeDelay)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoRebirth then
			tryRebirth()
			task.wait(state.autoRebirthDelay)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoClaimPlaytime then
			claimReadyPlaytimeRewards()
			task.wait(state.claimPlaytimeDelay)
		else
			task.wait(0.15)
		end
	end
end)

MovementTab:CreateSection("Tables")

MovementTab:CreateToggle({
	Name = "Auto Best Table",
	CurrentValue = false,
	Flag = "AutoBestTable",
	Callback = function(value)
		state.autoBestTable = value
		notify("Auto Best Table", value and "Enabled" or "Disabled")
	end,
})

MovementTab:CreateButton({
	Name = "Teleport To Best Table",
	Callback = function()
		local success, tableName, multiplier = teleportToBestTable()
		notify("Best Table", success and ("Teleported to " .. tableName .. " (" .. tostring(multiplier) .. "x)") or "No unlocked table found.")
	end,
})

MovementTab:CreateSection("Walking")

MovementTab:CreateToggle({
	Name = "Auto Walk",
	CurrentValue = false,
	Flag = "AutoWalk",
	Callback = function(value)
		state.autoWalk = value
		notify("Auto Walk", value and "Enabled" or "Disabled")
	end,
})

WinsTab:CreateSection("Wins")

WinsTab:CreateToggle({
	Name = "Auto Win",
	CurrentValue = false,
	Flag = "AutoWin",
	Callback = function(value)
		state.autoWin = value
		notify("Auto Win", value and "Enabled" or "Disabled")
	end,
})

WinsTab:CreateButton({
	Name = "Claim Best Eligible Win",
	Callback = function()
		local success, roomName = runAutoWin()
		notify("Auto Win", success and ("Triggered room " .. tostring(roomName)) or "No eligible win area found.")
	end,
})

ProgressionTab:CreateSection("Cycle")

ProgressionTab:CreateToggle({
	Name = "Auto Table Then Win",
	CurrentValue = false,
	Flag = "AutoTableThenWin",
	Callback = function(value)
		state.autoProgressCycle = value
		notify("Progression Cycle", value and "Enabled" or "Disabled")
	end,
})

ProgressionTab:CreateSlider({
	Name = "Win At Level",
	Range = {1, 700},
	Increment = 1,
	CurrentValue = state.progressCycleTargetLevel,
	Flag = "ProgressCycleTargetLevel",
	Callback = function(value)
		state.progressCycleTargetLevel = value
	end,
})

ProgressionTab:CreateSlider({
	Name = "Cycle Delay",
	Range = {0.5, 10},
	Increment = 0.5,
	Suffix = "s",
	CurrentValue = state.progressCycleDelay,
	Flag = "ProgressCycleDelay",
	Callback = function(value)
		state.progressCycleDelay = value
	end,
})

UpgradesTab:CreateSection("Cubes")

UpgradesTab:CreateToggle({
	Name = "Auto Buy Best Cube",
	CurrentValue = false,
	Flag = "AutoBuyBestCube",
	Callback = function(value)
		state.autoBuyBestCube = value
		notify("Best Cube", value and "Enabled" or "Disabled")
	end,
})

UpgradesTab:CreateButton({
	Name = "Buy Best Cube",
	Callback = function()
		local success, cubeName = buyBestCube()
		notify("Best Cube", success and ("Selected " .. tostring(cubeName)) or "No affordable cube found.")
	end,
})

UpgradesTab:CreateSection("Rebirth")

UpgradesTab:CreateToggle({
	Name = "Auto Rebirth",
	CurrentValue = false,
	Flag = "AutoRebirth",
	Callback = function(value)
		state.autoRebirth = value
		notify("Auto Rebirth", value and "Enabled" or "Disabled")
	end,
})

UpgradesTab:CreateButton({
	Name = "Try Rebirth",
	Callback = function()
		notify("Rebirth", tryRebirth() and "Rebirth successful." or "Not ready to rebirth.")
	end,
})

RewardsTab:CreateSection("Playtime")

RewardsTab:CreateToggle({
	Name = "Auto Claim Playtime Rewards",
	CurrentValue = false,
	Flag = "AutoClaimPlaytime",
	Callback = function(value)
		state.autoClaimPlaytime = value
		notify("Playtime Rewards", value and "Enabled" or "Disabled")
	end,
})

RewardsTab:CreateButton({
	Name = "Claim Ready Rewards",
	Callback = function()
		local claimedCount = claimReadyPlaytimeRewards()
		notify("Playtime Rewards", claimedCount > 0 and ("Claimed " .. claimedCount .. " reward(s).") or "No rewards are ready.")
	end,
})

SettingsTab:CreateSection("Delays")

SettingsTab:CreateSlider({
	Name = "Best Table Delay",
	Range = {0.5, 10},
	Increment = 0.5,
	Suffix = "s",
	CurrentValue = state.bestTableDelay,
	Flag = "BestTableDelay",
	Callback = function(value)
		state.bestTableDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Auto Win Delay",
	Range = {0.5, 10},
	Increment = 0.5,
	Suffix = "s",
	CurrentValue = state.autoWinDelay,
	Flag = "AutoWinDelay",
	Callback = function(value)
		state.autoWinDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Cube Buy Delay",
	Range = {1, 15},
	Increment = 0.5,
	Suffix = "s",
	CurrentValue = state.autoBuyCubeDelay,
	Flag = "CubeBuyDelay",
	Callback = function(value)
		state.autoBuyCubeDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Auto Walk Turn Rate",
	Range = {0.02, 0.3},
	Increment = 0.005,
	CurrentValue = state.autoWalkTurnRate,
	Flag = "AutoWalkTurnRate",
	Callback = function(value)
		state.autoWalkTurnRate = value
	end,
})

Rayfield:LoadConfiguration()
notify("BaconHub", "+1 Shrink per Step loaded. Press K to toggle the UI.")
