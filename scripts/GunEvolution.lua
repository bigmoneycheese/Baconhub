local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local state = {
	autoClick = false,
	autoBuy = false,
	autoRebirth = false,
	autoWin = false,
	autoEggOpen = false,
	selectedEgg = "Normal Egg",
	selectedStage = 1,
	stageRequiredDamage = {},
	pendingRebirth = false,
	clickDelay = 0.01,
	autoWinRunId = 0,
}

local hasLoadedConfiguration = false

local Window = Rayfield:CreateWindow({
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "Gun Evolution",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "GunEvolution",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
	KeySettings = {
		Title = "BaconHub",
		Subtitle = "Key System",
		Note = "No key is required.",
		FileName = "BaconHubKey",
		SaveKey = true,
		GrabKeyFromSite = false,
		Key = {"BaconHub"},
	},
})

local MainTab = Window:CreateTab("Home", 0)
local FarmTab = Window:CreateTab("Farm", 0)
local EggsTab = Window:CreateTab("Eggs", 0)
local StagesTab = Window:CreateTab("Stages", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

local function notify(title, content)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 4,
		Image = 0,
	})
end

local function createParagraph(tab, data)
	local success, paragraph = pcall(function()
		return tab:CreateParagraph(data)
	end)

	if success and paragraph then
		return paragraph
	end

	return {
		Set = function() end,
	}
end

local function createDivider(tab)
	pcall(function()
		tab:CreateDivider()
	end)
end

local function getPowerEvent()
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GuiEvents"):WaitForChild("Power")
end

task.spawn(function()
	while true do
		if state.autoClick then
			getPowerEvent():FireServer()
			task.wait(state.clickDelay)
		else
			task.wait(0.15)
		end
	end
end)

local guns = {
	{name = "Pistol", wins = 1},
	{name = "Revolver", wins = 3},
	{name = "Shotgun", wins = 10},
	{name = "Suppressed Pistol", wins = 25},
	{name = "Ducky Gun", wins = 100},
	{name = "Toaster Launcher", wins = 500},
	{name = "Gusini Gun", wins = 2000},
	{name = "Raygun", wins = 7500},
	{name = "Submachine Gun", wins = 25000},
	{name = "Machine Pistol", wins = 200000},
	{name = "DB Shotgun", wins = 850000},
	{name = "Hammerhead Rifle", wins = 1800000},
	{name = "Assault Scar", wins = 5000000},
	{name = "Sharky Shooter", wins = 25000000},
	{name = "Sniper", wins = 150000000},
	{name = "Alien Railgun", wins = 500000000},
	{name = "Deathgun", wins = 1000000000},
	{name = "Cryo Gun", wins = 5000000000},
}

local boughtGuns = {}

local function checkWins()
	if not state.autoBuy then
		return
	end

	local gunEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("MainEvents"):WaitForChild("Gun")
	local winsValue = player:WaitForChild("PlayerData"):WaitForChild("Wins")
	local wins = winsValue.Value

	local bestAffordableGun

	for _, gun in ipairs(guns) do
		if wins >= gun.wins then
			bestAffordableGun = gun
			boughtGuns[gun.name] = true
		end
	end

	if bestAffordableGun and boughtGuns.currentBest ~= bestAffordableGun.name then
		boughtGuns.currentBest = bestAffordableGun.name
		gunEvent:FireServer(bestAffordableGun.name)
		print("Bought/equipped best affordable gun:", bestAffordableGun.name)
	end
end

task.spawn(function()
	local winsValue = player:WaitForChild("PlayerData"):WaitForChild("Wins")

	winsValue:GetPropertyChangedSignal("Value"):Connect(checkWins)
end)

local eggs = {
	{
		name = "Normal Egg",
		currencyName = "Wins",
		cost = 1000,
	},
	{
		name = "Cooler Egg",
		currencyName = "Wins",
		cost = 15000,
	},
	{
		name = "Wavey Egg",
		currencyName = "Wins",
		cost = 0,
	},
	{
		name = "Dino Egg",
		currencyName = "Wins",
		cost = 0,
	},
	{
		name = "Rainbow Egg",
		currencyName = "Wins",
		cost = 0,
	},
}

local eggNames = {}
local eggsByName = {}

for _, egg in ipairs(eggs) do
	table.insert(eggNames, egg.name)
	eggsByName[egg.name] = egg
end

local function openEgg(egg)
	local openEggEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GuiEvents"):WaitForChild("OpenEgg")
	local petEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GuiEvents"):WaitForChild("Pet")

	openEggEvent:FireServer(egg.name, {})

	for clickNumber = 1, 5 do
		local camera = workspace.CurrentCamera
		local viewportSize = camera and camera.ViewportSize or Vector2.new(800, 600)
		local clickPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)

		VirtualInputManager:SendMouseButtonEvent(clickPosition.X, clickPosition.Y, 0, true, game, 0)
		task.wait()
		VirtualInputManager:SendMouseButtonEvent(clickPosition.X, clickPosition.Y, 0, false, game, 0)

		if clickNumber < 5 then
			task.wait(0.5)
		end
	end

	petEvent:FireServer("Equip Best")
	print("Opened egg and equipped best pets:", egg.name)
end

task.spawn(function()
	while true do
		if state.autoEggOpen then
			local openedEgg = false
			local egg = eggsByName[state.selectedEgg] or eggs[1]
			local currencyValue = player:WaitForChild("PlayerData"):WaitForChild(egg.currencyName)

			if currencyValue and currencyValue.Value >= egg.cost then
				openEgg(egg)
				openedEgg = true
			end

			task.wait(openedEgg and 0.75 or 1)
		else
			task.wait(0.25)
		end
	end
end)

local function performRebirth()
	local rebirthEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GuiEvents"):WaitForChild("Rebirth")

	state.pendingRebirth = false
	rebirthEvent:FireServer(false)
	print("Rebirthed at spawn.")
end

local function checkRebirthLevel()
	if not state.autoRebirth then
		return
	end

	local leaderstats = player:WaitForChild("leaderstats")
	local levelValue = leaderstats:WaitForChild("Level")
	local playerData = player:WaitForChild("PlayerData")
	local rebirthValue = playerData:WaitForChild("Rebirth")
	local gameSettings = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Dictionaries"):WaitForChild("GameSettings"))

	local currentRebirth = rebirthValue.Value
	local currentLevel = levelValue.Value
	local neededLevel = gameSettings.Levels.GetRebirthCost(currentRebirth)

	print("Current level:", currentLevel)
	print("Current rebirth:", currentRebirth)
	print("You need to be Level " .. neededLevel .. " to rebirth again.")

	if currentLevel >= neededLevel then
		state.pendingRebirth = true
		print("Rebirth ready. Waiting until spawn.")
	end
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local levelValue = leaderstats:WaitForChild("Level")
	local playerData = player:WaitForChild("PlayerData")
	local rebirthValue = playerData:WaitForChild("Rebirth")

	checkRebirthLevel()
	levelValue.Changed:Connect(checkRebirthLevel)
	rebirthValue.Changed:Connect(checkRebirthLevel)
end)

local character
local humanoid
local rootPart
local hasStartedRun = false
local hasLeftReturnArea = false
local deathConnection
local deathHumanoid
local isRespawningFromAutoWinDeath = false
local originalWalkSpeed
local refreshCharacter
local restartAutoWinLoop

local defaultStageRequiredDamage = {
	[1] = 1,
	[2] = 1000,
	[3] = 5000,
	[4] = 10000,
	[5] = 50000,
	[6] = 100000,
	[7] = 250000,
	[8] = 750000,
	[9] = 5000000,
	[10] = 50000000,
	[11] = 250000000,
	[12] = 1000000000,
	[13] = 15000000000,
	[14] = 25000000000,
	[15] = 250000000000,
	[16] = 1000000000000,
	[17] = 2500000000000,
	[18] = 10000000000000,
	[19] = 50000000000000,
	[20] = 250000000000000,
	[21] = 0,
	[22] = 0,
}

local lastStage = 22

for stageNumber = 1, lastStage do
	state.stageRequiredDamage[stageNumber] = defaultStageRequiredDamage[stageNumber] or 0
end

local stageConfigFile = "BaconHubGunEvolutionStageDamage.json"
local stageOptions = {}

for stageNumber = 1, lastStage do
	table.insert(stageOptions, "Stage " .. stageNumber)
end

local function loadStageRequirements()
	if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(stageConfigFile) then
		return false
	end

	local success, savedRequirements = pcall(function()
		return HttpService:JSONDecode(readfile(stageConfigFile))
	end)

	if not success or type(savedRequirements) ~= "table" then
		return false
	end

	for stageNumber = 1, lastStage do
		local savedDamage = tonumber(savedRequirements[tostring(stageNumber)] or savedRequirements[stageNumber])

		if savedDamage then
			state.stageRequiredDamage[stageNumber] = savedDamage
		end
	end

	return true
end

local function saveStageRequirements()
	if type(writefile) ~= "function" then
		return false
	end

	local savedRequirements = {}

	for stageNumber = 1, lastStage do
		savedRequirements[tostring(stageNumber)] = state.stageRequiredDamage[stageNumber] or 0
	end

	local success = pcall(function()
		writefile(stageConfigFile, HttpService:JSONEncode(savedRequirements))
	end)

	return success
end

loadStageRequirements()

local returnPosition = Vector3.new(568, 3, 258)
local returnDistance = 20
local autoWinWalkSpeed = 50

local function setAutoWinSpeed()
	if not humanoid then
		return
	end

	if not originalWalkSpeed then
		originalWalkSpeed = humanoid.WalkSpeed
	end

	humanoid.WalkSpeed = autoWinWalkSpeed
end

local function restoreWalkSpeed()
	if humanoid and originalWalkSpeed then
		humanoid.WalkSpeed = originalWalkSpeed
	end

	originalWalkSpeed = nil
end

local function stopAutoWinMovement()
	state.autoWinRunId += 1
	hasStartedRun = false
	hasLeftReturnArea = false

	if humanoid and rootPart then
		humanoid:MoveTo(rootPart.Position)
	end

	restoreWalkSpeed()
end

restartAutoWinLoop = function()
	state.autoWinRunId += 1
	hasStartedRun = false
	hasLeftReturnArea = false

	if humanoid and rootPart then
		setAutoWinSpeed()
		humanoid:MoveTo(rootPart.Position)
	end

	print("Restarting from Stage 1...")
end

local function bindDeathDetector()
	if humanoid == deathHumanoid then
		return
	end

	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end

	deathHumanoid = humanoid
	deathConnection = humanoid.Died:Connect(function()
		if not state.autoWin then
			return
		end

		print("Detected death during Auto Win. Waiting for respawn.")
		isRespawningFromAutoWinDeath = true
		restoreWalkSpeed()
		restartAutoWinLoop()

		task.spawn(function()
			player.CharacterAdded:Wait()
			task.wait(1)
			refreshCharacter()
			isRespawningFromAutoWinDeath = false
			restartAutoWinLoop()
		end)
	end)
end

refreshCharacter = function()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	bindDeathDetector()

	if state.autoWin then
		setAutoWinSpeed()
	end
end

player.CharacterAdded:Connect(function()
	task.wait(1)
	refreshCharacter()
	isRespawningFromAutoWinDeath = false
end)

task.spawn(function()
	refreshCharacter()

	while true do
		task.wait(0.25)

		if state.autoWin and not isRespawningFromAutoWinDeath then
			refreshCharacter()

			local distanceFromReturn = (rootPart.Position - returnPosition).Magnitude

			if hasStartedRun and distanceFromReturn > returnDistance then
				hasLeftReturnArea = true
			end

			if hasStartedRun and hasLeftReturnArea and distanceFromReturn <= returnDistance then
				print("Detected return position. Restarting loop.")

				if state.autoRebirth and state.pendingRebirth then
					performRebirth()
					task.wait(1)
				end

				restartAutoWinLoop()
			end
		end
	end
end)

local function parseNumber(text)
	text = string.upper(text):gsub(",", "")

	local numberText, suffix = text:match("([%d%.]+)%s*([KMBT]?)")
	local number = tonumber(numberText) or 0

	if suffix == "K" then
		number *= 1000
	elseif suffix == "M" then
		number *= 1000000
	elseif suffix == "B" then
		number *= 1000000000
	elseif suffix == "T" then
		number *= 1000000000000
	end

	return number
end

local function setStageRequirement(stageNumber, value)
	local damage = parseNumber(tostring(value or ""))

	state.stageRequiredDamage[stageNumber] = damage
	print("Stage " .. stageNumber .. " damage requirement set to:", damage)
end

local function formatDamage(value)
	value = tonumber(value) or 0

	if value >= 1000000000000 then
		return string.format("%.2fT", value / 1000000000000):gsub("%.00", "")
	elseif value >= 1000000000 then
		return string.format("%.2fB", value / 1000000000):gsub("%.00", "")
	elseif value >= 1000000 then
		return string.format("%.2fM", value / 1000000):gsub("%.00", "")
	elseif value >= 1000 then
		return string.format("%.2fK", value / 1000):gsub("%.00", "")
	end

	return tostring(value)
end

local function getStageRequirementSummary()
	local lines = {}

	for stageNumber = 1, lastStage do
		table.insert(lines, "S" .. stageNumber .. ": " .. formatDamage(state.stageRequiredDamage[stageNumber]))
	end

	return table.concat(lines, " | ")
end

local function getAutomationSummary()
	return table.concat({
		"Click: " .. (state.autoClick and "On" or "Off"),
		"Guns: " .. (state.autoBuy and "On" or "Off"),
		"Rebirth: " .. (state.autoRebirth and "On" or "Off"),
		"Auto Win: " .. (state.autoWin and "On" or "Off"),
		"Eggs: " .. (state.autoEggOpen and "On" or "Off"),
		"Egg: " .. state.selectedEgg,
	}, " | ")
end

local automationSummary

local function updateAutomationSummary()
	if automationSummary then
		automationSummary:Set({
			Title = "Automation Status",
			Content = getAutomationSummary(),
		})
	end
end

local function getDamage()
	local damageLabel = player
		:WaitForChild("PlayerGui")
		:WaitForChild("Main")
		:WaitForChild("Holder")
		:WaitForChild("PowerBar")
		:WaitForChild("Damage")

	return parseNumber(damageLabel.Text)
end

local function canEnterStage(stageNumber)
	local requiredDamage = state.stageRequiredDamage[stageNumber]

	if requiredDamage == nil then
		return false
	end

	return getDamage() >= requiredDamage
end

local function getStage(stageNumber)
	return workspace
		:WaitForChild("MainMap")
		:WaitForChild("Stage Assets")
		:WaitForChild(tostring(stageNumber))
end

local function getTargetPosition(target)
	if target:IsA("BasePart") then
		return target.Position
	end

	if target:IsA("Model") then
		local part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	if target:IsA("Folder") then
		local part = target:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	error(target.Name .. " has no BasePart to pathfind to.")
end

local function tryPathfindToPosition(targetPosition, targetName, thisRunId)
	refreshCharacter()

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
	})

	path:ComputeAsync(rootPart.Position, targetPosition)

	if thisRunId ~= state.autoWinRunId or not state.autoWin then
		return false
	end

	if path.Status ~= Enum.PathStatus.Success then
		warn(targetName .. " is blocked. Waiting...")
		return false
	end

	for _, waypoint in ipairs(path:GetWaypoints()) do
		if thisRunId ~= state.autoWinRunId or not state.autoWin then
			return false
		end

		refreshCharacter()
		setAutoWinSpeed()

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		humanoid:MoveTo(waypoint.Position)

		local reached = humanoid.MoveToFinished:Wait()

		if thisRunId ~= state.autoWinRunId or not state.autoWin then
			return false
		end

		if not reached then
			warn("Path got blocked while going to:", targetName)
			return false
		end
	end

	return true
end

local function waitUntilPathfindToPosition(targetPosition, targetName, thisRunId)
	while thisRunId == state.autoWinRunId and state.autoWin do
		local success = tryPathfindToPosition(targetPosition, targetName, thisRunId)

		if success then
			return true
		end

		task.wait(1)
	end

	return false
end

local function waitUntilPathfindTo(target, thisRunId)
	return waitUntilPathfindToPosition(getTargetPosition(target), target.Name, thisRunId)
end

local function goTenStudsPastStart(stageNumber, thisRunId)
	local stage = getStage(stageNumber)
	local start = stage:WaitForChild("Start")
	local safeZone = stage:WaitForChild("SafeZone")

	local startPosition = getTargetPosition(start)
	local safeZonePosition = getTargetPosition(safeZone)
	local direction = safeZonePosition - startPosition

	if direction.Magnitude == 0 then
		return waitUntilPathfindTo(start, thisRunId)
	end

	local tenStudsPastStart = startPosition + direction.Unit * 10

	print("Going 10 studs past Stage " .. stageNumber .. " Start")
	return waitUntilPathfindToPosition(tenStudsPastStart, "10 studs past Stage " .. stageNumber .. " Start", thisRunId)
end

local function goToWinsButton(stageNumber, thisRunId)
	local stage = getStage(stageNumber)
	local safeZone = stage:WaitForChild("SafeZone")
	local winsButton = safeZone:WaitForChild("Wins Button")

	print("Going to Stage " .. stageNumber .. " SafeZone")
	if not waitUntilPathfindTo(safeZone, thisRunId) then
		return false
	end

	print("Going to Stage " .. stageNumber .. " Wins Button")
	return waitUntilPathfindTo(winsButton, thisRunId)
end

task.spawn(function()
	while true do
		if state.autoWin and not isRespawningFromAutoWinDeath then
			local thisRunId = state.autoWinRunId
			local currentStage = 1

			while thisRunId == state.autoWinRunId and state.autoWin do
				if canEnterStage(currentStage) then
					hasStartedRun = true

					print("Can enter Stage " .. currentStage)
					if not goTenStudsPastStart(currentStage, thisRunId) then
						break
					end

					local nextStage = currentStage + 1

					if nextStage <= lastStage and canEnterStage(nextStage) then
						currentStage = nextStage
					else
						print("Cannot enter next stage. Going to Stage " .. currentStage .. " Wins Button")
						goToWinsButton(currentStage, thisRunId)
						break
					end
				else
					print("Cannot enter Stage " .. currentStage .. ". Waiting for more damage...")
					task.wait(3)
				end
			end

			while state.autoWin and state.pendingRebirth do
				refreshCharacter()

				local distanceFromReturn = (rootPart.Position - returnPosition).Magnitude
				if distanceFromReturn <= returnDistance then
					if state.autoRebirth then
						performRebirth()
						task.wait(1)
					end

					restartAutoWinLoop()
					break
				end

				print("Waiting to return to spawn before rebirthing...")
				task.wait(0.5)
			end

			task.wait(0.25)
		else
			task.wait(0.25)
		end
	end
end)

local stageSummary
local stageDamageInput

local function updateStageEditor()
	if stageDamageInput then
		stageDamageInput:Set(tostring(state.stageRequiredDamage[state.selectedStage] or 0))
	end

	if stageSummary then
		stageSummary:Set({
			Title = "Current Stage Damage",
			Content = getStageRequirementSummary(),
		})
	end
end

MainTab:CreateSection("Overview")

automationSummary = createParagraph(MainTab, {
	Title = "Automation Status",
	Content = getAutomationSummary(),
})

createDivider(MainTab)
MainTab:CreateSection("Quick Actions")

MainTab:CreateButton({
	Name = "Stop Current Path",
	Callback = function()
		stopAutoWinMovement()
		notify("Movement", "Stopped current Auto Win path.")
	end,
})

FarmTab:CreateSection("Core Farming")

FarmTab:CreateToggle({
	Name = "Auto Click",
	CurrentValue = false,
	Flag = "AutoClick",
	Callback = function(value)
		state.autoClick = value
		updateAutomationSummary()
		notify("Auto Click", value and "Enabled" or "Disabled")
	end,
})

FarmTab:CreateSlider({
	Name = "Click Delay",
	Range = {0.01, 1},
	Increment = 0.01,
	Suffix = "s",
	CurrentValue = 0.01,
	Flag = "ClickDelay",
	Callback = function(value)
		state.clickDelay = value
	end,
})

FarmTab:CreateToggle({
	Name = "Auto Buy Best Gun",
	CurrentValue = false,
	Flag = "AutoBuyGuns",
	Callback = function(value)
		state.autoBuy = value
		if value and hasLoadedConfiguration then
			checkWins()
		end
		updateAutomationSummary()
		notify("Auto Buy Guns", value and "Enabled" or "Disabled")
	end,
})

createDivider(FarmTab)
FarmTab:CreateSection("Runs")

FarmTab:CreateToggle({
	Name = "Auto Win",
	CurrentValue = false,
	Flag = "AutoWin",
	Callback = function(value)
		state.autoWin = value

		if value then
			restartAutoWinLoop()
		else
			stopAutoWinMovement()
		end

		updateAutomationSummary()
		notify("Auto Win", value and "Enabled" or "Disabled")
	end,
})

FarmTab:CreateToggle({
	Name = "Auto Rebirth",
	CurrentValue = false,
	Flag = "AutoRebirth",
	Callback = function(value)
		state.autoRebirth = value
		if value then
			checkRebirthLevel()
		else
			state.pendingRebirth = false
		end
		updateAutomationSummary()
		notify("Auto Rebirth", value and "Enabled" or "Disabled")
	end,
})

EggsTab:CreateSection("Egg Opening")

EggsTab:CreateDropdown({
	Name = "Egg",
	Options = eggNames,
	CurrentOption = {"Normal Egg"},
	MultipleOptions = false,
	Flag = "SelectedEgg",
	Callback = function(option)
		local selected = typeof(option) == "table" and option[1] or option
		state.selectedEgg = selected or "Normal Egg"
		updateAutomationSummary()
	end,
})

EggsTab:CreateToggle({
	Name = "Auto Open Selected Egg",
	CurrentValue = false,
	Flag = "AutoOpenEgg",
	Callback = function(value)
		state.autoEggOpen = value
		updateAutomationSummary()
		notify("Auto Egg Open", value and "Enabled" or "Disabled")
	end,
})

StagesTab:CreateSection("Editor")

StagesTab:CreateDropdown({
	Name = "Stage",
	Options = stageOptions,
	CurrentOption = {"Stage 1"},
	MultipleOptions = false,
	Flag = "SelectedStage",
	Callback = function(option)
		local selected = typeof(option) == "table" and option[1] or option
		local stageNumber = tonumber(tostring(selected or ""):match("%d+"))

		if stageNumber then
			state.selectedStage = math.clamp(stageNumber, 1, lastStage)
			updateStageEditor()
		end
	end,
})

stageDamageInput = StagesTab:CreateInput({
	Name = "Required Damage",
	CurrentValue = tostring(state.stageRequiredDamage[state.selectedStage] or 0),
	PlaceholderText = "Example: 5000000, 2.5B, 750K",
	RemoveTextAfterFocusLost = false,
	Callback = function(value)
		setStageRequirement(state.selectedStage, value)

		if stageSummary then
			stageSummary:Set({
				Title = "Current Stage Damage",
				Content = getStageRequirementSummary(),
			})
		end
	end,
})

createDivider(StagesTab)
StagesTab:CreateSection("Presets")

StagesTab:CreateButton({
	Name = "Save Stage Damage",
	Callback = function()
		local didSave = saveStageRequirements()
		notify("Stage Damage", didSave and "Saved stage damage settings." or "Could not save stage damage in this executor.")
	end,
})

StagesTab:CreateButton({
	Name = "Reset Selected Stage",
	Callback = function()
		state.stageRequiredDamage[state.selectedStage] = defaultStageRequiredDamage[state.selectedStage] or 0
		updateStageEditor()
		notify("Stage Damage", "Reset Stage " .. state.selectedStage .. ".")
	end,
})

StagesTab:CreateButton({
	Name = "Reset All Stages",
	Callback = function()
		for stageNumber = 1, lastStage do
			state.stageRequiredDamage[stageNumber] = defaultStageRequiredDamage[stageNumber] or 0
		end

		updateStageEditor()
		notify("Stage Damage", "Reset all stage damage settings.")
	end,
})

stageSummary = createParagraph(StagesTab, {
	Title = "Current Stage Damage",
	Content = getStageRequirementSummary(),
})

SettingsTab:CreateSection("Maintenance")

SettingsTab:CreateButton({
	Name = "Reset Bought Gun Cache",
	Callback = function()
		table.clear(boughtGuns)
		checkWins()
		notify("Gun Cache", "Reset bought gun cache.")
	end,
})

SettingsTab:CreateButton({
	Name = "Stop Current Path",
	Callback = function()
		stopAutoWinMovement()
		notify("Movement", "Stopped current Auto Win path.")
	end,
})

Rayfield:LoadConfiguration()
hasLoadedConfiguration = true
updateAutomationSummary()
updateStageEditor()

notify("BaconHub", "Gun Evolution loaded. Press K to toggle the GUI.")
