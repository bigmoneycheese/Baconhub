local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Session = {}
_G.BaconHubSlapSession = Session

local state = {
	autoDodge = false,
	autoSkillcheck = false,
	autoSlap = false,
	autoAbility = false,
	autoAbilityDodge = false,
	autoPlay = false,
	autoRejoin = false,
	antiAfk = false,
	dodgeRange = 15,
	feintChance = 45,
	autoPlayLobbyDelay = 3,
	autoPlayCycleDelay = 5,
}

_G.BaconHubAbilityBusy = false
_G.BaconHubSkillcheckBusy = false

local Window = Rayfield:CreateWindow({
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "SLAP",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "Slap",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local CombatTab = Window:CreateTab("Combat", 0)
local QueueTab = Window:CreateTab("Queue", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

local function isAlive()
	return _G.BaconHubSlapSession == Session
end

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
	if not isAlive() or not state.autoRejoin or autoRejoinRunning then
		return
	end

	local errorCode = GuiService:GetErrorCode()
	local errorType = GuiService:GetErrorType()
	if errorType == Enum.ConnectionError.DisconnectErrors and not reconnectDisabledList[errorCode] then
		autoRejoinRunning = true
		print("Disconnect registered!")
		while isAlive() and state.autoRejoin and task.wait(5) do
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end
	end
end)

LocalPlayer.Idled:Connect(function()
	if not isAlive() or not state.antiAfk then
		return
	end

	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

local function getMousePoint()
	local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(960, 540)
	return math.floor(viewport.X / 2), math.floor(viewport.Y / 2)
end

local function sendMouseButton(button)
	local x, y = getMousePoint()
	VirtualInputManager:SendMouseButtonEvent(x, y, button, true, game, 0)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, button, false, game, 0)
end

local function getChildPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end

	return current
end

local function getSlapGameUI()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	return playerGui and playerGui:FindFirstChild("SlapGameUI") or nil
end

local function isChainVisible(guiObject, stopAt)
	if not guiObject or not guiObject:IsA("GuiObject") or not guiObject.Visible then
		return false
	end

	local current = guiObject.Parent
	while current and current ~= stopAt do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end

	return true
end

local function getBattleContainer()
	local slapGameUI = getSlapGameUI()
	if not slapGameUI then
		return nil
	end

	for _, hudName in ipairs({ "InGameHUD", "InGameHUD_Mobile" }) do
		local hud = slapGameUI:FindFirstChild(hudName)
		local battleOptions = hud and hud:FindFirstChild("BattleOptions")
		local container = battleOptions and battleOptions:FindFirstChild("Container")
		if container and container.Visible then
			return container
		end
	end

	return nil
end

local function getLabelText(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end

	return current and current:IsA("TextLabel") and current.Text or ""
end

local function getNumberText(text)
	return tonumber((text or ""):match("%d+")) or 0
end

local BODY_PART_NAMES = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local FACING_DOT = 0.45
local HIGHLIGHT_MEMORY = 0.18
local DODGE_COOLDOWN = 4.05
local lastDodgeAt = 0
local trackedPlayers = {}

local function isIgnoredFakeHitColor(color)
	local minChannel = math.min(color.R, color.G, color.B)
	local maxChannel = math.max(color.R, color.G, color.B)

	if minChannel >= 0.85 and maxChannel - minChannel <= 0.12 then
		return true
	end

	local isYellow = color.R >= 0.7 and color.G >= 0.55 and color.B <= 0.35
	local isGreen = color.G >= 0.55 and color.R <= 0.55 and color.B <= 0.55

	return isYellow or isGreen
end

local function getRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isFacingLocal(attackerRoot, localRoot)
	local toLocal = localRoot.Position - attackerRoot.Position
	if toLocal.Magnitude <= 0 then
		return false
	end

	return attackerRoot.CFrame.LookVector:Dot(toLocal.Unit) >= FACING_DOT
end

local function sendDodgeClick()
	local now = Workspace:GetServerTimeNow()
	if now - lastDodgeAt < DODGE_COOLDOWN then
		return
	end

	lastDodgeAt = now
	sendMouseButton(0)
end

local function canDodgePlayer(player)
	if not state.autoDodge or player == LocalPlayer then
		return false
	end

	local localRoot = getRoot(LocalPlayer.Character)
	local attackerRoot = getRoot(player.Character)
	if not localRoot or not attackerRoot then
		return false
	end

	if (localRoot.Position - attackerRoot.Position).Magnitude > state.dodgeRange then
		return false
	end

	return isFacingLocal(attackerRoot, localRoot)
end

local function isHighlightPart(instance, character)
	if not instance:IsA("BasePart") or not BODY_PART_NAMES[instance.Name] then
		return false
	end

	if isIgnoredFakeHitColor(instance.Color) then
		return false
	end

	local parent = instance.Parent
	return parent and parent:IsA("BasePart") and parent.Parent == character and parent.Name == instance.Name
end

local function markRealHit(player)
	local playerState = trackedPlayers[player]
	if playerState then
		playerState.highlightUntil = os.clock() + HIGHLIGHT_MEMORY

		if canDodgePlayer(player) then
			sendDodgeClick()
		end
	end
end

local function hookCharacter(player, character)
	trackedPlayers[player] = {
		highlightUntil = 0,
	}

	for _, descendant in ipairs(character:GetDescendants()) do
		if isHighlightPart(descendant, character) then
			markRealHit(player)
		end
	end

	character.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			if isAlive() and descendant.Parent and isHighlightPart(descendant, character) then
				markRealHit(player)
			end
		end)
	end)
end

local function hookPlayer(player)
	if player.Character then
		hookCharacter(player, player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		if isAlive() then
			hookCharacter(player, character)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(player)
	trackedPlayers[player] = nil
end)

RunService.Heartbeat:Connect(function()
	if not isAlive() or not state.autoDodge then
		return
	end

	local now = os.clock()
	for player, playerState in pairs(trackedPlayers) do
		if now <= (playerState.highlightUntil or 0) and canDodgePlayer(player) then
			sendDodgeClick()
		end
	end
end)

local SUCCESS_START_OFFSET = 4
local SUCCESS_END_OFFSET = 34
local PRESS_OFFSET = 24
local PRESS_TOLERANCE = 5
local PRESS_DEBOUNCE = 0.12
local lastSkillcheckPressAt = 0
local lastTargetRotation = nil
local lastSkillcheckVisible = false

local function getQTEFrames()
	local slapGameUI = getSlapGameUI()
	if not slapGameUI then
		return {}
	end

	local frames = {}
	for _, hudName in ipairs({ "InGameHUD", "InGameHUD_Mobile" }) do
		local hud = slapGameUI:FindFirstChild(hudName)
		local qte = hud and hud:FindFirstChild("QuickTimeEvent")
		local container = qte and qte:FindFirstChild("Container")
		local indicator = container and container:FindFirstChild("Indicator")
		local target = container and container:FindFirstChild("Target")

		if qte and container and indicator and target then
			table.insert(frames, {
				qte = qte,
				container = container,
				indicator = indicator,
				target = target,
			})
		end
	end

	return frames
end

local function getActiveQTE()
	for _, frame in ipairs(getQTEFrames()) do
		if frame.qte.Visible and frame.container.Visible then
			return frame
		end
	end

	return nil
end

local function circularDistance(a, b)
	local difference = (a - b + 180) % 360 - 180
	return math.abs(difference)
end

local function isInsideArc(value, startAngle, endAngle)
	value = value % 360
	startAngle = startAngle % 360
	endAngle = endAngle % 360

	if startAngle <= endAngle then
		return value >= startAngle and value <= endAngle
	end

	return value >= startAngle or value <= endAngle
end

local function pressSkillcheck()
	local now = os.clock()
	if now - lastSkillcheckPressAt < PRESS_DEBOUNCE then
		return
	end

	lastSkillcheckPressAt = now
	sendMouseButton(0)
end

RunService.Heartbeat:Connect(function()
	if not isAlive() or not state.autoSkillcheck then
		_G.BaconHubSkillcheckBusy = false
		return
	end

	local frame = getActiveQTE()
	if not frame then
		lastSkillcheckVisible = false
		lastTargetRotation = nil
		_G.BaconHubSkillcheckBusy = false
		return
	end

	_G.BaconHubSkillcheckBusy = true

	if not lastSkillcheckVisible then
		lastSkillcheckVisible = true
		lastTargetRotation = nil
	end

	local targetRotation = frame.target.Rotation % 360
	local indicatorRotation = frame.indicator.Rotation % 360
	local successStart = (targetRotation + SUCCESS_START_OFFSET) % 360
	local successEnd = (targetRotation + SUCCESS_END_OFFSET) % 360
	local pressRotation = (targetRotation + PRESS_OFFSET) % 360

	if not lastTargetRotation or circularDistance(targetRotation, lastTargetRotation) > 1 then
		lastTargetRotation = targetRotation
		lastSkillcheckPressAt = 0
	end

	if isInsideArc(indicatorRotation, successStart, successEnd) and circularDistance(indicatorRotation, pressRotation) <= PRESS_TOLERANCE then
		pressSkillcheck()
	end
end)

local TURN_REACTION_MIN = 0.08
local TURN_REACTION_MAX = 0.18
local FEINT_FOLLOWUP_DELAY = 0.28
local ACTION_DEBOUNCE = 0.55
local TURN_CHECK_DELAY = 0.05
local lastSlapActionAt = 0
local actingSlapTurn = false

local function isSlapTurn()
	if not state.autoSlap or _G.BaconHubAbilityBusy or _G.BaconHubSkillcheckBusy then
		return false
	end

	local container = getBattleContainer()
	local slap = container and container:FindFirstChild("Slap")
	if not slap or not slap.Visible then
		return false
	end

	if string.upper(getLabelText(slap, { "Contents", "Text" })) ~= "SLAP" then
		return false
	end

	local cooldown = slap:FindFirstChild("Cooldown")
	if cooldown and cooldown.Visible and tonumber(cooldown.Text) and tonumber(cooldown.Text) > 0 then
		return false
	end

	return true
end

local function canFeint()
	local container = getBattleContainer()
	local feint = container and container:FindFirstChild("Feint")
	if not feint or not feint.Visible then
		return false
	end

	local remaining = feint:FindFirstChild("Remaining")
	if remaining and remaining.Visible then
		return getNumberText(remaining.Text) > 0
	end

	return true
end

local function slap()
	lastSlapActionAt = os.clock()
	sendMouseButton(0)
end

local function feintThenSlap()
	lastSlapActionAt = os.clock()
	sendMouseButton(1)
	task.wait(FEINT_FOLLOWUP_DELAY)

	if isAlive() and isSlapTurn() then
		slap()
	end
end

local function playSlapTurn()
	while isAlive() and isSlapTurn() do
		if os.clock() - lastSlapActionAt < ACTION_DEBOUNCE then
			task.wait(TURN_CHECK_DELAY)
			continue
		end

		task.wait(TURN_REACTION_MIN + math.random() * (TURN_REACTION_MAX - TURN_REACTION_MIN))
		if not isSlapTurn() then
			break
		end

		if canFeint() and math.random(1, 100) <= state.feintChance then
			feintThenSlap()
		else
			slap()
		end

		task.wait(TURN_CHECK_DELAY)
	end
end

RunService.Heartbeat:Connect(function()
	if not isAlive() or not state.autoSlap then
		return
	end

	if isSlapTurn() and not actingSlapTurn then
		actingSlapTurn = true
		task.spawn(function()
			playSlapTurn()
			actingSlapTurn = false
		end)
	end
end)

local ABILITY_REACTION_MIN = 0.08
local ABILITY_REACTION_MAX = 0.18
local ABILITY_DEBOUNCE = 0.75
local ABILITY_MIN_LOCK_TIME = 1.25
local ABILITY_FALLBACK_LOCK_TIME = 2.5
local ABILITY_MAX_LOCK_TIME = 12
local lastAbilityAt = 0
local usingAbility = false

local function isAbilitySlapTurn()
	local container = getBattleContainer()
	local slap = container and container:FindFirstChild("Slap")
	if not slap or not slap.Visible then
		return false
	end

	return string.upper(getLabelText(slap, { "Contents", "Text" })) == "SLAP"
end

local function isAbilitySlapButtonGray()
	local container = getBattleContainer()
	local slap = container and container:FindFirstChild("Slap")
	if not slap or not slap.Visible then
		return false
	end

	local contents = slap:FindFirstChild("Contents")
	local text = contents and contents:FindFirstChild("Text")

	if slap.Active == false or slap.Interactable == false then
		return true
	end

	if contents and contents:IsA("CanvasGroup") and contents.GroupTransparency >= 0.35 then
		return true
	end

	if text and text:IsA("TextLabel") and text.TextTransparency >= 0.35 then
		return true
	end

	return false
end

local function isAbilityReady()
	local container = getBattleContainer()
	local ability = container and container:FindFirstChild("Ability")
	if not ability or not ability.Visible then
		return false
	end

	local cooldown = ability:FindFirstChild("Cooldown")
	if cooldown and cooldown.Visible then
		local remaining = tonumber(cooldown.Text)
		if remaining and remaining > 0 then
			return false
		end
	end

	return true
end

local function isAbilityCoolingDown()
	local container = getBattleContainer()
	local ability = container and container:FindFirstChild("Ability")
	local cooldown = ability and ability:FindFirstChild("Cooldown")
	if not cooldown or not cooldown.Visible then
		return false
	end

	local remaining = tonumber(cooldown.Text)
	return remaining ~= nil and remaining > 0
end

local function isAbilityQTEVisible()
	for _, frame in ipairs(getQTEFrames()) do
		if frame.qte.Visible and (not frame.container or frame.container.Visible) then
			return true
		end
	end

	return false
end

local function pressAbilityKey()
	lastAbilityAt = os.clock()
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
	task.wait()
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
end

local function holdAbilityLock()
	local startedAt = os.clock()
	local sawAbilityCue = false

	while isAlive() and state.autoAbility and os.clock() - startedAt < ABILITY_MAX_LOCK_TIME do
		local qteVisible = isAbilityQTEVisible()
		local coolingDown = isAbilityCoolingDown()
		local slapGray = isAbilitySlapButtonGray()

		if qteVisible or coolingDown or slapGray then
			sawAbilityCue = true
		end

		if os.clock() - startedAt >= ABILITY_MIN_LOCK_TIME then
			if sawAbilityCue and not qteVisible and not slapGray then
				break
			end

			if not sawAbilityCue and not isAbilitySlapTurn() and not slapGray then
				break
			end

			if not sawAbilityCue and not slapGray and os.clock() - startedAt >= ABILITY_FALLBACK_LOCK_TIME then
				break
			end
		end

		task.wait(0.05)
	end

	_G.BaconHubAbilityBusy = false
end

RunService.Heartbeat:Connect(function()
	if not isAlive() or not state.autoAbility then
		_G.BaconHubAbilityBusy = false
		return
	end

	if usingAbility or os.clock() - lastAbilityAt < ABILITY_DEBOUNCE then
		return
	end

	if not isAbilitySlapTurn() or not isAbilityReady() then
		return
	end

	usingAbility = true
	_G.BaconHubAbilityBusy = true
	task.spawn(function()
		task.wait(ABILITY_REACTION_MIN + math.random() * (ABILITY_REACTION_MAX - ABILITY_REACTION_MIN))

		if isAlive() and state.autoAbility and isAbilitySlapTurn() and isAbilityReady() then
			pressAbilityKey()
			holdAbilityLock()
		else
			_G.BaconHubAbilityBusy = false
		end

		usingAbility = false
	end)
end)

local PROMPT_READY_SCALE = 0.92
local PROMPT_CLICK_DEBOUNCE = 0.18
local clickedPrompts = {}
local lastPromptClickAt = 0

local function getPromptHuds()
	local slapGameUI = getSlapGameUI()
	if not slapGameUI then
		return {}
	end

	local huds = {}
	for _, hudName in ipairs({ "InGameHUD", "InGameHUD_Mobile" }) do
		local hud = slapGameUI:FindFirstChild(hudName)
		if hud then
			table.insert(huds, hud)
		end
	end

	return huds
end

local function isCircularSkillcheckVisible()
	for _, hud in ipairs(getPromptHuds()) do
		local qte = hud:FindFirstChild("QuickTimeEvent")
		local container = qte and qte:FindFirstChild("Container")
		if qte and qte.Visible and (not container or container.Visible) then
			return true
		end
	end

	return false
end

local function clickGuiButton(button)
	local now = os.clock()
	if now - lastPromptClickAt < PROMPT_CLICK_DEBOUNCE then
		return
	end

	lastPromptClickAt = now

	local position = button.AbsolutePosition
	local size = button.AbsoluteSize
	local x = math.floor(position.X + size.X / 2)
	local y = math.floor(position.Y + size.Y / 2)

	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function isPromptVisible(prompt, qteArea)
	return qteArea.Visible and prompt:IsA("GuiObject") and prompt.Visible
end

local function isAbilityDodgePrompt(prompt)
	return prompt:IsA("GuiObject") and string.sub(prompt.Name, 1, #"QTEAction") == "QTEAction" and prompt:FindFirstChild("QTETimer") ~= nil
end

local function isPromptReady(prompt)
	local timer = prompt:FindFirstChild("QTETimer")
	if not timer then
		return true
	end

	return timer.Size.X.Scale >= PROMPT_READY_SCALE
end

local function getPromptClickTarget(prompt)
	local button = prompt:FindFirstChild("Button")
	if button and button:IsA("GuiObject") and button.Visible then
		return button
	end

	return prompt:IsA("GuiObject") and prompt or nil
end

RunService.Heartbeat:Connect(function()
	if not isAlive() or not state.autoAbilityDodge or isCircularSkillcheckVisible() then
		return
	end

	for _, hud in ipairs(getPromptHuds()) do
		local qteArea = hud:FindFirstChild("QTEArea")
		if qteArea and qteArea.Visible then
			for _, prompt in ipairs(qteArea:GetChildren()) do
				if isAbilityDodgePrompt(prompt) and isPromptVisible(prompt, qteArea) then
					local button = getPromptClickTarget(prompt)
					if button and not clickedPrompts[prompt] and isPromptReady(prompt) then
						clickedPrompts[prompt] = true
						clickGuiButton(button)
					end
				end
			end
		end
	end

	for prompt in pairs(clickedPrompts) do
		local qteArea = prompt.Parent
		if not prompt.Parent or not qteArea:IsA("GuiObject") or not isPromptVisible(prompt, qteArea) then
			clickedPrompts[prompt] = nil
		end
	end
end)

local miscReliable = ReplicatedStorage:WaitForChild("ZAP"):WaitForChild("MISC_RELIABLE")
local playPayload = buffer.fromstring("\x02")
local lobbyPayload = buffer.fromstring("\x01")
local queuedAutoPlayCycle = false
local lastAutoPlayCycleAt = 0

local function isOutOfMatch()
	local gui = getSlapGameUI()
	if not gui then
		return false
	end

	local playButton = getChildPath(gui, { "MainContainer", "QuickAccessBar", "Container", "Play" })
	local gameResults = getChildPath(gui, { "MainContainer", "GameResults" })

	return isChainVisible(playButton, gui) or isChainVisible(gameResults, gui)
end

local function firePlay()
	miscReliable:FireServer(playPayload, {})
end

local function fireLobby()
	miscReliable:FireServer(lobbyPayload, {})
end

local function runAutoPlayCycle()
	queuedAutoPlayCycle = true
	lastAutoPlayCycleAt = os.clock()

	firePlay()
	task.wait(state.autoPlayLobbyDelay)

	if isAlive() and state.autoPlay and isOutOfMatch() then
		fireLobby()
	end

	queuedAutoPlayCycle = false
end

RunService.Heartbeat:Connect(function()
	if not isAlive() or not state.autoPlay or queuedAutoPlayCycle then
		return
	end

	if os.clock() - lastAutoPlayCycleAt < state.autoPlayCycleDelay or not isOutOfMatch() then
		return
	end

	task.spawn(runAutoPlayCycle)
end)

CombatTab:CreateSection("Defense")

CombatTab:CreateToggle({
	Name = "Auto Dodge Real Slaps",
	CurrentValue = false,
	Flag = "AutoDodge",
	Callback = function(value)
		state.autoDodge = value
		notify("Auto Dodge", value and "Enabled" or "Disabled")
	end,
})

CombatTab:CreateToggle({
	Name = "Auto Skillcheck",
	CurrentValue = false,
	Flag = "AutoSkillcheck",
	Callback = function(value)
		state.autoSkillcheck = value
		if not value then
			_G.BaconHubSkillcheckBusy = false
		end
		notify("Auto Skillcheck", value and "Enabled" or "Disabled")
	end,
})

CombatTab:CreateToggle({
	Name = "Auto Ability Dodge Prompts",
	CurrentValue = false,
	Flag = "AutoAbilityDodgePrompts",
	Callback = function(value)
		state.autoAbilityDodge = value
		notify("Ability Dodge Prompts", value and "Enabled" or "Disabled")
	end,
})

CombatTab:CreateSection("Offense")

CombatTab:CreateToggle({
	Name = "Auto Slap And Feint",
	CurrentValue = false,
	Flag = "AutoSlapAndFeint",
	Callback = function(value)
		state.autoSlap = value
		notify("Auto Slap", value and "Enabled" or "Disabled")
	end,
})

CombatTab:CreateToggle({
	Name = "Auto Use Ability",
	CurrentValue = false,
	Flag = "AutoUseAbility",
	Callback = function(value)
		state.autoAbility = value
		if not value then
			_G.BaconHubAbilityBusy = false
		end
		notify("Auto Ability", value and "Enabled" or "Disabled")
	end,
})

QueueTab:CreateSection("Matchmaking")

QueueTab:CreateToggle({
	Name = "Auto Play",
	CurrentValue = false,
	Flag = "AutoPlay",
	Callback = function(value)
		state.autoPlay = value
		queuedAutoPlayCycle = false
		notify("Auto Play", value and "Enabled" or "Disabled")
	end,
})

QueueTab:CreateButton({
	Name = "Press Play Now",
	Callback = function()
		firePlay()
		notify("Auto Play", "Sent Play.")
	end,
})

QueueTab:CreateButton({
	Name = "Press Lobby Now",
	Callback = function()
		fireLobby()
		notify("Auto Play", "Sent Lobby.")
	end,
})

SettingsTab:CreateSection("Combat Settings")

SettingsTab:CreateParagraph({
	Title = "Auto Dodge Highlight Colors",
	Content = "White, yellow, and green are ignored as fake-hit colors. Do not set your real hit highlight color to yellow or green.",
})

SettingsTab:CreateSlider({
	Name = "Dodge Range",
	Range = { 5, 35 },
	Increment = 1,
	Suffix = " studs",
	CurrentValue = state.dodgeRange,
	Flag = "DodgeRange",
	Callback = function(value)
		state.dodgeRange = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Feint Chance",
	Range = { 0, 100 },
	Increment = 5,
	Suffix = "%",
	CurrentValue = state.feintChance,
	Flag = "FeintChance",
	Callback = function(value)
		state.feintChance = value
	end,
})

SettingsTab:CreateSection("Queue Settings")

SettingsTab:CreateSlider({
	Name = "Lobby Delay",
	Range = { 1, 10 },
	Increment = 0.5,
	Suffix = "s",
	CurrentValue = state.autoPlayLobbyDelay,
	Flag = "AutoPlayLobbyDelay",
	Callback = function(value)
		state.autoPlayLobbyDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Cycle Delay",
	Range = { 2, 15 },
	Increment = 0.5,
	Suffix = "s",
	CurrentValue = state.autoPlayCycleDelay,
	Flag = "AutoPlayCycleDelay",
	Callback = function(value)
		state.autoPlayCycleDelay = value
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
notify("BaconHub", "SLAP loaded. Press K to toggle the GUI.")
