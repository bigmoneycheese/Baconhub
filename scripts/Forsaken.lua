-- Feature: Forsaken BaconHub GUI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local DEFAULT_DASH_LENGTH = 40

if getgenv().BaconHubForsakenGUI then
	getgenv().BaconHubForsakenGUI:Cleanup()
end

for _, globalName in ipairs({
	"BaconHubForsakenKillerESP",
	"BaconHubForsakenGeneratorESP",
	"BaconHubForsakenPlayerESP",
}) do
	local oldState = getgenv()[globalName]
	if oldState and oldState.Cleanup then
		oldState:Cleanup()
		getgenv()[globalName] = nil
	end
end

for _, folderName in ipairs({
	"BaconHub_ForsakenKillerESP",
	"BaconHub_ForsakenGeneratorESP",
	"BaconHub_ForsakenPlayerESP",
	"BaconHub_KillerESP",
	"BaconHub_GeneratorESP",
	"BaconHub_PlayerESP",
}) do
	local oldFolder = workspace:FindFirstChild(folderName)
	if oldFolder then
		oldFolder:Destroy()
	end
end

local state = {
	connections = {},
	features = {},
	autoRejoin = false,
	antiAfk = false,
	dashLength = DEFAULT_DASH_LENGTH,
	rayfield = Rayfield,
}

getgenv().BaconHubForsakenGUI = state

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		if connection then
			connection:Disconnect()
		end
	end

	table.clear(connections)
end

local function create(className, properties)
	local instance = Instance.new(className)

	for property, value in pairs(properties or {}) do
		instance[property] = value
	end

	return instance
end

local Window = Rayfield:CreateWindow({
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "Forsaken",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "Forsaken",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local EspTab = Window:CreateTab("ESP", 0)
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

table.insert(state.connections, GuiService.ErrorMessageChanged:Connect(function()
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
end))

table.insert(state.connections, LocalPlayer.Idled:Connect(function()
	if not state.antiAfk then
		return
	end

	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end))

local function makeEspFeature(options)
	local feature = {
		connections = {},
		objects = {},
		folder = nil,
	}

	local function getFolder()
		local playersFolder = workspace:FindFirstChild("Players")
		return playersFolder and playersFolder:FindFirstChild(options.folderName)
	end

	local function getDisplayText(character)
		local actorName = character:GetAttribute("ActorDisplayName")
		local username = character:GetAttribute("Username")

		if actorName and username then
			return tostring(actorName) .. " / " .. tostring(username)
		end

		return tostring(actorName or username or character.Name)
	end

	local function cleanupCharacter(character)
		local objects = feature.objects[character]
		if not objects then
			return
		end

		for _, object in ipairs(objects) do
			if object and object.Parent then
				object:Destroy()
			end
		end

		feature.objects[character] = nil
	end

	local function addEsp(character)
		if not character:IsA("Model") then
			return
		end

		if LocalPlayer.Character == character then
			cleanupCharacter(character)
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
		local head = character:FindFirstChild("Head")

		if not humanoid or not root or humanoid.Health <= 0 then
			cleanupCharacter(character)
			return
		end

		if feature.objects[character] then
			local label = feature.objects[character][2]
			local text = label and label:FindFirstChild("Name")
			if text then
				text.Text = getDisplayText(character)
			end
			return
		end

		local highlight = create("Highlight", {
			Name = options.name .. "Highlight",
			Adornee = character,
			FillColor = options.fillColor,
			OutlineColor = Color3.fromRGB(255, 255, 255),
			FillTransparency = options.fillTransparency,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			Parent = feature.folder,
		})

		local label = create("BillboardGui", {
			Name = options.name .. "Label",
			Adornee = head or root,
			AlwaysOnTop = true,
			Size = UDim2.fromOffset(180, 42),
			StudsOffset = Vector3.new(0, 3.25, 0),
			Parent = feature.folder,
		})

		create("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			Text = getDisplayText(character),
			TextColor3 = options.textColor,
			TextSize = 15,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0,
			Parent = label,
		})

		feature.objects[character] = { highlight, label }
	end

	local function refresh()
		local folder = getFolder()
		local active = {}

		if folder then
			for _, character in ipairs(folder:GetChildren()) do
				active[character] = true
				addEsp(character)
			end
		end

		for character in pairs(feature.objects) do
			if not active[character] or not character.Parent then
				cleanupCharacter(character)
			end
		end
	end

	local function watchFolder(folder)
		table.insert(feature.connections, folder.ChildAdded:Connect(function()
			task.defer(refresh)
		end))

		table.insert(feature.connections, folder.ChildRemoved:Connect(cleanupCharacter))
	end

	function feature:Start()
		self:Stop()

		self.folder = create("Folder", {
			Name = "BaconHub_" .. options.name .. "ESP",
			Parent = workspace,
		})

		local folder = getFolder()
		if folder then
			watchFolder(folder)
		end

		table.insert(self.connections, workspace.ChildAdded:Connect(function(child)
			if child.Name ~= "Players" then
				return
			end

			task.defer(function()
				local newFolder = getFolder()
				if newFolder then
					watchFolder(newFolder)
					refresh()
				end
			end)
		end))

		table.insert(self.connections, RunService.Heartbeat:Connect(refresh))
		refresh()
	end

	function feature:Stop()
		disconnectAll(self.connections)

		for character in pairs(self.objects) do
			cleanupCharacter(character)
		end

		if self.folder and self.folder.Parent then
			self.folder:Destroy()
		end

		self.folder = nil
	end

	return feature
end

local function makeGeneratorEspFeature()
	local feature = {
		connections = {},
		objects = {},
		folder = nil,
	}

	local function isGeneratorModel(model)
		return model:IsA("Model") and model.Name == "Generator" and model:FindFirstChild("Progress") and model:FindFirstChild("Main")
	end

	local function getScanRoot()
		local mapFolder = workspace:FindFirstChild("Map")
		local ingameFolder = mapFolder and mapFolder:FindFirstChild("Ingame")
		return ingameFolder or workspace
	end

	local function getProgress(generator)
		local progress = generator:FindFirstChild("Progress")
		if progress and progress:IsA("NumberValue") then
			return math.clamp(math.floor(progress.Value + 0.5), 0, 100)
		end

		return 0
	end

	local function getAdornee(generator)
		local main = generator:FindFirstChild("Main")
		if main and main:IsA("BasePart") then
			return main
		end

		return generator:FindFirstChildWhichIsA("BasePart", true)
	end

	local function getColor(generator)
		if getProgress(generator) >= 100 then
			return Color3.fromRGB(70, 255, 120)
		end

		return Color3.fromRGB(255, 210, 70)
	end

	local function cleanupGenerator(generator)
		local objects = feature.objects[generator]
		if not objects then
			return
		end

		for _, object in ipairs(objects) do
			if object and object.Parent then
				object:Destroy()
			end
		end

		feature.objects[generator] = nil
	end

	local function getGenerators()
		local generators = {}

		for _, instance in ipairs(getScanRoot():GetDescendants()) do
			if isGeneratorModel(instance) then
				table.insert(generators, instance)
			end
		end

		return generators
	end

	local function addGeneratorEsp(generator)
		local adornee = getAdornee(generator)
		if not adornee then
			cleanupGenerator(generator)
			return
		end

		local color = getColor(generator)
		local textValue = "GENERATOR " .. tostring(getProgress(generator)) .. "%"

		if feature.objects[generator] then
			local objects = feature.objects[generator]
			local highlight = objects[1]
			local label = objects[2]
			local text = label and label:FindFirstChild("Name")

			if highlight then
				highlight.FillColor = color
			end

			if text then
				text.Text = textValue
				text.TextColor3 = color
			end

			return
		end

		local highlight = create("Highlight", {
			Name = "GeneratorHighlight",
			Adornee = generator,
			FillColor = color,
			OutlineColor = Color3.fromRGB(255, 255, 255),
			FillTransparency = 0.35,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			Parent = feature.folder,
		})

		local label = create("BillboardGui", {
			Name = "GeneratorLabel",
			Adornee = adornee,
			AlwaysOnTop = true,
			Size = UDim2.fromOffset(160, 38),
			StudsOffset = Vector3.new(0, 4, 0),
			Parent = feature.folder,
		})

		create("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			Text = textValue,
			TextColor3 = color,
			TextSize = 15,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0,
			Parent = label,
		})

		feature.objects[generator] = { highlight, label }
	end

	local function refresh()
		local active = {}

		for _, generator in ipairs(getGenerators()) do
			active[generator] = true
			addGeneratorEsp(generator)
		end

		for generator in pairs(feature.objects) do
			if not active[generator] or not generator.Parent then
				cleanupGenerator(generator)
			end
		end
	end

	function feature:Start()
		self:Stop()

		self.folder = create("Folder", {
			Name = "BaconHub_GeneratorESP",
			Parent = workspace,
		})

		table.insert(self.connections, RunService.Heartbeat:Connect(refresh))
		refresh()
	end

	function feature:Stop()
		disconnectAll(self.connections)

		for generator in pairs(self.objects) do
			cleanupGenerator(generator)
		end

		if self.folder and self.folder.Parent then
			self.folder:Destroy()
		end

		self.folder = nil
	end

	return feature
end

state.features.killerEsp = makeEspFeature({
	name = "Killer",
	folderName = "Killers",
	fillColor = Color3.fromRGB(255, 35, 35),
	textColor = Color3.fromRGB(255, 55, 55),
	fillTransparency = 0.25,
})

state.features.playerEsp = makeEspFeature({
	name = "Player",
	folderName = "Survivors",
	fillColor = Color3.fromRGB(45, 170, 255),
	textColor = Color3.fromRGB(70, 185, 255),
	fillTransparency = 0.35,
})

state.features.generatorEsp = makeGeneratorEspFeature()

local function setFeature(feature, enabled)
	if enabled then
		feature:Start()
	else
		feature:Stop()
	end
end

local function dash()
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		warn("BaconHub: HumanoidRootPart was not found.")
		return
	end

	local forward = root.CFrame.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z)

	if flatForward.Magnitude <= 0 then
		flatForward = Vector3.new(0, 0, -1)
	else
		flatForward = flatForward.Unit
	end

	character:PivotTo(character:GetPivot() + (flatForward * state.dashLength))
end

EspTab:CreateSection("Players")

EspTab:CreateToggle({
	Name = "Killer ESP",
	CurrentValue = false,
	Flag = "ForsakenKillerESP",
	Callback = function(value)
		setFeature(state.features.killerEsp, value)
		notify("Killer ESP", value and "Enabled" or "Disabled")
	end,
})

EspTab:CreateToggle({
	Name = "Survivor ESP",
	CurrentValue = false,
	Flag = "ForsakenSurvivorESP",
	Callback = function(value)
		setFeature(state.features.playerEsp, value)
		notify("Survivor ESP", value and "Enabled" or "Disabled")
	end,
})

EspTab:CreateSection("Generators")

EspTab:CreateToggle({
	Name = "Generator ESP",
	CurrentValue = false,
	Flag = "ForsakenGeneratorESP",
	Callback = function(value)
		setFeature(state.features.generatorEsp, value)
		notify("Generator ESP", value and "Enabled" or "Disabled")
	end,
})

MovementTab:CreateSection("Dash")

MovementTab:CreateButton({
	Name = "Dash Forward",
	Callback = dash,
})

MovementTab:CreateKeybind({
	Name = "Dash Keybind",
	CurrentKeybind = "Q",
	HoldToInteract = false,
	Flag = "ForsakenDashKeybind",
	Callback = dash,
})

MovementTab:CreateSlider({
	Name = "Dash Length",
	Range = {1, 50},
	Increment = 1,
	Suffix = " studs",
	CurrentValue = DEFAULT_DASH_LENGTH,
	Flag = "ForsakenDashLength",
	Callback = function(value)
		state.dashLength = math.clamp(math.floor(tonumber(value) or DEFAULT_DASH_LENGTH), 1, 50)
	end,
})

SettingsTab:CreateSection("Connection")

SettingsTab:CreateToggle({
	Name = "Auto Rejoin",
	CurrentValue = false,
	Flag = "ForsakenAutoRejoin",
	Callback = function(value)
		state.autoRejoin = value
		notify("Auto Rejoin", value and "Enabled" or "Disabled")
	end,
})

SettingsTab:CreateToggle({
	Name = "Anti AFK",
	CurrentValue = false,
	Flag = "ForsakenAntiAFK",
	Callback = function(value)
		state.antiAfk = value
		notify("Anti AFK", value and "Enabled" or "Disabled")
	end,
})

Rayfield:LoadConfiguration()

function state:Cleanup()
	for _, feature in pairs(self.features) do
		if feature.Stop then
			feature:Stop()
		end
	end

	disconnectAll(self.connections)

	if self.rayfield and self.rayfield.Destroy then
		pcall(function()
			self.rayfield:Destroy()
		end)
	end
end
