local ENV = (typeof(getgenv) == "function" and getgenv()) or _G
local GLOBAL_KEY = "BaconHubUntitledTagGameGui"
local oldSession = ENV[GLOBAL_KEY]
if oldSession and oldSession.Cleanup then
	pcall(function()
		oldSession:Cleanup()
	end)
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Teams = game:GetService("Teams")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ESP_FOLDER_NAME = "BaconHub_UntitledTagGamePlayerESP"
local HITBOX_NAME = "BaconHubQueryHitbox"
local CAMERA_TURN_BIND = "BaconHubUntitledTagGameCameraTurn"

local DEFAULT_TAGGER_WORDS = {
	"tagger",
	"it",
	"infected",
	"patientzero",
	"patient zero",
	"slasher",
	"killer",
	"murderer",
	"hunter",
	"juggernaut",
	"bomber",
	"bomb",
	"redteam",
	"red team",
}

local DEFAULT_SURVIVOR_WORDS = {
	"runner",
	"survivor",
	"surviv",
	"blue",
	"blueteam",
	"blue team",
	"green",
	"greenteam",
	"green team",
	"orange",
	"orangeteam",
	"orange team",
	"purple",
	"purpleteam",
	"purple team",
	"yellow",
	"yellowteam",
	"yellow team",
	"guard",
	"medic",
	"hider",
	"civilian",
	"player",
}

local DEFAULT_IGNORE_WORDS = {
	"neutral",
	"dead",
	"spectator",
	"lobby",
	"afk",
	"none",
	"nil",
}

local DEFAULT_ATTRIBUTE_NAMES = {
	"RagdollRole",
	"PlayerRole",
	"LastUpdateRole",
	"Role",
	"Team",
	"TeamName",
}

local DEFAULT_VALUE_NAMES = {
	"PlayerRole",
	"Role",
	"Team",
	"TeamName",
}

local NO_TEAM_OPTION = "No detected teams"

local OLD_HITBOX_NAMES = {
	[HITBOX_NAME] = true,
}

local function trim(value)
	return (tostring(value or ""):match("^%s*(.-)%s*$"))
end

local function normalize(value)
	local text = tostring(value or ""):lower()
	text = text:gsub("_", " "):gsub("%-", " "):gsub("%s+", " ")
	return trim(text)
end

local function copyList(list)
	local copy = {}
	for index, value in ipairs(list) do
		copy[index] = value
	end

	return copy
end

local function parseList(value, preserveCase)
	local list = {}
	local seen = {}

	for raw in tostring(value or ""):gmatch("[^,\n;|]+") do
		local item = preserveCase and trim(raw) or normalize(raw)
		if item ~= "" and not seen[item] then
			table.insert(list, item)
			seen[item] = true
		end
	end

	return list
end

local function joinList(list)
	local values = {}
	for index, value in ipairs(list) do
		values[index] = tostring(value)
	end

	return table.concat(values, ", ")
end

local function containsAny(text, words)
	local normalizedText = normalize(text)
	if normalizedText == "" then
		return false
	end

	for _, word in ipairs(words) do
		local normalizedWord = normalize(word)
		if normalizedWord ~= "" and (normalizedText == normalizedWord or normalizedText:find(normalizedWord, 1, true)) then
			return true
		end
	end

	return false
end

local function getDropdownValue(value, fallback)
	if typeof(value) == "table" then
		return tostring(value[1] or fallback)
	end

	return tostring(value or fallback)
end

local function getMultiOptions(value)
	local options = {}

	if typeof(value) == "table" then
		for _, option in ipairs(value) do
			if option ~= NO_TEAM_OPTION then
				table.insert(options, tostring(option))
			end
		end
	elseif value and value ~= NO_TEAM_OPTION then
		table.insert(options, tostring(value))
	end

	return options
end

local function create(className, properties)
	local instance = Instance.new(className)

	for property, value in pairs(properties or {}) do
		instance[property] = value
	end

	return instance
end

local function getGuiParent()
	local ok, result = pcall(function()
		if typeof(gethui) == "function" then
			return gethui()
		end

		return nil
	end)

	return (ok and result) or CoreGui
end

local state = {
	connections = {},
	espObjects = {},
	hitboxObjects = {},
	rayfield = Rayfield,

	espEnabled = true,
	espHighlights = true,
	espLabels = true,
	espShowTaggers = true,
	espShowSurvivors = true,
	espShowUnknown = false,
	espShowRole = true,
	espShowDistance = true,
	espShowHealth = false,
	espNameMode = "Display Name",
	espSeparator = " | ",
	espDistanceSuffix = "st",
	espMaxDistance = 2500,
	espUpdateInterval = 0.08,
	espLabelSize = 14,
	espLabelWidth = 230,
	espLabelHeight = 44,
	espLabelYOffset = 2.9,
	espFillTransparency = 0.72,
	espOutlineTransparency = 0,
	espUseCustomTeamColors = true,
	espColors = {
		TAGGER = Color3.fromRGB(255, 60, 60),
		SURVIVOR = Color3.fromRGB(55, 170, 255),
		UNKNOWN = Color3.fromRGB(255, 230, 85),
	},
	teamColors = {},
	selectedColorTeam = NO_TEAM_OPTION,

	taggerWords = copyList(DEFAULT_TAGGER_WORDS),
	survivorWords = copyList(DEFAULT_SURVIVOR_WORDS),
	ignoreWords = copyList(DEFAULT_IGNORE_WORDS),
	selectedTaggerTeams = {},
	selectedSurvivorTeams = {},
	selectedIgnoredTeams = {},
	selectedAvoidTeams = {},
	roleAttributeNames = copyList(DEFAULT_ATTRIBUTE_NAMES),
	roleValueNames = copyList(DEFAULT_VALUE_NAMES),
	avoidMode = "Enemies Only",
	avoidIgnoreIgnoredRoles = true,

	hitboxEnabled = false,
	hitboxSize = 7.5,

	dashSpeed = 220,
	dashGroundLift = 12,
	dashCooldown = 0.15,
	dashPreserveFaster = true,
	dashDirectionMode = "Current Velocity",

	doubleEnabled = false,
	doubleActive = false,
	doubleMultiplier = 2,

	catchEnabled = false,
	catchTargetRadius = 140,
	catchTimeout = 3,
	catchCursorDistance = 350,
	catchCloseDistance = 7,
	catchSoftenDistance = 42,
	catchMinExtraSpeed = 35,
	catchMaxExtraSpeed = 215,
	catchAcceleration = 900,
	catchGroundLift = 7,
	catchMatchVelocity = true,
	catching = false,
	catchTarget = nil,
	catchStartedAt = 0,

	dodgeEnabled = false,
	dodgeEnemyRadius = 130,
	dodgeSectorCount = 24,
	dodgeAvoidCone = 55,
	dodgeCameraTurn = true,
	dodgeMouseTurn = true,
	dodgeCameraTurnTime = 0.24,
	dodgeBoostMinSpeed = 92,
	dodgeBoostAddSpeed = 68,
	dodgeBoostMaxSpeed = 150,

	autoRejoin = false,
	antiAfk = false,
}

ENV[GLOBAL_KEY] = state

local function notify(title, content)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 3,
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

local function readValueBase(parent, name)
	if not parent then
		return nil
	end

	local value = parent:FindFirstChild(name)
	if value and value:IsA("ValueBase") then
		return tostring(value.Value)
	end

	return nil
end

local function collectRoles(player)
	local character = player.Character
	local roles = {}

	local function add(value)
		if value ~= nil and tostring(value) ~= "" then
			table.insert(roles, tostring(value))
		end
	end

	for _, attributeName in ipairs(state.roleAttributeNames) do
		add(player:GetAttribute(attributeName))
		add(character and character:GetAttribute(attributeName))
	end

	for _, valueName in ipairs(state.roleValueNames) do
		add(readValueBase(player, valueName))
		add(readValueBase(character, valueName))
	end

	add(player.Team and player.Team.Name)

	return roles
end

local function isIgnoredRoleText(text)
	local role = normalize(text)
	return role == "" or containsAny(role, state.ignoreWords)
end

local function toSelectionSet(selection)
	local selected = {}

	for _, value in ipairs(selection or {}) do
		local key = normalize(value)
		if key ~= "" and key ~= normalize(NO_TEAM_OPTION) then
			selected[key] = true
		end
	end

	return selected
end

local function roleMatchesSelection(roleText, selection)
	local selected = toSelectionSet(selection)
	local key = normalize(roleText)

	return key ~= "" and selected[key] == true
end

local function playerMatchesSelection(player, selection)
	for _, raw in ipairs(collectRoles(player)) do
		if roleMatchesSelection(raw, selection) then
			return true
		end
	end

	return false
end

local function hasIgnoredRole(player)
	for _, raw in ipairs(collectRoles(player)) do
		if isIgnoredRoleText(raw) or roleMatchesSelection(raw, state.selectedIgnoredTeams) then
			return true
		end
	end

	return false
end

local function classifyPlayer(player)
	local roles = collectRoles(player)
	local hasUsefulRole = false

	if playerMatchesSelection(player, state.selectedTaggerTeams) then
		return "TAGGER"
	end

	if playerMatchesSelection(player, state.selectedSurvivorTeams) then
		return "SURVIVOR"
	end

	for _, raw in ipairs(roles) do
		local role = normalize(raw)
		if not isIgnoredRoleText(role) then
			hasUsefulRole = true
		end

		if containsAny(role, state.taggerWords) then
			return "TAGGER"
		end
	end

	for _, raw in ipairs(roles) do
		local role = normalize(raw)
		if containsAny(role, state.survivorWords) then
			return "SURVIVOR"
		end
	end

	if hasUsefulRole then
		return "UNKNOWN"
	end

	return nil
end

local function hasListedAvoidRole(player)
	return playerMatchesSelection(player, state.selectedAvoidTeams)
end

local function addDetectedOption(options, seen, value)
	local text = trim(value)
	local key = normalize(text)

	if key == "" or seen[key] then
		return
	end

	seen[key] = true
	table.insert(options, text)
end

local function getDetectedTeamOptions()
	local options = {}
	local seen = {}

	for _, team in ipairs(Teams:GetChildren()) do
		if team:IsA("Team") then
			addDetectedOption(options, seen, team.Name)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team then
			addDetectedOption(options, seen, player.Team.Name)
		end

		for _, role in ipairs(collectRoles(player)) do
			addDetectedOption(options, seen, role)
		end
	end

	table.sort(options, function(left, right)
		return tostring(left):lower() < tostring(right):lower()
	end)

	if #options == 0 then
		return { NO_TEAM_OPTION }
	end

	return options
end

local function optionExists(options, value)
	local key = normalize(value)

	for _, option in ipairs(options) do
		if normalize(option) == key then
			return true
		end
	end

	return false
end

local function sanitizeSelection(selection, options)
	local clean = {}

	for _, selected in ipairs(selection or {}) do
		if optionExists(options, selected) and selected ~= NO_TEAM_OPTION then
			table.insert(clean, selected)
		end
	end

	return clean
end

local function getDefaultSelection(options, words)
	local selected = {}

	for _, option in ipairs(options or {}) do
		if option ~= NO_TEAM_OPTION and containsAny(option, words) then
			table.insert(selected, option)
		end
	end

	return selected
end

local function getOptionsKey(options)
	return table.concat(options, "\n")
end

local teamDropdowns = {}
local teamDropdownOptions = getDetectedTeamOptions()
local teamDropdownOptionsKey = getOptionsKey(teamDropdownOptions)

local function registerTeamDropdown(dropdown, getSelection, setSelection, multiple)
	if dropdown then
		table.insert(teamDropdowns, {
			dropdown = dropdown,
			getSelection = getSelection,
			setSelection = setSelection,
			multiple = multiple,
		})
	end

	return dropdown
end

local function refreshTeamDropdowns(force)
	local options = getDetectedTeamOptions()
	local optionsKey = getOptionsKey(options)

	if not force and optionsKey == teamDropdownOptionsKey then
		return
	end

	teamDropdownOptions = options
	teamDropdownOptionsKey = optionsKey

	if #state.selectedTaggerTeams == 0 then
		state.selectedTaggerTeams = getDefaultSelection(options, DEFAULT_TAGGER_WORDS)
	end

	if #state.selectedSurvivorTeams == 0 then
		state.selectedSurvivorTeams = getDefaultSelection(options, DEFAULT_SURVIVOR_WORDS)
	end

	if #state.selectedIgnoredTeams == 0 then
		state.selectedIgnoredTeams = getDefaultSelection(options, DEFAULT_IGNORE_WORDS)
	end

	if #state.selectedAvoidTeams == 0 then
		state.selectedAvoidTeams = getDefaultSelection(options, DEFAULT_TAGGER_WORDS)
	end

	for _, entry in ipairs(teamDropdowns) do
		local selection = entry.getSelection()

		if entry.multiple then
			selection = sanitizeSelection(selection, options)
			entry.setSelection(selection)
		else
			if not optionExists(options, selection) then
				selection = options[1] or NO_TEAM_OPTION
				entry.setSelection(selection)
			end
		end

		if entry.dropdown.Refresh then
			pcall(function()
				entry.dropdown:Refresh(options, entry.multiple and selection or { selection })
			end)
		end
	end
end

local function isSameTeam(player)
	return LocalPlayer.Team ~= nil and player.Team ~= nil and LocalPlayer.Team == player.Team
end

local function getRootAndHumanoid(player)
	local character = player.Character
	if not character then
		return nil, nil
	end

	return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

local function isAlivePlayer(player)
	local root, humanoid = getRootAndHumanoid(player)
	return root ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function shouldAvoidPlayer(player)
	if not player or player == LocalPlayer or not isAlivePlayer(player) then
		return false
	end

	if isSameTeam(player) then
		return false
	end

	if state.avoidIgnoreIgnoredRoles and hasIgnoredRole(player) then
		return false
	end

	local mode = state.avoidMode
	local theirRole = classifyPlayer(player)

	if mode == "All Players" then
		return true
	elseif mode == "Taggers" then
		return theirRole == "TAGGER"
	elseif mode == "Survivors" then
		return theirRole == "SURVIVOR"
	elseif mode == "Selected Teams/Roles" or mode == "Listed Teams/Roles" then
		return hasListedAvoidRole(player)
	end

	local myRole = classifyPlayer(LocalPlayer)
	return myRole ~= nil and theirRole ~= nil and myRole ~= theirRole
end

local function getDistanceTo(player)
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	if not myRoot or not root then
		return nil
	end

	return (myRoot.Position - root.Position).Magnitude
end

local function getRoleColor(role, player)
	if state.espUseCustomTeamColors then
		for _, raw in ipairs(collectRoles(player)) do
			local color = state.teamColors[normalize(raw)]
			if color then
				return color
			end
		end
	end

	return state.espColors[role] or state.espColors.UNKNOWN
end

local function getDisplayName(player)
	if state.espNameMode == "Username" then
		return player.Name
	elseif state.espNameMode == "Both" and player.DisplayName ~= player.Name then
		return player.DisplayName .. " @" .. player.Name
	end

	return player.DisplayName or player.Name
end

local function formatESPText(player, role, distance, humanoid)
	local parts = { getDisplayName(player) }

	if state.espShowRole then
		table.insert(parts, role)
	end

	if state.espShowDistance and distance then
		table.insert(parts, tostring(math.floor(distance + 0.5)) .. state.espDistanceSuffix)
	end

	if state.espShowHealth and humanoid then
		table.insert(parts, tostring(math.floor(humanoid.Health + 0.5)) .. "hp")
	end

	return table.concat(parts, state.espSeparator)
end

local function getESPFolder()
	if state.espFolder and state.espFolder.Parent then
		return state.espFolder
	end

	local parent = getGuiParent()
	local old = parent:FindFirstChild(ESP_FOLDER_NAME)
	if old then
		old:Destroy()
	end

	state.espFolder = create("Folder", {
		Name = ESP_FOLDER_NAME,
		Parent = parent,
	})

	return state.espFolder
end

local function cleanupESPPlayer(player)
	local objects = state.espObjects[player]
	if not objects then
		return
	end

	for _, object in pairs(objects) do
		if object and object.Parent then
			object:Destroy()
		end
	end

	state.espObjects[player] = nil
end

local function cleanupAllESP()
	for player in pairs(state.espObjects) do
		cleanupESPPlayer(player)
	end

	if state.espFolder and state.espFolder.Parent then
		state.espFolder:Destroy()
	end

	state.espFolder = nil
end

local function shouldShowESP(player, role, distance)
	if player == LocalPlayer then
		return false
	end

	if not state.espEnabled then
		return false
	end

	if state.espMaxDistance > 0 and distance and distance > state.espMaxDistance then
		return false
	end

	if role == "TAGGER" then
		return state.espShowTaggers
	elseif role == "SURVIVOR" then
		return state.espShowSurvivors
	end

	return state.espShowUnknown
end

local function ensureESP(player)
	local character = player.Character
	local root, humanoid = getRootAndHumanoid(player)
	local head = character and (character:FindFirstChild("Head") or root or character:FindFirstChildWhichIsA("BasePart"))

	if not character or not root or not humanoid or humanoid.Health <= 0 or not head then
		cleanupESPPlayer(player)
		return
	end

	local role = classifyPlayer(player) or "UNKNOWN"
	local distance = getDistanceTo(player)

	if not shouldShowESP(player, role, distance) then
		cleanupESPPlayer(player)
		return
	end

	local color = getRoleColor(role, player)
	local folder = getESPFolder()
	local objects = state.espObjects[player]
	if not objects then
		objects = {}
		state.espObjects[player] = objects
	end

	if state.espHighlights then
		local highlight = objects.highlight
		if not highlight or not highlight.Parent then
			highlight = create("Highlight", {
				Name = "BaconHubESPHighlight",
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				Parent = folder,
			})
			objects.highlight = highlight
		end

		highlight.Adornee = character
		highlight.Enabled = true
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = math.clamp(state.espFillTransparency, 0, 1)
		highlight.OutlineTransparency = math.clamp(state.espOutlineTransparency, 0, 1)
	elseif objects.highlight then
		objects.highlight:Destroy()
		objects.highlight = nil
	end

	if state.espLabels then
		local billboard = objects.billboard
		if not billboard or not billboard.Parent then
			billboard = create("BillboardGui", {
				Name = "BaconHubESPLabel",
				AlwaysOnTop = true,
				Parent = folder,
			})

			create("TextLabel", {
				Name = "Text",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamBold,
				TextStrokeTransparency = 0.15,
				TextStrokeColor3 = Color3.new(0, 0, 0),
				Parent = billboard,
			})

			objects.billboard = billboard
		end

		local text = billboard:FindFirstChild("Text")
		billboard.Adornee = head
		billboard.Enabled = true
		billboard.Size = UDim2.fromOffset(state.espLabelWidth, state.espLabelHeight)
		billboard.StudsOffset = Vector3.new(0, state.espLabelYOffset, 0)

		if text then
			text.Text = formatESPText(player, role, distance, humanoid)
			text.TextColor3 = color
			text.TextSize = state.espLabelSize
		end
	elseif objects.billboard then
		objects.billboard:Destroy()
		objects.billboard = nil
	end

	if not objects.highlight and not objects.billboard then
		state.espObjects[player] = nil
	end
end

local function refreshAllESP()
	local present = {}

	for _, player in ipairs(Players:GetPlayers()) do
		present[player] = true
		ensureESP(player)
	end

	for player in pairs(state.espObjects) do
		if not present[player] then
			cleanupESPPlayer(player)
		end
	end
end

local function cleanupHitboxPlayer(player)
	local character = player and player.Character
	if character then
		for _, instance in ipairs(character:GetDescendants()) do
			if OLD_HITBOX_NAMES[instance.Name] then
				instance:Destroy()
			elseif instance:IsA("BasePart") then
				instance.LocalTransparencyModifier = 0
				instance.Anchored = false

				if instance.Name == "HumanoidRootPart" then
					instance.Transparency = 1
					instance.CanCollide = false
					instance.Massless = false
					instance.Size = Vector3.new(2, 2, 1)
				end
			elseif instance:IsA("Decal") or instance:IsA("Texture") then
				instance.Transparency = 0
			end
		end
	end

	state.hitboxObjects[player] = nil
end

local function restoreHitboxCharacter(character)
	if not character then
		return
	end

	for _, instance in ipairs(character:GetDescendants()) do
		if OLD_HITBOX_NAMES[instance.Name] then
			instance:Destroy()
		elseif instance:IsA("BasePart") then
			instance.LocalTransparencyModifier = 0
			instance.Anchored = false

			if instance.Name == "HumanoidRootPart" then
				instance.Transparency = 1
				instance.CanCollide = false
				instance.Massless = false
				instance.Size = Vector3.new(2, 2, 1)
			end
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			instance.Transparency = 0
		end
	end
end

local function cleanupAllHitboxes()
	for _, player in ipairs(Players:GetPlayers()) do
		cleanupHitboxPlayer(player)
	end

	for player, hitbox in pairs(state.hitboxObjects) do
		if hitbox and hitbox.Parent then
			hitbox:Destroy()
		end

		state.hitboxObjects[player] = nil
	end
end

local function shouldHitboxPlayer(player)
	return state.hitboxEnabled and player ~= LocalPlayer
end

local function ensureHitbox(player)
	if not shouldHitboxPlayer(player) then
		cleanupHitboxPlayer(player)
		return
	end

	local character = player.Character
	local root = character and (
		character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
	)

	if not character or not root or not root:IsA("BasePart") then
		cleanupHitboxPlayer(player)
		return
	end

	local hitbox = character:FindFirstChild(HITBOX_NAME)
	if not hitbox then
		hitbox = Instance.new("Part")
		hitbox.Name = HITBOX_NAME
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		hitbox.CanQuery = true
		hitbox.Massless = true
		hitbox.CastShadow = false
		hitbox.Transparency = 1
		hitbox.Size = Vector3.new(state.hitboxSize, state.hitboxSize, state.hitboxSize)
		hitbox.Parent = character
	end

	hitbox.Size = Vector3.new(state.hitboxSize, state.hitboxSize, state.hitboxSize)
	hitbox.CFrame = root.CFrame
	hitbox.Transparency = 1
	hitbox.CanQuery = true
	hitbox.CanTouch = false
	hitbox.CanCollide = false
	hitbox.Anchored = true

	root.Anchored = false
	state.hitboxObjects[player] = hitbox
end

local function refreshHitboxes()
	for _, player in ipairs(Players:GetPlayers()) do
		if state.hitboxEnabled and player ~= LocalPlayer and player.Character and not state.hitboxObjects[player] then
			restoreHitboxCharacter(player.Character)
		end

		ensureHitbox(player)
	end
end

local function flatUnit(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return nil
	end

	return flat.Unit
end

local function signedYaw(fromDirection, toDirection)
	local from = flatUnit(fromDirection)
	local to = flatUnit(toDirection)

	if not from or not to then
		return 0
	end

	local dot = math.clamp(from:Dot(to), -1, 1)
	local cross = from:Cross(to)

	return math.atan2(cross.Y, dot)
end

local function getDashDirection(root, humanoid)
	local mode = state.dashDirectionMode
	local current = root.AssemblyLinearVelocity

	if mode == "Move Direction" and humanoid and humanoid.MoveDirection.Magnitude > 0 then
		return humanoid.MoveDirection.Unit
	elseif mode == "Camera" and Workspace.CurrentCamera then
		return flatUnit(Workspace.CurrentCamera.CFrame.LookVector)
	elseif mode == "Character Look" then
		return flatUnit(root.CFrame.LookVector)
	elseif mode == "Current Velocity" then
		local horizontal = Vector3.new(current.X, 0, current.Z)
		if horizontal.Magnitude > 2 then
			return horizontal.Unit
		end
	end

	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		return humanoid.MoveDirection.Unit
	end

	return flatUnit(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
end

local lastDashAt = 0
local function dashVelocity()
	if os.clock() - lastDashAt < state.dashCooldown then
		return
	end

	lastDashAt = os.clock()

	local root, humanoid = getRootAndHumanoid(LocalPlayer)
	if not root then
		return
	end

	local direction = getDashDirection(root, humanoid)
	if not direction then
		return
	end

	local current = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(current.X, 0, current.Z)
	local speed = state.dashPreserveFaster and math.max(horizontal.Magnitude, state.dashSpeed) or state.dashSpeed
	local boosted = direction.Unit * speed
	local yVelocity = current.Y

	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		yVelocity = math.max(yVelocity, state.dashGroundLift)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	root.AssemblyLinearVelocity = Vector3.new(boosted.X, yVelocity, boosted.Z)
end

local doubleLastVelocity = nil
local function stopDoubleSpeed()
	state.doubleActive = false
	doubleLastVelocity = nil
end

local function updateDoubleSpeed()
	local root = select(1, getRootAndHumanoid(LocalPlayer))
	if not root then
		doubleLastVelocity = nil
		return
	end

	local current = root.AssemblyLinearVelocity

	if not state.doubleEnabled or not state.doubleActive then
		doubleLastVelocity = current
		return
	end

	if not doubleLastVelocity then
		doubleLastVelocity = current
		return
	end

	local naturalChange = current - doubleLastVelocity
	local doubledVelocity = doubleLastVelocity + (naturalChange * state.doubleMultiplier)

	root.AssemblyLinearVelocity = doubledVelocity
	doubleLastVelocity = doubledVelocity
end

local function findClosestAvoidTargetToCursor()
	local camera = Workspace.CurrentCamera
	local myRoot = select(1, getRootAndHumanoid(LocalPlayer))

	if not camera or not myRoot then
		return nil
	end

	local closestPlayer = nil
	local closestCursorDistance = state.catchCursorDistance
	local cursorPosition = Vector2.new(Mouse.X, Mouse.Y)

	for _, player in ipairs(Players:GetPlayers()) do
		if shouldAvoidPlayer(player) then
			local root = select(1, getRootAndHumanoid(player))
			if root then
				local worldDistance = (root.Position - myRoot.Position).Magnitude
				if worldDistance <= state.catchTargetRadius then
					local screenPosition, onScreen = camera:WorldToViewportPoint(root.Position)
					if onScreen and screenPosition.Z > 0 then
						local cursorDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - cursorPosition).Magnitude
						if cursorDistance < closestCursorDistance then
							closestCursorDistance = cursorDistance
							closestPlayer = player
						end
					end
				end
			end
		end
	end

	return closestPlayer
end

local function stopCatching(matchTargetVelocity)
	local myRoot = select(1, getRootAndHumanoid(LocalPlayer))
	local targetRoot = state.catchTarget and select(1, getRootAndHumanoid(state.catchTarget)) or nil

	if matchTargetVelocity and myRoot and targetRoot then
		local current = myRoot.AssemblyLinearVelocity
		local target = targetRoot.AssemblyLinearVelocity
		myRoot.AssemblyLinearVelocity = current:Lerp(target, 0.65)
	end

	state.catching = false
	state.catchTarget = nil
	state.catchStartedAt = 0
end

local function startCatching()
	if not state.catchEnabled then
		return
	end

	state.catchTarget = findClosestAvoidTargetToCursor()
	state.catching = state.catchTarget ~= nil
	state.catchStartedAt = state.catching and os.clock() or 0
end

local function moveToward(current, target, maxDelta)
	local delta = target - current
	local distance = delta.Magnitude

	if distance <= maxDelta or distance <= 0 then
		return target
	end

	return current + (delta.Unit * maxDelta)
end

local function updateCatching(dt)
	if not state.catchEnabled or not state.catching or not state.catchTarget then
		return
	end

	if os.clock() - state.catchStartedAt >= state.catchTimeout then
		stopCatching(false)
		return
	end

	local myRoot, myHumanoid = getRootAndHumanoid(LocalPlayer)
	local targetRoot, targetHumanoid = getRootAndHumanoid(state.catchTarget)

	if not myRoot or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 or not shouldAvoidPlayer(state.catchTarget) then
		stopCatching(false)
		return
	end

	if (targetRoot.Position - myRoot.Position).Magnitude > state.catchTargetRadius + 25 then
		stopCatching(false)
		return
	end

	local offset = targetRoot.Position - myRoot.Position
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	local distance = flatOffset.Magnitude

	if distance <= state.catchCloseDistance then
		stopCatching(state.catchMatchVelocity)
		return
	end

	if distance <= 0 then
		return
	end

	local direction = flatOffset.Unit
	local targetVelocity = targetRoot.AssemblyLinearVelocity
	local currentVelocity = myRoot.AssemblyLinearVelocity
	local approachRatio = math.clamp((distance - state.catchCloseDistance) / state.catchSoftenDistance, 0, 1)
	local extraSpeed = state.catchMinExtraSpeed + ((state.catchMaxExtraSpeed - state.catchMinExtraSpeed) * approachRatio)
	local targetHorizontal = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
	local desiredHorizontal = targetHorizontal + (direction * extraSpeed)
	local currentHorizontal = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
	local newHorizontal = moveToward(currentHorizontal, desiredHorizontal, state.catchAcceleration * dt)
	local yVelocity = currentVelocity.Y

	if myHumanoid and myHumanoid.FloorMaterial ~= Enum.Material.Air then
		yVelocity = math.max(yVelocity, state.catchGroundLift)
		myHumanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	myRoot.AssemblyLinearVelocity = Vector3.new(newHorizontal.X, yVelocity, newHorizontal.Z)
end

local function getNearbyAvoidTargets(myRoot)
	local targets = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if shouldAvoidPlayer(player) then
			local root = select(1, getRootAndHumanoid(player))
			if root then
				local offset = root.Position - myRoot.Position
				local flatOffset = Vector3.new(offset.X, 0, offset.Z)
				local distance = flatOffset.Magnitude

				if distance <= state.dodgeEnemyRadius and distance > 0.001 then
					table.insert(targets, {
						direction = flatOffset.Unit,
						distance = distance,
					})
				end
			end
		end
	end

	return targets
end

local function chooseLeastCrowdedDirection(myRoot)
	local camera = Workspace.CurrentCamera
	local baseDirection = camera and flatUnit(camera.CFrame.LookVector) or flatUnit(myRoot.CFrame.LookVector)

	if not baseDirection then
		baseDirection = Vector3.new(0, 0, -1)
	end

	local targets = getNearbyAvoidTargets(myRoot)
	if #targets == 0 then
		return baseDirection
	end

	local bestDirection = baseDirection
	local bestScore = math.huge
	local bestTurn = math.huge
	local sectorCount = math.max(8, math.floor(state.dodgeSectorCount))
	local avoidCone = math.rad(state.dodgeAvoidCone)

	for index = 0, sectorCount - 1 do
		local angle = (index / sectorCount) * math.pi * 2
		local candidate = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angle):VectorToWorldSpace(baseDirection)
		candidate = flatUnit(candidate) or baseDirection

		local score = 0
		for _, target in ipairs(targets) do
			local dot = math.clamp(candidate:Dot(target.direction), -1, 1)
			local angleToTarget = math.acos(dot)

			if angleToTarget <= avoidCone then
				local distanceWeight = 1 - math.clamp(target.distance / state.dodgeEnemyRadius, 0, 1)
				local angleWeight = 1 - (angleToTarget / avoidCone)
				score = score + 1 + (distanceWeight * 0.75) + (angleWeight * 0.5)
			end
		end

		local turnAmount = math.abs(signedYaw(baseDirection, candidate))
		local finalScore = score + (turnAmount * 0.08)

		if finalScore < bestScore or (math.abs(finalScore - bestScore) < 0.001 and turnAmount < bestTurn) then
			bestScore = finalScore
			bestTurn = turnAmount
			bestDirection = candidate
		end
	end

	return bestDirection
end

local function expEaseOut(alpha)
	alpha = math.clamp(alpha, 0, 1)
	if alpha >= 1 then
		return 1
	end

	local strength = 7
	return (1 - math.exp(-strength * alpha)) / (1 - math.exp(-strength))
end

local function turnCameraHorizontally(targetDirection)
	if not state.dodgeCameraTurn then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	pcall(function()
		RunService:UnbindFromRenderStep(CAMERA_TURN_BIND)
	end)

	local startTime = os.clock()
	local startDirection = flatUnit(camera.CFrame.LookVector) or targetDirection
	local startPitchY = math.clamp(camera.CFrame.LookVector.Y, -0.92, 0.92)

	RunService:BindToRenderStep(CAMERA_TURN_BIND, Enum.RenderPriority.Camera.Value + 3, function()
		local currentCamera = Workspace.CurrentCamera
		if not currentCamera then
			RunService:UnbindFromRenderStep(CAMERA_TURN_BIND)
			return
		end

		local alpha = math.clamp((os.clock() - startTime) / state.dodgeCameraTurnTime, 0, 1)
		local smoothAlpha = expEaseOut(alpha)
		local flatLook = startDirection:Lerp(targetDirection, smoothAlpha)
		if flatLook.Magnitude <= 0.001 then
			flatLook = targetDirection
		end

		flatLook = flatLook.Unit

		local horizontalScale = math.sqrt(math.max(0.01, 1 - (startPitchY * startPitchY)))
		local look = Vector3.new(flatLook.X * horizontalScale, startPitchY, flatLook.Z * horizontalScale).Unit
		local position = currentCamera.CFrame.Position

		currentCamera.CFrame = CFrame.lookAt(position, position + look)

		if state.dodgeMouseTurn and typeof(mousemoverel) == "function" then
			local errorYaw = signedYaw(currentCamera.CFrame.LookVector, targetDirection)
			if math.abs(errorYaw) > math.rad(1.25) then
				mousemoverel(math.clamp(-errorYaw * 220, -18, 18), 0)
			end
		end

		if alpha >= 1 then
			RunService:UnbindFromRenderStep(CAMERA_TURN_BIND)
		end
	end)
end

local function boostDodge(direction)
	local root = select(1, getRootAndHumanoid(LocalPlayer))
	if not root then
		return
	end

	local current = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(current.X, 0, current.Z)
	local targetSpeed = math.clamp(
		math.max(horizontal.Magnitude + state.dodgeBoostAddSpeed, state.dodgeBoostMinSpeed),
		0,
		state.dodgeBoostMaxSpeed
	)
	local boosted = direction.Unit * targetSpeed

	root.AssemblyLinearVelocity = Vector3.new(boosted.X, current.Y, boosted.Z)
end

local function dodgeCrowd()
	if not state.dodgeEnabled then
		return
	end

	local root = select(1, getRootAndHumanoid(LocalPlayer))
	if not root then
		return
	end

	local direction = chooseLeastCrowdedDirection(root)
	turnCameraHorizontally(direction)
	boostDodge(direction)
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

function state:Cleanup()
	stopCatching(false)
	stopDoubleSpeed()
	cleanupAllESP()
	cleanupAllHitboxes()
	disconnectAll(self.connections)

	pcall(function()
		RunService:UnbindFromRenderStep(CAMERA_TURN_BIND)
	end)

	if self.rayfield and self.rayfield.Destroy then
		pcall(function()
			self.rayfield:Destroy()
		end)
	end

	if ENV[GLOBAL_KEY] == self then
		ENV[GLOBAL_KEY] = nil
	end
end

table.insert(state.connections, Players.PlayerRemoving:Connect(function(player)
	cleanupESPPlayer(player)
	cleanupHitboxPlayer(player)
end))

local lastESPRefresh = 0
local lastTeamDropdownRefresh = 0
table.insert(state.connections, RunService.RenderStepped:Connect(function()
	local now = os.clock()

	if now - lastTeamDropdownRefresh >= 2 then
		lastTeamDropdownRefresh = now
		refreshTeamDropdowns(false)
	end

	if state.espEnabled and now - lastESPRefresh >= state.espUpdateInterval then
		lastESPRefresh = now
		refreshAllESP()
	end

	if state.hitboxEnabled then
		refreshHitboxes()
	end
end))

table.insert(state.connections, RunService.Heartbeat:Connect(function(dt)
	updateDoubleSpeed()
	updateCatching(dt)
end))

table.insert(state.connections, GuiService.ErrorMessageChanged:Connect(function()
	if not state.autoRejoin or autoRejoinRunning then
		return
	end

	local errorCode = GuiService:GetErrorCode()
	local errorType = GuiService:GetErrorType()
	if errorType == Enum.ConnectionError.DisconnectErrors and not reconnectDisabledList[errorCode] then
		autoRejoinRunning = true
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
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "untitled tag game",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "UntitledTagGame",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local EspTab = Window:CreateTab("ESP", 0)
local HitboxTab = Window:CreateTab("Hitbox", 0)
local MovementTab = Window:CreateTab("Movement", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

EspTab:CreateSection("General")

createParagraph(EspTab, {
	Title = "Player ESP",
	Content = "Highlights and labels players based on the team and role setup in the Teams tab.",
})

EspTab:CreateToggle({
	Name = "ESP Enabled",
	CurrentValue = state.espEnabled,
	Flag = "ESPEnabled",
	Callback = function(value)
		state.espEnabled = value
		if value then
			refreshAllESP()
		else
			cleanupAllESP()
		end
	end,
})

EspTab:CreateToggle({
	Name = "Highlights",
	CurrentValue = state.espHighlights,
	Flag = "ESPHighlights",
	Callback = function(value)
		state.espHighlights = value
		refreshAllESP()
	end,
})

EspTab:CreateToggle({
	Name = "Labels",
	CurrentValue = state.espLabels,
	Flag = "ESPLabels",
	Callback = function(value)
		state.espLabels = value
		refreshAllESP()
	end,
})

EspTab:CreateToggle({
	Name = "Show Taggers",
	CurrentValue = state.espShowTaggers,
	Flag = "ESPShowTaggers",
	Callback = function(value)
		state.espShowTaggers = value
		refreshAllESP()
	end,
})

EspTab:CreateToggle({
	Name = "Show Survivors",
	CurrentValue = state.espShowSurvivors,
	Flag = "ESPShowSurvivors",
	Callback = function(value)
		state.espShowSurvivors = value
		refreshAllESP()
	end,
})

EspTab:CreateToggle({
	Name = "Show Unknown Roles",
	CurrentValue = state.espShowUnknown,
	Flag = "ESPShowUnknown",
	Callback = function(value)
		state.espShowUnknown = value
		refreshAllESP()
	end,
})

EspTab:CreateSection("Labels")

EspTab:CreateDropdown({
	Name = "Name Mode",
	Options = { "Display Name", "Username", "Both" },
	CurrentOption = { state.espNameMode },
	MultipleOptions = false,
	Flag = "ESPNameMode",
	Callback = function(value)
		state.espNameMode = getDropdownValue(value, "Display Name")
		refreshAllESP()
	end,
})

EspTab:CreateToggle({
	Name = "Show Role",
	CurrentValue = state.espShowRole,
	Flag = "ESPShowRole",
	Callback = function(value)
		state.espShowRole = value
		refreshAllESP()
	end,
})

EspTab:CreateToggle({
	Name = "Show Distance",
	CurrentValue = state.espShowDistance,
	Flag = "ESPShowDistance",
	Callback = function(value)
		state.espShowDistance = value
		refreshAllESP()
	end,
})

EspTab:CreateToggle({
	Name = "Show Health",
	CurrentValue = state.espShowHealth,
	Flag = "ESPShowHealth",
	Callback = function(value)
		state.espShowHealth = value
		refreshAllESP()
	end,
})

EspTab:CreateSection("Visuals")

EspTab:CreateColorPicker({
	Name = "Tagger Color",
	Color = state.espColors.TAGGER,
	Flag = "ESPTaggerColor",
	Callback = function(value)
		state.espColors.TAGGER = value
		refreshAllESP()
	end,
})

EspTab:CreateColorPicker({
	Name = "Survivor Color",
	Color = state.espColors.SURVIVOR,
	Flag = "ESPSurvivorColor",
	Callback = function(value)
		state.espColors.SURVIVOR = value
		refreshAllESP()
	end,
})

EspTab:CreateColorPicker({
	Name = "Unknown Color",
	Color = state.espColors.UNKNOWN,
	Flag = "ESPUnknownColor",
	Callback = function(value)
		state.espColors.UNKNOWN = value
		refreshAllESP()
	end,
})

EspTab:CreateSlider({
	Name = "Fill Transparency",
	Range = { 0, 1 },
	Increment = 0.05,
	CurrentValue = state.espFillTransparency,
	Flag = "ESPFillTransparency",
	Callback = function(value)
		state.espFillTransparency = value
		refreshAllESP()
	end,
})

EspTab:CreateSlider({
	Name = "Outline Transparency",
	Range = { 0, 1 },
	Increment = 0.05,
	CurrentValue = state.espOutlineTransparency,
	Flag = "ESPOutlineTransparency",
	Callback = function(value)
		state.espOutlineTransparency = value
		refreshAllESP()
	end,
})

EspTab:CreateSlider({
	Name = "Max Distance",
	Range = { 0, 5000 },
	Increment = 50,
	Suffix = " studs",
	CurrentValue = state.espMaxDistance,
	Flag = "ESPMaxDistance",
	Callback = function(value)
		state.espMaxDistance = value
		refreshAllESP()
	end,
})

HitboxTab:CreateSection("Hitbox Extender")

createParagraph(HitboxTab, {
	Title = "Original Behavior",
	Content = "Creates an invisible query-only cube on every other player and keeps it locked to their root part.",
})

HitboxTab:CreateToggle({
	Name = "Hitbox Extender",
	CurrentValue = state.hitboxEnabled,
	Flag = "HitboxEnabled",
	Callback = function(value)
		state.hitboxEnabled = value
		if value then
			refreshHitboxes()
		else
			cleanupAllHitboxes()
		end
	end,
})

HitboxTab:CreateSlider({
	Name = "Hitbox Size",
	Range = { 2, 30 },
	Increment = 0.5,
	CurrentValue = state.hitboxSize,
	Flag = "HitboxSize",
	Callback = function(value)
		state.hitboxSize = value
	end,
})

HitboxTab:CreateButton({
	Name = "Clear Hitboxes",
	Callback = function()
		cleanupAllHitboxes()
		notify("Hitbox", "Cleared.")
	end,
})

MovementTab:CreateSection("Dash")

createParagraph(MovementTab, {
	Title = "Dash",
	Content = "Applies one quick velocity burst in the selected direction.",
})

MovementTab:CreateButton({
	Name = "Dash Now",
	Callback = dashVelocity,
})

MovementTab:CreateKeybind({
	Name = "Dash Keybind",
	CurrentKeybind = "F",
	HoldToInteract = false,
	Flag = "DashKeybind",
	Callback = dashVelocity,
})

MovementTab:CreateDropdown({
	Name = "Dash Direction",
	Options = { "Current Velocity", "Move Direction", "Camera", "Character Look" },
	CurrentOption = { state.dashDirectionMode },
	MultipleOptions = false,
	Flag = "DashDirection",
	Callback = function(value)
		state.dashDirectionMode = getDropdownValue(value, "Current Velocity")
	end,
})

MovementTab:CreateToggle({
	Name = "Preserve Faster Speed",
	CurrentValue = state.dashPreserveFaster,
	Flag = "DashPreserveFaster",
	Callback = function(value)
		state.dashPreserveFaster = value
	end,
})

MovementTab:CreateSlider({
	Name = "Dash Speed",
	Range = { 20, 500 },
	Increment = 5,
	CurrentValue = state.dashSpeed,
	Flag = "DashSpeed",
	Callback = function(value)
		state.dashSpeed = value
	end,
})

MovementTab:CreateSlider({
	Name = "Ground Lift",
	Range = { 0, 80 },
	Increment = 1,
	CurrentValue = state.dashGroundLift,
	Flag = "DashGroundLift",
	Callback = function(value)
		state.dashGroundLift = value
	end,
})

createDivider(MovementTab)
MovementTab:CreateSection("Velocity Doubler")

createParagraph(MovementTab, {
	Title = "Velocity Doubler",
	Content = "When active, keeps amplifying natural movement changes for faster acceleration.",
})

MovementTab:CreateToggle({
	Name = "Velocity Doubler",
	CurrentValue = state.doubleEnabled,
	Flag = "VelocityDoubler",
	Callback = function(value)
		state.doubleEnabled = value
		if not value then
			stopDoubleSpeed()
		end
	end,
})

MovementTab:CreateKeybind({
	Name = "Toggle Double Speed",
	CurrentKeybind = "R",
	HoldToInteract = false,
	Flag = "ToggleDoubleSpeedKeybind",
	Callback = function()
		if not state.doubleEnabled then
			return
		end

		state.doubleActive = not state.doubleActive
		local root = select(1, getRootAndHumanoid(LocalPlayer))
		doubleLastVelocity = root and root.AssemblyLinearVelocity or nil
		notify("Velocity Doubler", state.doubleActive and "Active" or "Stopped")
	end,
})

MovementTab:CreateSlider({
	Name = "Double Multiplier",
	Range = { 1, 5 },
	Increment = 0.1,
	CurrentValue = state.doubleMultiplier,
	Flag = "DoubleMultiplier",
	Callback = function(value)
		state.doubleMultiplier = value
	end,
})

MovementTab:CreateButton({
	Name = "Stop Double Speed",
	Callback = function()
		stopDoubleSpeed()
		notify("Velocity Doubler", "Stopped.")
	end,
})

createDivider(MovementTab)
MovementTab:CreateSection("Tag Dash")

createParagraph(MovementTab, {
	Title = "Tag Dash",
	Content = "Dashes toward the avoid target closest to your cursor. Configure targets in the Teams tab.",
})

MovementTab:CreateToggle({
	Name = "Tag Dash",
	CurrentValue = state.catchEnabled,
	Flag = "TagDash",
	Callback = function(value)
		state.catchEnabled = value
		if not value then
			stopCatching(false)
		end
	end,
})

MovementTab:CreateButton({
	Name = "Tag Dash Now",
	Callback = startCatching,
})

MovementTab:CreateKeybind({
	Name = "Tag Dash Keybind",
	CurrentKeybind = "G",
	HoldToInteract = false,
	Flag = "TagDashKeybind",
	Callback = startCatching,
})

MovementTab:CreateSlider({
	Name = "Target Range",
	Range = { 20, 400 },
	Increment = 5,
	Suffix = " studs",
	CurrentValue = state.catchTargetRadius,
	Flag = "TagDashTargetRange",
	Callback = function(value)
		state.catchTargetRadius = value
	end,
})

MovementTab:CreateSlider({
	Name = "Dash Strength",
	Range = { 50, 500 },
	Increment = 5,
	CurrentValue = state.catchMaxExtraSpeed,
	Flag = "TagDashStrength",
	Callback = function(value)
		state.catchMaxExtraSpeed = value
		state.catchMinExtraSpeed = math.max(0, math.floor(value * 0.2))
	end,
})

MovementTab:CreateSlider({
	Name = "Duration",
	Range = { 0.25, 8 },
	Increment = 0.25,
	Suffix = "s",
	CurrentValue = state.catchTimeout,
	Flag = "TagDashDuration",
	Callback = function(value)
		state.catchTimeout = value
	end,
})

createDivider(MovementTab)
MovementTab:CreateSection("Evasive Dash")

createParagraph(MovementTab, {
	Title = "Evasive Dash",
	Content = "Finds the least crowded direction away from avoid targets, turns the camera, and boosts that way.",
})

MovementTab:CreateToggle({
	Name = "Evasive Dash",
	CurrentValue = state.dodgeEnabled,
	Flag = "EvasiveDash",
	Callback = function(value)
		state.dodgeEnabled = value
	end,
})

MovementTab:CreateButton({
	Name = "Evasive Dash Now",
	Callback = dodgeCrowd,
})

MovementTab:CreateKeybind({
	Name = "Evasive Dash Keybind",
	CurrentKeybind = "V",
	HoldToInteract = false,
	Flag = "EvasiveDashKeybind",
	Callback = dodgeCrowd,
})

MovementTab:CreateSlider({
	Name = "Avoid Range",
	Range = { 20, 400 },
	Increment = 5,
	Suffix = " studs",
	CurrentValue = state.dodgeEnemyRadius,
	Flag = "EvasiveAvoidRange",
	Callback = function(value)
		state.dodgeEnemyRadius = value
	end,
})

MovementTab:CreateSlider({
	Name = "Dash Strength",
	Range = { 30, 400 },
	Increment = 5,
	CurrentValue = state.dodgeBoostMaxSpeed,
	Flag = "EvasiveDashStrength",
	Callback = function(value)
		state.dodgeBoostMaxSpeed = value
		state.dodgeBoostAddSpeed = math.max(0, math.floor(value * 0.45))
		state.dodgeBoostMinSpeed = math.max(10, math.floor(value * 0.6))
	end,
})

SettingsTab:CreateSection("Connection")

SettingsTab:CreateToggle({
	Name = "Auto Rejoin",
	CurrentValue = state.autoRejoin,
	Flag = "AutoRejoin",
	Callback = function(value)
		state.autoRejoin = value
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

SettingsTab:CreateSection("Session")

SettingsTab:CreateButton({
	Name = "Unload GUI",
	Callback = function()
		state:Cleanup()
	end,
})

Rayfield:LoadConfiguration()
refreshTeamDropdowns(true)
refreshAllESP()
notify("BaconHub", "untitled tag game loaded. Press K to toggle the GUI.")
