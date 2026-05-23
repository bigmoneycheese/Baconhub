local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

local DataService = require(ReplicatedStorage.Packages.DataService).client
local Zones = require(ReplicatedStorage.Source.Game.Items.Zones)
local UpgradeTree = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeTree)
local UpgradeUtils = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeServiceUtils)
local originDependency = UpgradeUtils.enums.originDependency

local networkerRemotes = ReplicatedStorage
	:WaitForChild("Packages")
	:WaitForChild("_Index")
	:WaitForChild("leifstout_networker@0.3.1")
	:WaitForChild("networker")
	:WaitForChild("_remotes")

local rollRemote = networkerRemotes:WaitForChild("RollService"):WaitForChild("RemoteFunction")
local zonesRemote = networkerRemotes:WaitForChild("ZonesService"):WaitForChild("RemoteFunction")
local upgradeRemote = networkerRemotes:WaitForChild("UpgradeService"):WaitForChild("RemoteFunction")

local state = {
	autoRoll = false,
	autoBuyNextArea = false,
	autoUpgrade = false,
	autoWalkBestArea = false,
	autoWalkDrops = false,
	autoRejoin = false,
	antiAfk = false,
	rollDelay = 0.04,
	buyCheckDelay = 0.5,
	upgradeCheckDelay = 0.5,
	bestAreaCheckDelay = 2,
	dropScanDelay = 0.35,
}

local Window = Rayfield:CreateWindow({
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "Slime RNG",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "SlimeRNG",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local AutomationTab = Window:CreateTab("Automation", 0)
local MovementTab = Window:CreateTab("Movement", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

local function notify(title, content)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 3,
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

local function getCharacterParts()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")

	return humanoid, root
end

local function canUseMovement(owner)
	return _G.BaconHubMovementOwner == nil or _G.BaconHubMovementOwner == owner
end

local function claimMovement(owner)
	if not canUseMovement(owner) then
		return false
	end

	_G.BaconHubMovementOwner = owner
	return true
end

local function releaseMovement(owner)
	if _G.BaconHubMovementOwner == owner then
		_G.BaconHubMovementOwner = nil
	end
end

local function walkTo(position, owner, arriveDistance)
	if not claimMovement(owner) then
		return
	end

	local humanoid, root = getCharacterParts()
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 8,
	})

	local success = pcall(function()
		path:ComputeAsync(root.Position, position)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		humanoid:MoveTo(position)
		humanoid.MoveToFinished:Wait()
		releaseMovement(owner)
		return
	end

	for _, waypoint in ipairs(path:GetWaypoints()) do
		if not canUseMovement(owner) then
			break
		end

		if (root.Position - position).Magnitude <= arriveDistance then
			break
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		humanoid:MoveTo(waypoint.Position)
		local reached = humanoid.MoveToFinished:Wait()

		if not reached then
			break
		end
	end

	releaseMovement(owner)
end

local upgradeList = {}

for treeName, tree in pairs(UpgradeTree) do
	for upgradeId, upgradeInfo in pairs(tree) do
		local isTreeRootPlaceholder = treeName == upgradeId and upgradeInfo.dependency == originDependency and not upgradeInfo.cost

		if not isTreeRootPlaceholder then
			table.insert(upgradeList, {
				id = upgradeId,
				dependency = upgradeInfo.dependency,
				cost = upgradeInfo.cost,
				layers = upgradeInfo.layers or 0,
			})
		end
	end
end

table.sort(upgradeList, function(left, right)
	if left.layers ~= right.layers then
		return left.layers < right.layers
	end

	local leftCost = left.cost and left.cost.amount or 0
	local rightCost = right.cost and right.cost.amount or 0

	if leftCost ~= rightCost then
		return leftCost < rightCost
	end

	return left.id < right.id
end)

local function ownsUpgrade(ownedUpgrades, upgradeId)
	return ownedUpgrades and ownedUpgrades[upgradeId] == true
end

local function canBuyUpgrade(ownedUpgrades, upgrade)
	if ownsUpgrade(ownedUpgrades, upgrade.id) then
		return false
	end

	if upgrade.dependency ~= originDependency and not ownsUpgrade(ownedUpgrades, upgrade.dependency) then
		return false
	end

	if not upgrade.cost then
		return true
	end

	local currency = DataService:get(upgrade.cost.currency) or 0
	return currency >= upgrade.cost.amount
end

local function getBestAreaSpawn()
	local maxZone = DataService:get("maxZone") or 1
	local zone = workspace:WaitForChild("Zones"):FindFirstChild(tostring(maxZone))

	if not zone then
		return nil
	end

	local poi = zone:FindFirstChild("POI")
	local spawnPart = poi and poi:FindFirstChild("PlayerSpawn")

	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart
	end

	return nil
end

local function getDropPosition(drop)
	if drop:IsA("BasePart") then
		return drop.Position
	end

	if drop:IsA("Model") then
		return drop:GetPivot().Position
	end

	return nil
end

local function addDropTarget(targets, drop, rootPosition)
	local position = getDropPosition(drop)

	if not position then
		return
	end

	table.insert(targets, {
		instance = drop,
		position = position,
		distance = (rootPosition - position).Magnitude,
	})
end

local function getNearestDrop(rootPosition)
	local targets = {}
	local lootFolder = workspace:FindFirstChild("Loot")

	if lootFolder then
		for _, drop in ipairs(lootFolder:GetChildren()) do
			if drop:IsA("Model") or drop:IsA("BasePart") then
				addDropTarget(targets, drop, rootPosition)
			end
		end
	end

	for _, folder in ipairs(workspace:GetChildren()) do
		if folder:IsA("Folder") and string.match(folder.Name, "^Gameplay%d+$") then
			for _, drop in ipairs(folder:GetChildren()) do
				if drop:IsA("BasePart") and (drop.Name == "CoinPickup" or drop.Name == "GoopPickup") then
					addDropTarget(targets, drop, rootPosition)
				end
			end
		end
	end

	table.sort(targets, function(left, right)
		return left.distance < right.distance
	end)

	return targets[1]
end

local function triggerDrop(drop)
	if not drop or not drop.Parent then
		return
	end

	local prompt = drop:FindFirstChildWhichIsA("ProximityPrompt", true)

	if prompt and fireproximityprompt then
		pcall(function()
			fireproximityprompt(prompt)
		end)
	end
end

task.spawn(function()
	while true do
		if state.autoRoll then
			pcall(function()
				rollRemote:InvokeServer("requestRoll")
			end)

			task.wait(state.rollDelay)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoBuyNextArea then
			local coins = DataService:get("coins") or 0
			local maxZone = DataService:get("maxZone") or 1
			local nextZone = maxZone + 1

			if Zones.hasZone(nextZone) then
				local nextZoneInfo = Zones.getZone(nextZone)

				if coins >= nextZoneInfo.price then
					pcall(function()
						zonesRemote:InvokeServer("requestPurchaseZone")
					end)
				end
			end

			task.wait(state.buyCheckDelay)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoUpgrade then
			local ownedUpgrades = DataService:get("upgrades") or {}

			for _, upgrade in ipairs(upgradeList) do
				if canBuyUpgrade(ownedUpgrades, upgrade) then
					pcall(function()
						upgradeRemote:InvokeServer("requestUnlock", upgrade.id)
					end)

					break
				end
			end

			task.wait(state.upgradeCheckDelay)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoWalkBestArea and canUseMovement("AutoWalkBestArea") then
			local spawnPart = getBestAreaSpawn()

			if spawnPart then
				local _, root = getCharacterParts()

				if (root.Position - spawnPart.Position).Magnitude > 12 then
					walkTo(spawnPart.Position, "AutoWalkBestArea", 12)
				end
			end
		end

		task.wait(state.bestAreaCheckDelay)
	end
end)

task.spawn(function()
	while true do
		if state.autoWalkDrops and canUseMovement("AutoWalkDrops") then
			local _, root = getCharacterParts()
			local drop = getNearestDrop(root.Position)

			if drop then
				walkTo(drop.position, "AutoWalkDrops", 5)

				if drop.instance.Parent then
					triggerDrop(drop.instance)
				end
			else
				releaseMovement("AutoWalkDrops")
			end
		end

		task.wait(state.dropScanDelay)
	end
end)

AutomationTab:CreateSection("Farming")

AutomationTab:CreateToggle({
	Name = "Auto Roll",
	CurrentValue = false,
	Flag = "AutoRoll",
	Callback = function(value)
		state.autoRoll = value
		notify("Auto Roll", value and "Enabled" or "Disabled")
	end,
})

AutomationTab:CreateToggle({
	Name = "Auto Buy Next Area",
	CurrentValue = false,
	Flag = "AutoBuyNextArea",
	Callback = function(value)
		state.autoBuyNextArea = value
		notify("Auto Buy Next Area", value and "Enabled" or "Disabled")
	end,
})

AutomationTab:CreateToggle({
	Name = "Auto Upgrade Evenly",
	CurrentValue = false,
	Flag = "AutoUpgradeEvenly",
	Callback = function(value)
		state.autoUpgrade = value
		notify("Auto Upgrade", value and "Enabled" or "Disabled")
	end,
})

MovementTab:CreateSection("Movement")

MovementTab:CreateToggle({
	Name = "Auto Walk To Best Area",
	CurrentValue = false,
	Flag = "AutoWalkBestArea",
	Callback = function(value)
		state.autoWalkBestArea = value
		if not value then
			releaseMovement("AutoWalkBestArea")
		end
		notify("Best Area Walk", value and "Enabled" or "Disabled")
	end,
})

MovementTab:CreateToggle({
	Name = "Auto Walk To Drops",
	CurrentValue = false,
	Flag = "AutoWalkDrops",
	Callback = function(value)
		state.autoWalkDrops = value
		if not value then
			releaseMovement("AutoWalkDrops")
		end
		notify("Drop Walk", value and "Enabled" or "Disabled")
	end,
})

SettingsTab:CreateSection("Delays")

SettingsTab:CreateSlider({
	Name = "Roll Delay",
	Range = {0.04, 1},
	Increment = 0.01,
	Suffix = "s",
	CurrentValue = state.rollDelay,
	Flag = "RollDelay",
	Callback = function(value)
		state.rollDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Automation Check Delay",
	Range = {0.1, 3},
	Increment = 0.1,
	Suffix = "s",
	CurrentValue = state.buyCheckDelay,
	Flag = "AutomationCheckDelay",
	Callback = function(value)
		state.buyCheckDelay = value
		state.upgradeCheckDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Drop Scan Delay",
	Range = {0.1, 2},
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = state.dropScanDelay,
	Flag = "DropScanDelay",
	Callback = function(value)
		state.dropScanDelay = value
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
notify("BaconHub", "Slime RNG loaded. Press K to toggle the UI.")
