local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local worlds = {
	{
		name = "World 1",
		flagName = "World1",
		winsPosition = Vector3.new(5176, 6, 25),
		nextWorldPosition = Vector3.new(5190, 6, 25),
	},
	{
		name = "World 2",
		flagName = "World2",
		winsPosition = Vector3.new(4070, 71, -108),
		nextWorldPosition = Vector3.new(4080, 71, -120),
	},
	{
		name = "World 3",
		flagName = "World3",
		winsPosition = Vector3.new(938, 220, 700),
	},
}

local state = {
	autoClick = false,
	autoRebirth = false,
	autoFarmWins = {},
}

local Window = Rayfield:CreateWindow({
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "+1 Health Per Click",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "PlusOneHealthPerClick",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 0)
MainTab:CreateSection("Automation")

local function notify(title, content)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 3,
		Image = 0,
	})
end

local function getCharacterRoot()
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart")
end

local function teleportTo(position)
	local root = getCharacterRoot()
	root.CFrame = CFrame.new(position)
end

local function getClickEvent()
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MHP")
end

local function getRebirthEvent()
	return ReplicatedStorage:WaitForChild("RebirthRemote")
end

task.spawn(function()
	while true do
		if state.autoClick then
			getClickEvent():FireServer()
			task.wait(0.01)
		else
			task.wait(0.15)
		end
	end
end)

task.spawn(function()
	while true do
		if state.autoRebirth then
			getRebirthEvent():FireServer()
			task.wait(1)
		else
			task.wait(0.15)
		end
	end
end)

for _, world in ipairs(worlds) do
	state.autoFarmWins[world.flagName] = false

	task.spawn(function()
		while true do
			if state.autoFarmWins[world.flagName] then
				teleportTo(world.winsPosition)
				task.wait(1)
			else
				task.wait(0.15)
			end
		end
	end)
end

MainTab:CreateToggle({
	Name = "Auto Click",
	CurrentValue = false,
	Flag = "AutoClick",
	Callback = function(value)
		state.autoClick = value
		notify("Auto Click", value and "Enabled" or "Disabled")
	end,
})

MainTab:CreateToggle({
	Name = "Auto Rebirth",
	CurrentValue = false,
	Flag = "AutoRebirth",
	Callback = function(value)
		state.autoRebirth = value
		notify("Auto Rebirth", value and "Enabled" or "Disabled")
	end,
})

for _, world in ipairs(worlds) do
	local WorldTab = Window:CreateTab(world.name, 0)
	WorldTab:CreateSection("Farming")

	WorldTab:CreateToggle({
		Name = "Auto Farm Wins",
		CurrentValue = false,
		Flag = world.flagName .. "AutoFarmWins",
		Callback = function(value)
			state.autoFarmWins[world.flagName] = value
			notify(world.name .. " Auto Farm", value and "Enabled" or "Disabled")
		end,
	})

	if world.nextWorldPosition then
		WorldTab:CreateButton({
			Name = "Next World",
			Callback = function()
				teleportTo(world.nextWorldPosition)
				notify(world.name, "Teleported to next world.")
			end,
		})
	end
end

Rayfield:LoadConfiguration()
notify("BaconHub", "+1 Health Per Click loaded. Press K to toggle the UI.")
