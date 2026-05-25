local ENV = (typeof(getgenv) == "function" and getgenv()) or _G
local GUI_KEY = "BaconHub_DemonologyGui"

local oldSession = ENV[GUI_KEY]
if oldSession and oldSession.Cleanup then
	pcall(function()
		oldSession:Cleanup()
	end)
end

for _, key in ipairs({
	"BaconHub_DemonologyGhostChams",
	"BaconHub_DemonologyEvidenceESP",
	"BaconHub_DemonologyEvidenceWatcher",
	"BaconHub_DemonologyAutoFuseBox",
	"BaconHub_DemonologyInfiniteSprint",
}) do
	local oldFeature = ENV[key]
	if oldFeature and oldFeature.Cleanup then
		pcall(function()
			oldFeature:Cleanup()
		end)
	end
	ENV[key] = nil
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local EVIDENCE_COLORS = {
	["Ghost Orb"] = Color3.fromRGB(130, 210, 255),
	Handprint = Color3.fromRGB(90, 255, 140),
	["Laser/LIDAR"] = Color3.fromRGB(255, 80, 220),
	["Ghost Writing"] = Color3.fromRGB(255, 230, 90),
	Wither = Color3.fromRGB(190, 90, 255),
	["Freezing Temps"] = Color3.fromRGB(100, 190, 255),
	Evidence = Color3.fromRGB(255, 255, 255),
}

local state = {
	connections = {},

	ghostChams = false,
	evidenceEsp = false,
	autoFuse = false,
	infiniteSprint = false,
	autoRejoin = false,
	antiAfk = false,

	ghostChamsObjects = {},
	evidenceObjects = {},
	evidenceLive = {},
	evidenceCounts = {},

	lastGhostUpdate = 0,
	lastEvidenceScan = 0,
	lastFuseAttempt = 0,
	lastStaminaRefill = 0,
	autoRejoinRunning = false,
}

ENV[GUI_KEY] = state

local function notify(title, content)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 3,
		Image = 0,
	})
end

local function createParagraph(tab, data)
	local ok, paragraph = pcall(function()
		return tab:CreateParagraph(data)
	end)

	if ok and paragraph then
		return paragraph
	end

	return {
		Set = function() end,
	}
end

local function setParagraph(paragraph, title, content)
	if paragraph and paragraph.Set then
		pcall(function()
			paragraph:Set({
				Title = title,
				Content = content,
			})
		end)
	end
end

local function getGuiParent()
	local ok, result = pcall(function()
		if typeof(gethui) == "function" then
			return gethui()
		end
	end)

	return (ok and result) or CoreGui
end

local function disconnectAll(connections)
	for index, connection in ipairs(connections) do
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
		connections[index] = nil
	end
end

local function getGhost()
	return workspace:FindFirstChild("Ghost")
end

local function firstBasePart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getGhostPart(model)
	if not model then
		return nil
	end

	local visibleParts = model:FindFirstChild("VisibleParts")
	local torso = visibleParts and visibleParts:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end

	return firstBasePart(model)
end

local function getRootPart()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getDistance(part)
	local root = getRootPart()
	if not root or not part then
		return nil
	end

	return math.floor((root.Position - part.Position).Magnitude + 0.5)
end

local function cleanupGhostChams()
	local objects = state.ghostChamsObjects

	for _, object in pairs(objects.chams or {}) do
		if object and object.Parent then
			object:Destroy()
		end
	end

	for _, key in ipairs({ "folder", "highlight", "billboard", "label" }) do
		local object = objects[key]
		if object and object.Parent then
			object:Destroy()
		end
		objects[key] = nil
	end

	objects.chams = {}
end

local function ensureGhostChamsObjects()
	local objects = state.ghostChamsObjects

	if objects.folder and objects.folder.Parent then
		return objects
	end

	objects.folder = Instance.new("Folder")
	objects.folder.Name = "BaconHub_GhostChams"
	objects.folder.Parent = getGuiParent()
	objects.chams = {}

	local highlight = Instance.new("Highlight")
	highlight.Name = "GhostChamsHighlight"
	highlight.FillColor = Color3.fromRGB(255, 35, 95)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.18
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = objects.folder
	objects.highlight = highlight

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GhostChamsLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(240, 58)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.Parent = objects.folder
	objects.billboard = billboard

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.08
	label.TextWrapped = true
	label.Parent = billboard
	objects.label = label

	return objects
end

local function refreshGhostChams()
	local ghost = getGhost()
	local part = getGhostPart(ghost)
	local objects = ensureGhostChamsObjects()

	if not ghost or not part then
		if objects.highlight then
			objects.highlight.Enabled = false
		end
		if objects.billboard then
			objects.billboard.Enabled = false
		end
		return
	end

	objects.highlight.Enabled = true
	objects.highlight.Adornee = ghost
	objects.billboard.Enabled = true
	objects.billboard.Adornee = part

	local room = ghost:GetAttribute("FavoriteRoom") or ghost:GetAttribute("CurrentRoom") or "Unknown Room"
	local visualModel = ghost:GetAttribute("VisualModel") or "Ghost"
	local distance = getDistance(part)
	objects.label.Text = distance and string.format("%s\n%s | %d studs", visualModel, room, distance) or string.format("%s\n%s", visualModel, room)

	local liveParts = {}
	for _, instance in ipairs(ghost:GetDescendants()) do
		if instance:IsA("BasePart") then
			liveParts[instance] = true

			local cham = objects.chams[instance]
			if not cham or not cham.Parent then
				cham = Instance.new("BoxHandleAdornment")
				cham.Name = "GhostPartCham"
				cham.AlwaysOnTop = true
				cham.ZIndex = 10
				cham.Color3 = Color3.fromRGB(255, 35, 95)
				cham.Transparency = 0.35
				cham.Parent = objects.folder
				objects.chams[instance] = cham
			end

			cham.Adornee = instance
			cham.Size = instance.Size + Vector3.new(0.04, 0.04, 0.04)
			cham.Visible = true
		end
	end

	for partInstance, cham in pairs(objects.chams) do
		if not partInstance.Parent or not liveParts[partInstance] then
			if cham and cham.Parent then
				cham:Destroy()
			end
			objects.chams[partInstance] = nil
		end
	end
end

local function cleanupEvidenceObject(key)
	local object = state.evidenceObjects[key]
	if not object then
		return
	end

	for _, instance in pairs(object.instances) do
		if instance and instance.Parent then
			instance:Destroy()
		end
	end

	state.evidenceObjects[key] = nil
end

local function cleanupEvidenceEsp()
	for key in pairs(state.evidenceObjects) do
		cleanupEvidenceObject(key)
	end

	for _, key in ipairs({ "evidenceFolder", "evidenceAnchorFolder", "evidenceSummaryGui" }) do
		local object = state[key]
		if object and object.Parent then
			object:Destroy()
		end
		state[key] = nil
	end
end

local function ensureEvidenceContainers()
	if state.evidenceFolder and state.evidenceFolder.Parent then
		return
	end

	state.evidenceFolder = Instance.new("Folder")
	state.evidenceFolder.Name = "BaconHub_EvidenceESP"
	state.evidenceFolder.Parent = getGuiParent()

	state.evidenceAnchorFolder = Instance.new("Folder")
	state.evidenceAnchorFolder.Name = "BaconHub_EvidenceESP_Anchors"
	state.evidenceAnchorFolder.Parent = workspace

	local summaryGui = Instance.new("ScreenGui")
	summaryGui.Name = "BaconHubEvidenceESPSummary"
	summaryGui.ResetOnSpawn = false
	summaryGui.Parent = getGuiParent()
	state.evidenceSummaryGui = summaryGui

	local summaryLabel = Instance.new("TextLabel")
	summaryLabel.Name = "Summary"
	summaryLabel.Position = UDim2.fromOffset(14, 214)
	summaryLabel.Size = UDim2.fromOffset(380, 72)
	summaryLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	summaryLabel.BackgroundTransparency = 0.28
	summaryLabel.BorderSizePixel = 0
	summaryLabel.Font = Enum.Font.GothamSemibold
	summaryLabel.TextSize = 14
	summaryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	summaryLabel.TextStrokeTransparency = 0.65
	summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
	summaryLabel.TextYAlignment = Enum.TextYAlignment.Top
	summaryLabel.TextWrapped = true
	summaryLabel.Parent = summaryGui
	state.evidenceSummaryLabel = summaryLabel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = summaryLabel
end

local function createEvidenceAnchor(position, name)
	local anchor = Instance.new("Part")
	anchor.Name = name or "EvidenceAnchor"
	anchor.Size = Vector3.new(0.35, 0.35, 0.35)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = state.evidenceAnchorFolder
	return anchor
end

local function createEvidenceLabel()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EvidenceLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(210, 48)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.Parent = state.evidenceFolder

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.08
	label.TextWrapped = true
	label.Parent = billboard

	return billboard, label
end

local function ensureEvidenceObject(key, evidenceType, target, position)
	ensureEvidenceContainers()

	local color = EVIDENCE_COLORS[evidenceType] or EVIDENCE_COLORS.Evidence
	local part = firstBasePart(target)
	local object = state.evidenceObjects[key]

	if not object then
		object = {
			instances = {},
			evidenceType = evidenceType,
		}
		state.evidenceObjects[key] = object

		if not part and position then
			object.anchor = createEvidenceAnchor(position, evidenceType .. "Anchor")
			table.insert(object.instances, object.anchor)
			part = object.anchor
		end

		local billboard, label = createEvidenceLabel()
		object.billboard = billboard
		object.label = label
		table.insert(object.instances, billboard)

		if target and (target:IsA("BasePart") or target:IsA("Model")) then
			local highlight = Instance.new("Highlight")
			highlight.Name = "EvidenceHighlight"
			highlight.FillColor = color
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.35
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = target
			highlight.Parent = state.evidenceFolder
			object.highlight = highlight
			table.insert(object.instances, highlight)
		end

		if part then
			local adornment
			if evidenceType == "Ghost Orb" then
				adornment = Instance.new("SphereHandleAdornment")
				adornment.Radius = math.max(part.Size.X, part.Size.Y, part.Size.Z, 1.2)
			else
				adornment = Instance.new("BoxHandleAdornment")
				adornment.Size = part.Size + Vector3.new(0.08, 0.08, 0.08)
			end

			adornment.Name = "EvidenceCham"
			adornment.AlwaysOnTop = true
			adornment.ZIndex = 12
			adornment.Color3 = color
			adornment.Transparency = 0.25
			adornment.Adornee = part
			adornment.Parent = state.evidenceFolder
			object.adornment = adornment
			table.insert(object.instances, adornment)
		end
	end

	if object.anchor and position then
		object.anchor.CFrame = CFrame.new(position)
		part = object.anchor
	else
		part = firstBasePart(target) or object.anchor
	end

	if object.highlight and target then
		object.highlight.Adornee = target
		object.highlight.FillColor = color
		object.highlight.Enabled = true
	end

	if object.adornment and part then
		object.adornment.Adornee = part
		object.adornment.Color3 = color
		if object.adornment:IsA("BoxHandleAdornment") then
			object.adornment.Size = part.Size + Vector3.new(0.08, 0.08, 0.08)
		elseif object.adornment:IsA("SphereHandleAdornment") then
			object.adornment.Radius = math.max(part.Size.X, part.Size.Y, part.Size.Z, 1.2)
		end
		object.adornment.Visible = true
	end

	if object.billboard and part then
		object.billboard.Adornee = part
		object.billboard.Enabled = true
	end

	if object.label then
		local distance = getDistance(part)
		local text = evidenceType
		if target and typeof(target) == "Instance" and target.Name ~= evidenceType then
			text = text .. "\n" .. target.Name
		end
		if distance then
			text = text .. " | " .. tostring(distance) .. " studs"
		end
		object.label.Text = text
		object.label.TextColor3 = color
	end
end

local function markEvidence(key, evidenceType, target, position)
	state.evidenceLive[key] = true
	state.evidenceCounts[evidenceType] = (state.evidenceCounts[evidenceType] or 0) + 1
	ensureEvidenceObject(key, evidenceType, target, position)
end

local function getRoomPosition(room)
	local box = room and room:FindFirstChild("BoundingBox")
	if not box then
		return nil
	end

	if box:IsA("BasePart") then
		return box.Position
	end

	local total = Vector3.zero
	local count = 0
	for _, part in ipairs(box:GetDescendants()) do
		if part:IsA("BasePart") then
			total += part.Position
			count += 1
		end
	end

	return count > 0 and total / count or nil
end

local function hasVisibleDecal(instance, words)
	if not (instance:IsA("Decal") or instance:IsA("Texture")) then
		return false
	end

	local lowerName = instance.Name:lower()
	for _, word in ipairs(words) do
		if lowerName:find(word, 1, true) and instance.Transparency < 1 then
			return true
		end
	end

	return false
end

local function attributeSuggests(instance, words)
	for key, value in pairs(instance:GetAttributes()) do
		local text = tostring(key):lower() .. " " .. tostring(value):lower()
		for _, word in ipairs(words) do
			if text:find(word, 1, true) then
				return true
			end
		end
	end

	return false
end

local function scanEvidenceEsp()
	ensureEvidenceContainers()

	state.evidenceLive = {}
	state.evidenceCounts = {}

	local ghostOrb = workspace:FindFirstChild("GhostOrb")
	if ghostOrb then
		markEvidence(ghostOrb, "Ghost Orb", ghostOrb)
	end

	local handprints = workspace:FindFirstChild("Handprints")
	if handprints then
		for _, item in ipairs(handprints:GetChildren()) do
			markEvidence(item, "Handprint", item)
		end
	end

	local lidar = workspace:FindFirstChild("LIDAR")
	if lidar then
		for _, item in ipairs(lidar:GetChildren()) do
			markEvidence(item, "Laser/LIDAR", item)
		end
	end

	for _, instance in ipairs(workspace:GetDescendants()) do
		local name = instance.Name:lower()

		if hasVisibleDecal(instance, { "writing", "ghostwriting" }) then
			local target = firstBasePart(instance.Parent) and instance.Parent or instance
			markEvidence(instance, "Ghost Writing", target)
		elseif (instance:IsA("BasePart") or instance:IsA("Model")) and (name:find("ghostwriting", 1, true) or name:find("ghost writing", 1, true) or attributeSuggests(instance, { "ghostwriting", "ghost writing", "written" })) then
			markEvidence(instance, "Ghost Writing", instance)
		end

		if hasVisibleDecal(instance, { "distortion", "wither", "rust" }) then
			local target = firstBasePart(instance.Parent) and instance.Parent or instance
			markEvidence(instance, "Wither", target)
		elseif (instance:IsA("BasePart") or instance:IsA("Model")) and (name:find("wither", 1, true) or name:find("wilt", 1, true) or name:find("rust", 1, true) or attributeSuggests(instance, { "wither", "wilt", "rust", "distort" })) then
			markEvidence(instance, "Wither", instance)
		end
	end

	local rooms = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Rooms")
	if rooms then
		for _, room in ipairs(rooms:GetChildren()) do
			local temp = room:GetAttribute("Temperature")
			if temp and temp < 0 then
				local position = getRoomPosition(room)
				if position then
					local key = "FreezingRoom:" .. room.Name
					markEvidence(key, "Freezing Temps", nil, position + Vector3.new(0, 3, 0))

					local object = state.evidenceObjects[key]
					if object and object.label then
						object.label.Text = string.format("Freezing Temps\n%s | %.1f C", room.Name, temp)
					end
				end
			end
		end
	end

	for key in pairs(state.evidenceObjects) do
		if not state.evidenceLive[key] then
			cleanupEvidenceObject(key)
		end
	end

	local parts = {}
	for evidenceType, count in pairs(state.evidenceCounts) do
		table.insert(parts, evidenceType .. ": " .. tostring(count))
	end
	table.sort(parts)

	if state.evidenceSummaryLabel then
		state.evidenceSummaryLabel.Text = "Evidence ESP\n" .. (#parts > 0 and table.concat(parts, " | ") or "No evidence objects detected yet")
	end
end

local function findFuseBox()
	local map = workspace:FindFirstChild("Map")
	if map then
		local fuseBox = map:FindFirstChild("FuseBox", true)
		if fuseBox then
			return fuseBox
		end
	end

	return workspace:FindFirstChild("FuseBox", true)
end

local function findToggleFuseRemote()
	local events = ReplicatedStorage:FindFirstChild("Events")
	return events and events:FindFirstChild("ToggleFuseBox")
end

local function isFuseOn(fuseBox)
	if not fuseBox then
		return true
	end

	local enabled = fuseBox:GetAttribute("Enabled")
	if enabled ~= nil then
		return enabled == true
	end

	local stateValue = fuseBox:GetAttribute("State")
	if stateValue ~= nil then
		return stateValue == true or tostring(stateValue):lower() == "on"
	end

	for _, value in ipairs(fuseBox:GetDescendants()) do
		if value:IsA("BoolValue") and (value.Name == "Enabled" or value.Name == "On" or value.Name == "Powered") then
			return value.Value
		end
	end

	return true
end

local function tryFusePrompt(fuseBox)
	if typeof(fireproximityprompt) ~= "function" then
		return
	end

	for _, instance in ipairs(fuseBox:GetDescendants()) do
		if instance:IsA("ProximityPrompt") then
			pcall(fireproximityprompt, instance)
			task.wait(0.25)
			if isFuseOn(fuseBox) then
				return
			end
		end
	end
end

local function tryFuseRemote(fuseBox)
	local remote = findToggleFuseRemote()
	if not remote or not remote:IsA("RemoteEvent") then
		return
	end

	local attempts = {
		{ fuseBox },
		{ true },
		{ "On" },
		{},
	}

	for _, args in ipairs(attempts) do
		if isFuseOn(fuseBox) then
			return
		end

		pcall(function()
			remote:FireServer(table.unpack(args))
		end)

		task.wait(0.35)
	end
end

local function ensureFuseOn()
	local fuseBox = findFuseBox()
	if not fuseBox or isFuseOn(fuseBox) then
		return
	end

	tryFuseRemote(fuseBox)

	if not isFuseOn(fuseBox) then
		tryFusePrompt(fuseBox)
	end

	if isFuseOn(fuseBox) then
		notify("Auto Fuse", "Fuse box turned on.")
	end
end

local function getMaxStamina()
	local maxStamina = workspace:GetAttribute("MaxStamina") or 100
	if workspace:GetAttribute("Perk_Strength") then
		maxStamina *= 2
	end

	return maxStamina
end

local function refillStamina()
	if not state.infiniteSprint then
		return
	end

	local maxStamina = getMaxStamina()
	if (LocalPlayer:GetAttribute("Stamina") or 0) < maxStamina then
		LocalPlayer:SetAttribute("Stamina", maxStamina)
	end
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

function state:Cleanup()
	self.ghostChams = false
	self.evidenceEsp = false
	self.autoFuse = false
	self.infiniteSprint = false
	self.autoRejoin = false
	self.antiAfk = false

	cleanupGhostChams()
	cleanupEvidenceEsp()
	disconnectAll(self.connections)

	if self.rayfield and self.rayfield.Destroy then
		pcall(function()
			self.rayfield:Destroy()
		end)
	end

	if ENV[GUI_KEY] == self then
		ENV[GUI_KEY] = nil
	end
end

state.rayfield = Rayfield

table.insert(state.connections, LocalPlayer:GetAttributeChangedSignal("Stamina"):Connect(refillStamina))

table.insert(state.connections, RunService.Heartbeat:Connect(function()
	local now = os.clock()

	if state.ghostChams and now - state.lastGhostUpdate >= 0.08 then
		state.lastGhostUpdate = now
		refreshGhostChams()
	end

	if state.evidenceEsp and now - state.lastEvidenceScan >= 0.75 then
		state.lastEvidenceScan = now
		scanEvidenceEsp()
	end

	if state.autoFuse and now - state.lastFuseAttempt >= 2 then
		state.lastFuseAttempt = now
		ensureFuseOn()
	end

	if state.infiniteSprint and now - state.lastStaminaRefill >= 0.05 then
		state.lastStaminaRefill = now
		refillStamina()
	end
end))

table.insert(state.connections, GuiService.ErrorMessageChanged:Connect(function()
	if not state.autoRejoin or state.autoRejoinRunning then
		return
	end

	local errorCode = GuiService:GetErrorCode()
	local errorType = GuiService:GetErrorType()
	if errorType == Enum.ConnectionError.DisconnectErrors and not reconnectDisabledList[errorCode] then
		state.autoRejoinRunning = true
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

local Window = Rayfield:CreateWindow({
	Name = "BaconHub - Demonology",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "Demonology",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "Demonology",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local GhostTab = Window:CreateTab("Ghost", 0)
local EvidenceTab = Window:CreateTab("Evidence", 0)
local UtilityTab = Window:CreateTab("Utility", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

local ghostInfoParagraph = createParagraph(GhostTab, {
	Title = "Ghost Info",
	Content = "Press Refresh Ghost Room to read the current ghost room.",
})

local evidenceParagraph = createParagraph(EvidenceTab, {
	Title = "Evidence ESP",
	Content = "Marks physical evidence. Freezing labels only appear below 0 C.",
})

local function refreshGhostRoom()
	local ghost = getGhost()
	if not ghost then
		setParagraph(ghostInfoParagraph, "Ghost Info", "Ghost not found.")
		notify("Ghost Info", "Ghost not found.")
		return
	end

	local room = ghost:GetAttribute("FavoriteRoom") or ghost:GetAttribute("CurrentRoom") or "Unknown"
	local visualModel = ghost:GetAttribute("VisualModel") or "Unknown"
	local age = ghost:GetAttribute("Age") or "Unknown"
	local gender = ghost:GetAttribute("Gender") or "Unknown"
	local text = string.format("Room: %s\nModel: %s\nAge: %s | Gender: %s", room, visualModel, tostring(age), tostring(gender))

	setParagraph(ghostInfoParagraph, "Ghost Info", text)
	print("[BaconHub Demonology] Ghost room: " .. tostring(room))
	notify("Ghost Room", tostring(room))
end

GhostTab:CreateButton({
	Name = "Refresh Ghost Room",
	Callback = refreshGhostRoom,
})

GhostTab:CreateToggle({
	Name = "Ghost Chams",
	CurrentValue = state.ghostChams,
	Flag = "GhostChams",
	Callback = function(value)
		state.ghostChams = value
		if value then
			refreshGhostChams()
			notify("Ghost Chams", "Enabled")
		else
			cleanupGhostChams()
			notify("Ghost Chams", "Disabled")
		end
	end,
})

EvidenceTab:CreateToggle({
	Name = "Evidence ESP",
	CurrentValue = state.evidenceEsp,
	Flag = "EvidenceESP",
	Callback = function(value)
		state.evidenceEsp = value
		if value then
			scanEvidenceEsp()
			setParagraph(evidenceParagraph, "Evidence ESP", "Enabled. Freezing labels require temperature below 0 C.")
			notify("Evidence ESP", "Enabled")
		else
			cleanupEvidenceEsp()
			setParagraph(evidenceParagraph, "Evidence ESP", "Disabled.")
			notify("Evidence ESP", "Disabled")
		end
	end,
})

EvidenceTab:CreateButton({
	Name = "Refresh Evidence ESP",
	Callback = function()
		if not state.evidenceEsp then
			notify("Evidence ESP", "Turn it on first.")
			return
		end

		scanEvidenceEsp()
		notify("Evidence ESP", "Refreshed")
	end,
})

UtilityTab:CreateToggle({
	Name = "Auto Fuse Box",
	CurrentValue = state.autoFuse,
	Flag = "AutoFuseBox",
	Callback = function(value)
		state.autoFuse = value
		if value then
			ensureFuseOn()
		end
		notify("Auto Fuse", value and "Enabled" or "Disabled")
	end,
})

UtilityTab:CreateToggle({
	Name = "Infinite Sprint",
	CurrentValue = state.infiniteSprint,
	Flag = "InfiniteSprint",
	Callback = function(value)
		state.infiniteSprint = value
		if value then
			refillStamina()
		end
		notify("Infinite Sprint", value and "Enabled" or "Disabled")
	end,
})

SettingsTab:CreateToggle({
	Name = "Auto Rejoin",
	CurrentValue = state.autoRejoin,
	Flag = "AutoRejoin",
	Callback = function(value)
		state.autoRejoin = value
		if not value then
			state.autoRejoinRunning = false
		end
		notify("Auto Rejoin", value and "Enabled" or "Disabled")
	end,
})

SettingsTab:CreateToggle({
	Name = "Anti AFK",
	CurrentValue = state.antiAfk,
	Flag = "AntiAFK",
	Callback = function(value)
		state.antiAfk = value
		notify("Anti AFK", value and "Enabled" or "Disabled")
	end,
})

SettingsTab:CreateButton({
	Name = "Unload GUI",
	Callback = function()
		state:Cleanup()
	end,
})

Rayfield:LoadConfiguration()
refreshGhostRoom()
notify("BaconHub", "Demonology GUI loaded. Press K to toggle.")
