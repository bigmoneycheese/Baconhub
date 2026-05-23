local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

local state = {
	autoClick = false,
	autoBuy = false,
	autoRebirth = false,
	autoWin = false,
	autoWinPausedForMultiplier = false,
	autoBestMultiplier = false,
	autoEggOpen = false,
	autoEquipBestPets = false,
	autoDeletePets = false,
	selectedDeleteRarities = {},
	selectedEgg = "Normal Egg",
	selectedStage = 1,
	stageRequiredDamage = {},
	pendingRebirth = false,
	clickDelay = 0.01,
	multiplierUntilLevel = 50,
	multiplierTeleportDelay = 1,
	multiplierStartGun = "Any Gun",
	waitingForMultiplierGun = false,
	eggOpenRunId = 0,
	autoWinRunId = 0,
	autoRejoin = false,
	antiAfk = false,
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

local autoRejoinRunning = false

GuiService.ErrorMessageChanged:Connect(function()
	if not state.autoRejoin or autoRejoinRunning then
		return
	end

	local errorCode = GuiService:GetErrorCode()
	local errorType = GuiService:GetErrorType()
	if errorType == Enum.ConnectionError.DisconnectErrors and not reconnectDisabledList[errorCode] then
		autoRejoinRunning = true
		print("Disconnect registered!")
		while state.autoRejoin and task.wait(5) do
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end
	end
end)

player.Idled:Connect(function()
	if not state.antiAfk then
		return
	end

	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

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

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local guiEvents = remoteEvents:WaitForChild("GuiEvents")
local mainEvents = remoteEvents:WaitForChild("MainEvents")
local modules = ReplicatedStorage:WaitForChild("Modules")
local classes = modules:WaitForChild("Classes")
local dictionaries = modules:WaitForChild("Dictionaries")
local gunModule = require(classes:WaitForChild("Gun"))
local gameSettings = require(dictionaries:WaitForChild("GameSettings"))
local petsDictionary = require(dictionaries:WaitForChild("Pets"))
local powerEvent = guiEvents:WaitForChild("Power")
local gunEvent = mainEvents:WaitForChild("Gun")
local openEggEvent = guiEvents:WaitForChild("OpenEgg")
local petEvent = guiEvents:WaitForChild("Pet")
local rebirthEvent = guiEvents:WaitForChild("Rebirth")
local multiplierStartGunOptions = {"Any Gun"}
local gunOptionRows = {}

for gunName, gunInfo in pairs(gunModule.Guns or {}) do
	if not gunInfo.ProductId then
		table.insert(gunOptionRows, {
			name = gunName,
			wins = tonumber(gunInfo.Wins) or 0,
			gain = tonumber(gunInfo.Gain) or 0,
		})
	end
end

table.sort(gunOptionRows, function(left, right)
	if left.wins == right.wins then
		return left.gain < right.gain
	end

	return left.wins < right.wins
end)

for _, row in ipairs(gunOptionRows) do
	table.insert(multiplierStartGunOptions, row.name)
end

local function getPowerEvent()
	return powerEvent
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

local lastGunEquipRequest = 0

local function checkWins()
	if not state.autoBuy then
		return
	end

	local equippedGun = player:WaitForChild("PlayerData"):WaitForChild("EquippedGun")
	local equipableGuns = gunModule.GetEquipableGuns(player)
	local bestGun = equipableGuns and equipableGuns[1]

	if not bestGun or not bestGun[1] or equippedGun.Value == bestGun[1] then
		return
	end

	if os.clock() - lastGunEquipRequest < 0.5 then
		return
	end

	lastGunEquipRequest = os.clock()
	gunEvent:FireServer(bestGun[1])
	print("Equipped best available gun:", bestGun[1])
end

local function getGunWins(gunName)
	local gunInfo = gunModule.Guns and gunModule.Guns[gunName]

	return gunInfo and tonumber(gunInfo.Wins) or 0
end

local function getBestCurrentGunName()
	local playerData = player:FindFirstChild("PlayerData")
	local equippedGun = playerData and playerData:FindFirstChild("EquippedGun")

	return equippedGun and equippedGun.Value
end

local function hasMultiplierStartGun()
	if state.multiplierStartGun == "Any Gun" then
		return true
	end

	return getGunWins(getBestCurrentGunName()) >= getGunWins(state.multiplierStartGun)
end

task.spawn(function()
	local winsValue = player:WaitForChild("PlayerData"):WaitForChild("Wins")
	local equippedGun = player:WaitForChild("PlayerData"):WaitForChild("EquippedGun")

	winsValue:GetPropertyChangedSignal("Value"):Connect(checkWins)
	equippedGun:GetPropertyChangedSignal("Value"):Connect(checkWins)
end)

local eggs = {}
local eggNames = {}
local eggsByName = {}
local petRarityByName = {}
local rarityOptions = {}
local raritySeen = {}

for eggName, cost in pairs(petsDictionary.EggCosts or {}) do
	if type(cost) == "number" then
		table.insert(eggs, {
			name = eggName,
			currencyName = "Wins",
			cost = cost,
		})
	end
end

for _, pets in pairs(petsDictionary.Dictionaries or {}) do
	for petName, petInfo in pairs(pets) do
		local rarity = petInfo.Rarity

		if rarity then
			petRarityByName[petInfo.Name or petName] = rarity

			if not raritySeen[rarity] then
				raritySeen[rarity] = true
				table.insert(rarityOptions, rarity)
			end
		end
	end
end

table.sort(eggs, function(left, right)
	if left.cost == right.cost then
		return left.name < right.name
	end

	return left.cost < right.cost
end)

table.sort(rarityOptions, function(left, right)
	local rarityOrder = {
		Common = 1,
		Uncommon = 2,
		Rare = 3,
		Epic = 4,
		Legendary = 5,
	}

	return (rarityOrder[left] or 99) < (rarityOrder[right] or 99)
end)

for _, egg in ipairs(eggs) do
	table.insert(eggNames, egg.name)
	eggsByName[egg.name] = egg
end

local function openEgg(egg)
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

	print("Opened egg:", egg.name)
end

local lastPetEquipRequest = 0
local eggWakeEvent = Instance.new("BindableEvent")

local function equipBestPets()
	if os.clock() - lastPetEquipRequest < 0.75 then
		return
	end

	lastPetEquipRequest = os.clock()
	petEvent:FireServer("Equip Best")
	print("Equipped best pets.")
end

local lastPetDeleteRequest = 0

local function getSelectedDeleteRaritySet()
	local selected = {}

	for _, rarity in ipairs(state.selectedDeleteRarities or {}) do
		selected[rarity] = true
	end

	return selected
end

local function getPetRarity(petValue)
	return petRarityByName[petValue.Name]
end

local function deleteSelectedRarityPets()
	local selectedRarities = getSelectedDeleteRaritySet()
	local petsFolder = player:WaitForChild("PlayerData"):WaitForChild("Pets")
	local petsToDelete = {}

	for _, petValue in ipairs(petsFolder:GetChildren()) do
		local rarity = getPetRarity(petValue)

		if rarity and selectedRarities[rarity] and petValue.Value == false then
			table.insert(petsToDelete, petValue.Name)
		end
	end

	if #petsToDelete == 0 then
		return 0
	end

	if os.clock() - lastPetDeleteRequest < 0.5 then
		return 0
	end

	lastPetDeleteRequest = os.clock()
	petEvent:FireServer("Delete", petsToDelete)
	print("Deleted selected rarity pets:", table.concat(petsToDelete, ", "))
	return #petsToDelete
end

local function checkAutoDeletePet(petValue)
	if not state.autoDeletePets then
		return false
	end

	local selectedRarities = getSelectedDeleteRaritySet()
	local rarity = getPetRarity(petValue)

	if rarity and selectedRarities[rarity] and petValue.Value == false then
		deleteSelectedRarityPets()
		return true
	end

	return false
end

local function waitForEggCurrency(currencyValue, cost, runId)
	while state.autoEggOpen and runId == state.eggOpenRunId and currencyValue.Value < cost do
		local wake = Instance.new("BindableEvent")
		local currencyConnection = currencyValue:GetPropertyChangedSignal("Value"):Connect(function()
			wake:Fire()
		end)
		local controlConnection = eggWakeEvent.Event:Connect(function()
			wake:Fire()
		end)

		if currencyValue.Value < cost then
			wake.Event:Wait()
		end

		currencyConnection:Disconnect()
		controlConnection:Disconnect()
		wake:Destroy()
	end

	return state.autoEggOpen and runId == state.eggOpenRunId and currencyValue.Value >= cost
end

task.spawn(function()
	while true do
		if state.autoEggOpen then
			local thisRunId = state.eggOpenRunId
			local openedEgg = false
			local egg = eggsByName[state.selectedEgg] or eggs[1]
			local currencyValue = player:WaitForChild("PlayerData"):WaitForChild(egg.currencyName)

			if waitForEggCurrency(currencyValue, egg.cost, thisRunId) then
				openEgg(egg)
				openedEgg = true
				if state.autoEquipBestPets then
					equipBestPets()
				end
			end

			task.wait(openedEgg and 0.75 or 0.15)
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	local petsFolder = player:WaitForChild("PlayerData"):WaitForChild("Pets")

	petsFolder.ChildAdded:Connect(function(petValue)
		task.wait(0.1)

		local didQueueDelete = checkAutoDeletePet(petValue)

		if state.autoEquipBestPets then
			if didQueueDelete then
				task.wait(0.6)
			end

			equipBestPets()
		end
	end)
end)

local lastRebirthAttempt = 0

local function isRebirthReady()
	local leaderstats = player:WaitForChild("leaderstats")
	local levelValue = leaderstats:WaitForChild("Level")
	local playerData = player:WaitForChild("PlayerData")
	local rebirthValue = playerData:WaitForChild("Rebirth")
	local neededLevel = gameSettings.Levels.GetRebirthCost(rebirthValue.Value)

	return levelValue.Value >= neededLevel, levelValue.Value, rebirthValue.Value, neededLevel
end

local function performRebirth()
	local ready = isRebirthReady()

	if not ready or os.clock() - lastRebirthAttempt < 1.5 then
		return false
	end

	lastRebirthAttempt = os.clock()
	state.pendingRebirth = false
	rebirthEvent:FireServer(false)
	print("Rebirthed at spawn.")
	return true
end

local lastRebirthStatusKey

local function checkRebirthLevel()
	if not state.autoRebirth then
		state.pendingRebirth = false
		return
	end

	local ready, currentLevel, currentRebirth, neededLevel = isRebirthReady()
	local statusKey = currentRebirth .. ":" .. neededLevel .. ":" .. tostring(ready)

	if statusKey ~= lastRebirthStatusKey then
		lastRebirthStatusKey = statusKey
		print("Rebirth progress:", currentLevel .. "/" .. neededLevel, "Current rebirth:", currentRebirth)
	end

	if ready then
		state.pendingRebirth = true
		if not state.autoWin then
			performRebirth()
		end
	else
		state.pendingRebirth = false
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

local fallbackStageRequiredDamage = {
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
local defaultStageRequiredDamage = {}

local function getEnemyDefinitions()
	local success, enemyModule = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Classes"):WaitForChild("Enemy"))
	end)

	if success and enemyModule and enemyModule.Enemies then
		return enemyModule.Enemies
	end

	return {}
end

local function calculateStageRequiredDamage(stageNumber, enemyDefinitions)
	local stageSpawners = workspace
		:WaitForChild("MainMap")
		:WaitForChild("Stage Spawners")
		:FindFirstChild(tostring(stageNumber))

	if not stageSpawners then
		return nil
	end

	local bestEnemyHealth = 0
	local bestBossHealth = 0

	for _, spawner in ipairs(stageSpawners:GetChildren()) do
		if spawner:IsA("BasePart") then
			local enemyInfo = enemyDefinitions[spawner.Name]

			if enemyInfo and tonumber(enemyInfo.Health) then
				local health = tonumber(enemyInfo.Health)

				if string.find(string.lower(spawner.Name), "boss") then
					bestBossHealth = math.max(bestBossHealth, health)
				else
					bestEnemyHealth = math.max(bestEnemyHealth, health)
				end
			end
		end
	end

	if bestBossHealth > 0 then
		return math.ceil(bestBossHealth / 4)
	end

	if bestEnemyHealth > 0 then
		return math.ceil(bestEnemyHealth / 2)
	end

	return nil
end

local function buildDefaultStageRequiredDamage()
	local enemyDefinitions = getEnemyDefinitions()

	for stageNumber = 1, lastStage do
		defaultStageRequiredDamage[stageNumber] = calculateStageRequiredDamage(stageNumber, enemyDefinitions)
			or fallbackStageRequiredDamage[stageNumber]
			or 0
	end
end

buildDefaultStageRequiredDamage()

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
		if not state.autoWin or state.autoWinPausedForMultiplier then
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
			if state.autoWin and not state.autoWinPausedForMultiplier then
				restartAutoWinLoop()
			end
		end)
	end)
end

refreshCharacter = function()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	bindDeathDetector()

	if state.autoWin and not state.autoWinPausedForMultiplier then
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

		if state.autoWin and not state.autoWinPausedForMultiplier and not isRespawningFromAutoWinDeath then
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

local automationSummary
local updateAutomationSummary

local function getAutomationSummary()
	local autoWinStatus = state.autoWin and "On" or "Off"

	if state.autoWin and state.autoWinPausedForMultiplier then
		autoWinStatus = "Paused"
	end

	return table.concat({
		"Click: " .. (state.autoClick and "On" or "Off"),
		"Guns: " .. (state.autoBuy and "On" or "Off"),
		"Multiplier: " .. (state.autoBestMultiplier and "On" or "Off"),
		"Rebirth: " .. (state.autoRebirth and "On" or "Off"),
		"Auto Win: " .. autoWinStatus,
		"Eggs: " .. (state.autoEggOpen and "On" or "Off"),
		"Pets: " .. (state.autoEquipBestPets and "On" or "Off"),
		"Delete Pets: " .. (state.autoDeletePets and "On" or "Off"),
		"Egg: " .. state.selectedEgg,
	}, " | ")
end

updateAutomationSummary = function()
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

local function getLevel()
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")

	return levelValue and tonumber(levelValue.Value) or 0
end

local function shouldTrainAtMultiplier()
	return state.autoBestMultiplier and getLevel() < state.multiplierUntilLevel and hasMultiplierStartGun()
end

local function shouldGetGunBeforeMultiplier()
	return state.autoBestMultiplier and getLevel() < state.multiplierUntilLevel and not hasMultiplierStartGun()
end

local function getRebirths()
	local playerData = player:FindFirstChild("PlayerData")
	local rebirthValue = playerData and playerData:FindFirstChild("Rebirth")

	return rebirthValue and tonumber(rebirthValue.Value) or 0
end

local function getTextLabelText(parent, name)
	local label = parent:FindFirstChild(name, true)

	if label and label:IsA("TextLabel") then
		return label.Text
	end

	return ""
end

local function getBestMultiplierZone()
	local targetZones = workspace:WaitForChild("MainMap"):WaitForChild("TargetZones")
	local currentRebirths = getRebirths()
	local bestZone

	for _, zone in ipairs(targetZones:GetChildren()) do
		local middle = zone:FindFirstChild("Middle")

		if middle and middle:IsA("BasePart") then
			local costText = getTextLabelText(middle, "Cost")
			local rebirthText = getTextLabelText(middle, "Rebirths")
			local multiplierText = getTextLabelText(middle, "Multi")
			local requiredRebirths = parseNumber(rebirthText)
			local multiplier = parseNumber(multiplierText)

			if multiplier > 0 and currentRebirths >= requiredRebirths and costText == "" then
				if not bestZone or multiplier > bestZone.multiplier then
					bestZone = {
						part = middle,
						multiplier = multiplier,
						requiredRebirths = requiredRebirths,
					}
				end
			end
		end
	end

	return bestZone
end

local function teleportToBestMultiplier()
	refreshCharacter()

	local bestZone = getBestMultiplierZone()

	if not bestZone or not rootPart then
		return false
	end

	if (rootPart.Position - bestZone.part.Position).Magnitude <= 5 then
		return true, bestZone
	end

	rootPart.CFrame = CFrame.new(bestZone.part.Position + Vector3.new(0, 3, 0))
	return true, bestZone
end

task.spawn(function()
	while true do
		if state.autoBestMultiplier then
			if shouldTrainAtMultiplier() then
				state.waitingForMultiplierGun = false

				if not state.autoWinPausedForMultiplier then
					state.autoWinPausedForMultiplier = true
					stopAutoWinMovement()
					if updateAutomationSummary then
						updateAutomationSummary()
					end
				end

				teleportToBestMultiplier()
				task.wait(state.multiplierTeleportDelay)
			elseif shouldGetGunBeforeMultiplier() then
				if not state.waitingForMultiplierGun then
					state.waitingForMultiplierGun = true
					state.autoWinPausedForMultiplier = false
					state.autoWin = true
					checkWins()

					if updateAutomationSummary then
						updateAutomationSummary()
					end

					restartAutoWinLoop()
					notify("Auto Win", "Getting " .. state.multiplierStartGun .. " before multiplier training.")
				end

				task.wait(0.5)
			else
				state.waitingForMultiplierGun = false

				if state.autoWinPausedForMultiplier then
					state.autoWinPausedForMultiplier = false
					state.autoWin = true
					if updateAutomationSummary then
						updateAutomationSummary()
					end

					restartAutoWinLoop()
					notify("Auto Win", "Level target reached. Starting Auto Win.")
				end

				task.wait(0.5)
			end
		else
			state.waitingForMultiplierGun = false

			if state.autoWinPausedForMultiplier then
				state.autoWinPausedForMultiplier = false
				if updateAutomationSummary then
					updateAutomationSummary()
				end

				if state.autoWin then
					restartAutoWinLoop()
				end
			end

			task.wait(0.25)
		end
	end
end)

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

	if thisRunId ~= state.autoWinRunId or not state.autoWin or state.autoWinPausedForMultiplier then
		return false
	end

	if path.Status ~= Enum.PathStatus.Success then
		warn(targetName .. " is blocked. Waiting...")
		return false
	end

	for _, waypoint in ipairs(path:GetWaypoints()) do
		if thisRunId ~= state.autoWinRunId or not state.autoWin or state.autoWinPausedForMultiplier then
			return false
		end

		refreshCharacter()
		setAutoWinSpeed()

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		humanoid:MoveTo(waypoint.Position)

		local reached = humanoid.MoveToFinished:Wait()

		if thisRunId ~= state.autoWinRunId or not state.autoWin or state.autoWinPausedForMultiplier then
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
	while thisRunId == state.autoWinRunId and state.autoWin and not state.autoWinPausedForMultiplier do
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
		if state.autoWin and not state.autoWinPausedForMultiplier and not isRespawningFromAutoWinDeath then
			local thisRunId = state.autoWinRunId
			local currentStage = 1

			while thisRunId == state.autoWinRunId and state.autoWin and not state.autoWinPausedForMultiplier do
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

			while state.autoWin and not state.autoWinPausedForMultiplier and state.pendingRebirth do
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
FarmTab:CreateSection("Power Multiplier")

FarmTab:CreateToggle({
	Name = "Auto Best Multiplier Until Level",
	CurrentValue = false,
	Flag = "AutoBestMultiplier",
	Callback = function(value)
		state.autoBestMultiplier = value
		if value and hasLoadedConfiguration then
			local isTraining = shouldTrainAtMultiplier()
			local needsGun = shouldGetGunBeforeMultiplier()

			if isTraining then
				state.waitingForMultiplierGun = false
				state.autoWinPausedForMultiplier = true
				stopAutoWinMovement()
			elseif needsGun then
				state.waitingForMultiplierGun = true
				state.autoWinPausedForMultiplier = false
				state.autoWin = true
				checkWins()
				restartAutoWinLoop()
				notify("Auto Win", "Getting " .. state.multiplierStartGun .. " before multiplier training.")
			else
				state.waitingForMultiplierGun = false
				state.autoWinPausedForMultiplier = false
				state.autoWin = true
				restartAutoWinLoop()
			end

			local success, bestZone = false, nil
			if isTraining then
				success, bestZone = teleportToBestMultiplier()
			end

			if isTraining and success and bestZone then
				notify("Best Multiplier", "Using " .. formatDamage(bestZone.multiplier) .. "x until Level " .. state.multiplierUntilLevel .. ".")
			elseif not needsGun then
				notify("Auto Win", "Level target already reached. Starting Auto Win.")
			end
		elseif not value and state.autoWinPausedForMultiplier then
			state.waitingForMultiplierGun = false
			state.autoWinPausedForMultiplier = false
			if state.autoWin then
				restartAutoWinLoop()
			end
		elseif not value then
			state.waitingForMultiplierGun = false
		end
		updateAutomationSummary()
		notify("Auto Best Multiplier", value and "Enabled" or "Disabled")
	end,
})

FarmTab:CreateDropdown({
	Name = "Start Multiplier After Gun",
	Options = multiplierStartGunOptions,
	CurrentOption = {"Any Gun"},
	MultipleOptions = false,
	Flag = "MultiplierStartGun",
	Callback = function(option)
		local selected = typeof(option) == "table" and option[1] or option
		state.multiplierStartGun = selected or "Any Gun"

		if state.autoBestMultiplier and hasLoadedConfiguration then
			state.waitingForMultiplierGun = false

			if shouldTrainAtMultiplier() then
				state.autoWinPausedForMultiplier = true
				stopAutoWinMovement()
				teleportToBestMultiplier()
			elseif shouldGetGunBeforeMultiplier() then
				state.autoWinPausedForMultiplier = false
				state.autoWin = true
				checkWins()
				restartAutoWinLoop()
				notify("Auto Win", "Getting " .. state.multiplierStartGun .. " before multiplier training.")
			elseif state.autoWinPausedForMultiplier then
				state.autoWinPausedForMultiplier = false
				state.autoWin = true
				restartAutoWinLoop()
			end
		end

		updateAutomationSummary()
	end,
})

FarmTab:CreateSlider({
	Name = "Multiplier Until Level",
	Range = {1, 250},
	Increment = 1,
	Suffix = " Level",
	CurrentValue = 50,
	Flag = "MultiplierUntilLevel",
	Callback = function(value)
		state.multiplierUntilLevel = value
		if state.autoBestMultiplier and shouldTrainAtMultiplier() and state.autoWin then
			state.waitingForMultiplierGun = false
			state.autoWinPausedForMultiplier = true
			stopAutoWinMovement()
			teleportToBestMultiplier()
			updateAutomationSummary()
		elseif state.autoBestMultiplier and shouldGetGunBeforeMultiplier() then
			state.waitingForMultiplierGun = true
			state.autoWinPausedForMultiplier = false
			state.autoWin = true
			checkWins()
			restartAutoWinLoop()
			updateAutomationSummary()
		end
	end,
})

FarmTab:CreateSlider({
	Name = "Multiplier Teleport Delay",
	Range = {0.25, 5},
	Increment = 0.25,
	Suffix = "s",
	CurrentValue = 1,
	Flag = "MultiplierTeleportDelay",
	Callback = function(value)
		state.multiplierTeleportDelay = value
	end,
})

FarmTab:CreateButton({
	Name = "Go To Best Multiplier",
	Callback = function()
		local success, bestZone = teleportToBestMultiplier()

		if success and bestZone then
			notify("Best Multiplier", "Teleported to " .. formatDamage(bestZone.multiplier) .. "x Power.")
		else
			notify("Best Multiplier", "No available multiplier zone found.")
		end
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
			if shouldTrainAtMultiplier() then
				state.waitingForMultiplierGun = false
				state.autoWinPausedForMultiplier = true
				stopAutoWinMovement()
				teleportToBestMultiplier()
				notify("Auto Win", "Waiting at multiplier until Level " .. state.multiplierUntilLevel .. ".")
			else
				state.waitingForMultiplierGun = shouldGetGunBeforeMultiplier()
				state.autoWinPausedForMultiplier = false
				restartAutoWinLoop()
			end
		else
			state.waitingForMultiplierGun = false
			state.autoWinPausedForMultiplier = false
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
		state.eggOpenRunId += 1
		eggWakeEvent:Fire()
		updateAutomationSummary()
	end,
})

EggsTab:CreateToggle({
	Name = "Auto Open Selected Egg",
	CurrentValue = false,
	Flag = "AutoOpenEgg",
	Callback = function(value)
		state.autoEggOpen = value
		state.eggOpenRunId += 1
		eggWakeEvent:Fire()
		updateAutomationSummary()
		notify("Auto Egg Open", value and "Enabled" or "Disabled")
	end,
})

EggsTab:CreateToggle({
	Name = "Auto Equip Best Pets",
	CurrentValue = false,
	Flag = "AutoEquipBestPets",
	Callback = function(value)
		state.autoEquipBestPets = value
		if value and hasLoadedConfiguration then
			equipBestPets()
		end
		updateAutomationSummary()
		notify("Auto Equip Best Pets", value and "Enabled" or "Disabled")
	end,
})

EggsTab:CreateButton({
	Name = "Equip Best Pets",
	Callback = function()
		equipBestPets()
		notify("Pets", "Equipped best pets.")
	end,
})

createDivider(EggsTab)
EggsTab:CreateSection("Pet Cleanup")

EggsTab:CreateDropdown({
	Name = "Delete Rarities",
	Options = rarityOptions,
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "DeletePetRarities",
	Callback = function(option)
		state.selectedDeleteRarities = typeof(option) == "table" and option or {}

		if state.autoDeletePets then
			deleteSelectedRarityPets()
		end
	end,
})

EggsTab:CreateToggle({
	Name = "Auto Delete Selected Rarities",
	CurrentValue = false,
	Flag = "AutoDeletePetRarities",
	Callback = function(value)
		state.autoDeletePets = value

		if value and hasLoadedConfiguration then
			deleteSelectedRarityPets()
		end

		updateAutomationSummary()
		notify("Auto Delete Pets", value and "Enabled" or "Disabled")
	end,
})

EggsTab:CreateButton({
	Name = "Delete Selected Rarities Now",
	Callback = function()
		local deletedCount = deleteSelectedRarityPets()
		notify("Pet Cleanup", deletedCount > 0 and ("Queued " .. deletedCount .. " pets for deletion.") or "No matching unequipped pets found.")
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
	Name = "Refresh Best Gun",
	Callback = function()
		checkWins()
		notify("Best Gun", "Checked current best available gun.")
	end,
})

SettingsTab:CreateButton({
	Name = "Stop Current Path",
	Callback = function()
		stopAutoWinMovement()
		notify("Movement", "Stopped current Auto Win path.")
	end,
})

SettingsTab:CreateSection("Connection")

SettingsTab:CreateToggle({
	Name = "Auto Rejoin",
	CurrentValue = false,
	Flag = "AutoRejoin",
	Callback = function(value)
		state.autoRejoin = value
		notify("Auto Rejoin", value and "Enabled" or "Disabled")
	end,
})

SettingsTab:CreateToggle({
	Name = "Anti AFK",
	CurrentValue = false,
	Flag = "AntiAFK",
	Callback = function(value)
		state.antiAfk = value
		notify("Anti AFK", value and "Enabled" or "Disabled")
	end,
})

Rayfield:LoadConfiguration()
hasLoadedConfiguration = true
checkWins()
checkRebirthLevel()
if state.autoEquipBestPets then
	equipBestPets()
end
if state.autoDeletePets then
	deleteSelectedRarityPets()
end
if state.autoBestMultiplier then
	if shouldTrainAtMultiplier() then
		state.waitingForMultiplierGun = false
		state.autoWinPausedForMultiplier = true
		stopAutoWinMovement()
		teleportToBestMultiplier()
	elseif shouldGetGunBeforeMultiplier() then
		state.waitingForMultiplierGun = true
		state.autoWinPausedForMultiplier = false
		state.autoWin = true
		checkWins()
		restartAutoWinLoop()
	else
		state.waitingForMultiplierGun = false
		state.autoWinPausedForMultiplier = false
		state.autoWin = true
		restartAutoWinLoop()
	end
end
eggWakeEvent:Fire()
updateAutomationSummary()
updateStageEditor()

notify("BaconHub", "Gun Evolution loaded. Press K to toggle the GUI.")
