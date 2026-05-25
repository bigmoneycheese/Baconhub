local ENV = (typeof(getgenv) == "function" and getgenv()) or _G
local GUI_KEY = "BaconHub_BBQItGui"

local oldSession = ENV[GUI_KEY]
if oldSession and oldSession.Cleanup then
	pcall(function()
		oldSession:Cleanup()
	end)
end

local function stopLegacyFeature(prefix)
	ENV[prefix .. "Enabled"] = false
	ENV[prefix .. "Running"] = false

	local thread = ENV[prefix .. "Thread"]
	if thread then
		pcall(task.cancel, thread)
	end

	for _, suffix in ipairs({ "Connection", "UpdateConnection", "ResultConnection", "BackpackConnection", "CharacterConnection" }) do
		local connection = ENV[prefix .. suffix]
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
		ENV[prefix .. suffix] = nil
	end
end

for _, prefix in ipairs({
	"BaconHubAutoNPCResponse",
	"BaconHubAutoCook",
	"BaconHubAutoPlaceCooked",
	"BaconHubAutoBuyMeat",
	"BaconHubAutoOrganize",
	"BaconHubAutoPlaceBoughtObjects",
	"BaconHubAutoPickupEverything",
	"BaconHubAutoDiscard",
	"BaconHubAutoUpgrade",
}) do
	stopLegacyFeature(prefix)
end

for _, connection in ipairs(ENV.BaconHubAutoPlaceBoughtObjectsToolConnections or {}) do
	pcall(function()
		connection:Disconnect()
	end)
end
ENV.BaconHubAutoPlaceBoughtObjectsToolConnections = nil

for _, connection in ipairs(ENV.BaconHubAutoUpgradeConnections or {}) do
	pcall(function()
		connection:Disconnect()
	end)
end
ENV.BaconHubAutoUpgradeConnections = nil

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local npcOffer = Remotes:WaitForChild("NPCOffer")
local npcResponse = Remotes:WaitForChild("NPCResponse")
local placeMeat = Remotes:WaitForChild("PlaceMeat")
local pickupMeat = Remotes:WaitForChild("PickupMeat")
local cookUpdate = Remotes:WaitForChild("CookUpdate")
local buyMeat = Remotes:WaitForChild("BuyMeat")
local getStock = Remotes:WaitForChild("GetStock")
local meatBuyResult = Remotes:WaitForChild("MeatBuyResult")
local buyShopItem = Remotes:WaitForChild("BuyShopItem")
local buyResult = Remotes:WaitForChild("BuyResult")
local getTotemStock = Remotes:WaitForChild("GetTotemStock")
local totemStockUpdate = Remotes:WaitForChild("TotemStockUpdate")
local pickupObject = Remotes:WaitForChild("PickupObject")
local placeObject = Remotes:WaitForChild("PlaceObject")
local placeResult = Remotes:WaitForChild("PlaceResult")
local discardHeldTool = Remotes:WaitForChild("DiscardHeldTool")

local state = {
	running = true,
	connections = {},
	loops = {},
	objectConnections = {},

	autoNpcResponse = false,
	autoCook = false,
	autoPlaceCooked = false,
	autoBuyMeat = false,
	autoBuyShopItems = false,
	autoPlaceObjects = false,
	autoPickupEverything = false,
	autoDiscard = false,
	autoUpgrade = false,
	autoRejoin = false,
	antiAfk = false,

	autoOrganizeRunning = false,
	pickupEverythingRunning = false,
	autoRejoinRunning = false,

	cookStateBySpot = {},
	meatFailedUntil = {},
	meatStock = {},
	buyMeatMode = "Most Expensive Affordable",
	selectedBuyMeats = {},
	shopFailedUntil = {},
	shopSearchText = "",
	shopBuyMode = "Most Expensive Selected",
	selectedShopItems = {},
	totemStockState = nil,
	objectQueue = {},
	objectKnownStacks = {},
	objectQueuedCurrent = {},
	discardMode = "Cooked Not Perfect",
	discardNameFilter = "",
	upgradeStates = {},
	failedUpgradeAttempts = {},
	blockedUpgradeUntil = {},

	lastAction = "Ready",
	lastCookAction = "Idle",
	lastPlaceCookedAction = "Idle",
	lastBuyAction = "Idle",
	lastShopBuyAction = "Idle",
	lastObjectAction = "Idle",
	lastPickupAllAction = "Idle",
	lastDiscardAction = "Idle",
	lastUpgradeAction = "Idle",
	lastOrganizeAction = "Idle",
	lastError = nil,
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

local function cancelAll(threads)
	for index, thread in ipairs(threads) do
		if thread then
			pcall(task.cancel, thread)
		end
		threads[index] = nil
	end
end

local function getSingleOption(option, fallback)
	if typeof(option) == "table" then
		return option[1] or fallback
	end

	return option or fallback
end

local function getMultiOptions(option)
	if typeof(option) ~= "table" then
		return {}
	end

	return option
end

local function copyList(list)
	local copy = {}

	for _, value in ipairs(list or {}) do
		table.insert(copy, value)
	end

	return copy
end

local function toSet(list)
	local set = {}

	for _, value in ipairs(list or {}) do
		set[value] = true
	end

	return set
end

local function setDropdownSelection(dropdown, selectedOptions)
	if not dropdown then
		return
	end

	if dropdown.Set then
		pcall(function()
			dropdown:Set(selectedOptions)
		end)
	end
end

local function refreshDropdownOptions(dropdown, options, clearSelection)
	if dropdown and dropdown.Refresh then
		pcall(function()
			dropdown:Refresh(options, clearSelection == true)
		end)
	end
end

local function getLot()
	local lots = workspace:FindFirstChild("PlayerLots")
	return lots and lots:FindFirstChild(LocalPlayer.Name)
end

local function getPlacementParts(lot)
	local important = lot and lot:FindFirstChild("Important")
	if not important then
		return nil, nil
	end

	return important:FindFirstChild("PlacementPart"), important:FindFirstChild("Pivot")
end

local function trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function cleanToolName(name)
	return trim((name:match("^(.-)%s*%(x%d+%)$") or name)
		:gsub("%[.-%]%s*", "")
		:gsub("^%s*%d+%.?%d*KG%s+", ""))
end

local function getToolBaseName(tool)
	return tool.Name:match("^(.-)%s*%(x%d+%)$") or tool.Name
end

local function getMeatRemoteName(tool)
	return tool.Name:gsub("%s*%(x%d+%)$", "")
end

local function getToolStackCount(tool)
	local stackCount = tool:GetAttribute("StackCount")
	if typeof(stackCount) == "number" and stackCount > 0 then
		return stackCount
	end

	return tonumber(tool.Name:match("%(x(%d+)%)$")) or 1
end

local function equipTool(tool, delayTime)
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and tool and tool.Parent ~= LocalPlayer.Character then
		humanoid:EquipTool(tool)
		task.wait(delayTime or 0.15)
	end
end

local function findToolByBaseName(baseName)
	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and getToolBaseName(tool) == baseName then
					return tool
				end
			end
		end
	end
end

local function isRawMeatTool(tool)
	return tool:IsA("Tool") and cleanToolName(tool.Name):lower():find("^raw ") ~= nil
end

local function findRawMeatTool()
	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if isRawMeatTool(tool) then
					return tool
				end
			end
		end
	end
end

local function findCookedTool()
	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("Cooked") == true then
					return tool
				end
			end
		end
	end
end

local function getMeatChildren(slot)
	local meats = {}

	for _, child in ipairs(slot:GetChildren()) do
		if child:GetAttribute("MeatName") or child:FindFirstChild("CookBillboard", true) then
			table.insert(meats, child)
		end
	end

	return meats
end

local function slotHasMeat(slot)
	return #getMeatChildren(slot) > 0
end

local function isSlot(instance)
	if not instance or instance:GetAttribute("MeatName") then
		return false
	end

	if instance:IsA("BasePart") then
		return true
	end

	if instance:IsA("Model") or instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("BasePart", true) ~= nil
	end

	return false
end

local function getCookState(spot)
	for _, meat in ipairs(getMeatChildren(spot)) do
		local stateLabel = meat:FindFirstChild("StateLabel", true)
		if stateLabel and stateLabel:IsA("TextLabel") then
			return stateLabel.Text
		end
	end

	return state.cookStateBySpot[spot]
end

local function getAllGrillSpots()
	local lot = getLot()
	local spots = {}

	if not lot then
		return spots
	end

	for _, object in ipairs(lot:GetChildren()) do
		local grillSpots = object:FindFirstChild("GrillSpots")
		if grillSpots then
			for _, spot in ipairs(grillSpots:GetChildren()) do
				if isSlot(spot) then
					table.insert(spots, spot)
				end
			end
		end
	end

	return spots
end

local function getEmptyGrillSpots()
	local emptySpots = {}

	for _, spot in ipairs(getAllGrillSpots()) do
		if not slotHasMeat(spot) then
			table.insert(emptySpots, spot)
		end
	end

	return emptySpots
end

local function getEmptyPlates()
	local lot = getLot()
	local emptyPlates = {}

	if not lot then
		return emptyPlates
	end

	for _, object in ipairs(lot:GetChildren()) do
		local plates = object:FindFirstChild("Plates")
		if plates then
			for _, plate in ipairs(plates:GetChildren()) do
				if isSlot(plate) and not slotHasMeat(plate) then
					table.insert(emptyPlates, plate)
				end
			end
		end
	end

	return emptyPlates
end

local function parseMoney(value)
	if typeof(value) == "number" then
		return value
	end

	local cleaned = tostring(value or ""):gsub(",", ""):gsub("%$", ""):gsub("%s+", "")
	local numberText, suffix = cleaned:match("^([%d%.]+)(%a*)$")
	local number = tonumber(numberText)

	if not number then
		return 0
	end

	local multipliers = {
		[""] = 1,
		K = 1e3,
		M = 1e6,
		B = 1e9,
		T = 1e12,
		Q = 1e15,
		QA = 1e15,
		QI = 1e18,
		SX = 1e21,
		SP = 1e24,
		OC = 1e27,
		NO = 1e30,
		DC = 1e33,
	}

	return number * (multipliers[suffix:upper()] or 1)
end

local function getMoney()
	local moneyValue = LocalPlayer:FindFirstChild("Money")
	if moneyValue and moneyValue:IsA("ValueBase") then
		return parseMoney(moneyValue.Value)
	end

	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	local leaderMoney = leaderstats and leaderstats:FindFirstChild("Money")
	if leaderMoney and leaderMoney:IsA("ValueBase") then
		return parseMoney(leaderMoney.Value)
	end

	return 0
end

local function formatMoney(amount)
	if not amount then
		return "?"
	end

	local suffixes = {
		{ value = 1e33, suffix = "Dc" },
		{ value = 1e30, suffix = "No" },
		{ value = 1e27, suffix = "Oc" },
		{ value = 1e24, suffix = "Sp" },
		{ value = 1e21, suffix = "Sx" },
		{ value = 1e18, suffix = "Qi" },
		{ value = 1e15, suffix = "Qa" },
		{ value = 1e12, suffix = "T" },
		{ value = 1e9, suffix = "B" },
		{ value = 1e6, suffix = "M" },
		{ value = 1e3, suffix = "K" },
	}

	for _, entry in ipairs(suffixes) do
		if math.abs(amount) >= entry.value then
			local compact = string.format("%.2f", amount / entry.value):gsub("0+$", ""):gsub("%.$", "")
			return compact .. entry.suffix
		end
	end

	return tostring(math.floor(amount))
end

local function getRawMeatCount()
	local count = 0

	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and cleanToolName(tool.Name):lower():find("^raw ") then
					count += getToolStackCount(tool)
				end
			end
		end
	end

	return count
end

local function getAvailableMeats()
	local meatsFolder = ReplicatedStorage:WaitForChild("Meats")
	local meats = {}

	for _, rarityFolder in ipairs(meatsFolder:GetChildren()) do
		for _, meatTool in ipairs(rarityFolder:GetChildren()) do
			if meatTool:IsA("Tool") then
				table.insert(meats, {
					name = meatTool.Name,
					price = meatTool:GetAttribute("Price") or 0,
					rarity = rarityFolder.Name,
				})
			end
		end
	end

	table.sort(meats, function(left, right)
		return left.price > right.price
	end)

	return meats
end

local function getMeatOptions()
	local options = {}

	for _, meat in ipairs(getAvailableMeats()) do
		table.insert(options, meat.name)
	end

	return options
end

local function refreshMeatStock()
	local success, result = pcall(function()
		return getStock:InvokeServer()
	end)

	if success and typeof(result) == "table" and typeof(result.stock) == "table" then
		state.meatStock = result.stock
	else
		state.meatStock = {}
	end
end

local function isInStock(meat)
	if meat.rarity == "Common" or meat.rarity == "Uncommon" then
		return true
	end

	return (state.meatStock[meat.name] or 0) > 0
end

local function getChosenMeatName()
	local money = getMoney()
	local candidates = {}
	local selectedSet = toSet(state.selectedBuyMeats)
	local hasSelectedMeats = #state.selectedBuyMeats > 0

	for _, meat in ipairs(getAvailableMeats()) do
		local canRetry = not state.meatFailedUntil[meat.name] or os.clock() >= state.meatFailedUntil[meat.name]

		if canRetry and meat.price <= money and isInStock(meat) then
			table.insert(candidates, meat)
		end
	end

	if #candidates == 0 then
		if hasSelectedMeats then
			state.lastBuyAction = "Selected meats unavailable"
		end

		return nil
	end

	if hasSelectedMeats then
		local selectedCandidates = {}

		for _, meat in ipairs(candidates) do
			if selectedSet[meat.name] then
				table.insert(selectedCandidates, meat)
			end
		end

		if #selectedCandidates == 0 then
			state.lastBuyAction = "Selected meats unavailable"
			return nil
		end

		candidates = selectedCandidates
	end

	local function highest(list)
		return list[1] and list[1].name or nil
	end

	local function lowest(list)
		local best

		for _, meat in ipairs(list) do
			if not best or meat.price < best.price then
				best = meat
			end
		end

		return best and best.name or nil
	end

	if state.buyMeatMode == "Cheapest Affordable" then
		return lowest(candidates)
	elseif state.buyMeatMode == "Random Affordable" then
		return candidates[math.random(1, #candidates)].name
	elseif state.buyMeatMode == "Selected Only" then
		if not hasSelectedMeats then
			state.lastBuyAction = "Select meats first"
			return nil
		end

		return highest(candidates)
	elseif state.buyMeatMode == "Selected First" then
		return highest(candidates)
	end

	return highest(candidates)
end

local SHOP_CATEGORIES = { "Grills", "Smokers", "Tables", "Totems", "Gears" }

local function isTotemItem(item)
	return item and item.category == "Totems"
end

local function makeShopOption(item)
	return item.category .. " / " .. item.name
end

local function getShopItems(searchText)
	local items = {}
	local needle = string.lower(tostring(searchText or ""))

	for categoryIndex, categoryName in ipairs(SHOP_CATEGORIES) do
		local folder = ReplicatedStorage:FindFirstChild(categoryName)
		if folder then
			for _, item in ipairs(folder:GetChildren()) do
				if item:IsA("Tool") or item:IsA("Model") then
					local itemData = {
						name = item.Name,
						category = categoryName,
						categoryIndex = categoryIndex,
						price = item:GetAttribute("Price") or 0,
						option = categoryName .. " / " .. item.Name,
					}

					local haystack = string.lower(itemData.option)
					if needle == "" or string.find(haystack, needle, 1, true) then
						table.insert(items, itemData)
					end
				end
			end
		end
	end

	table.sort(items, function(left, right)
		if left.categoryIndex == right.categoryIndex then
			if left.price == right.price then
				return left.name < right.name
			end

			return left.price > right.price
		end

		return left.categoryIndex < right.categoryIndex
	end)

	return items
end

local function getShopOptions(searchText)
	local options = {}

	for _, item in ipairs(getShopItems(searchText)) do
		table.insert(options, item.option)
	end

	return options
end

local function getShopItemByOption(option)
	for _, item in ipairs(getShopItems("")) do
		if item.option == option or item.name == option then
			return item
		end
	end
end

local function refreshTotemStock()
	local success, result = pcall(function()
		return getTotemStock:InvokeServer()
	end)

	if success and typeof(result) == "table" then
		state.totemStockState = result
		return true
	end

	state.totemStockState = nil
	return false
end

local function getTotemStockCount(itemName)
	local stockState = state.totemStockState
	local stockRoot = stockState and stockState.stock
	local stockTable = stockRoot and stockRoot.stock

	if typeof(stockTable) ~= "table" then
		return 0
	end

	return stockTable[itemName] or 0
end

local function canBuyShopItem(item)
	if not item then
		return false
	end

	if item.price > getMoney() then
		return false
	end

	if state.shopFailedUntil[item.option] and os.clock() < state.shopFailedUntil[item.option] then
		return false
	end

	if isTotemItem(item) then
		if not state.totemStockState then
			refreshTotemStock()
		end

		if state.totemStockState and state.totemStockState.alreadyBought then
			return false
		end

		return getTotemStockCount(item.name) > 0
	end

	return true
end

local function getSelectedShopCandidates()
	local candidates = {}

	for _, option in ipairs(state.selectedShopItems) do
		local item = getShopItemByOption(option)

		if canBuyShopItem(item) then
			table.insert(candidates, item)
		end
	end

	table.sort(candidates, function(left, right)
		if left.price == right.price then
			return left.option < right.option
		end

		if state.shopBuyMode == "Cheapest Selected" then
			return left.price < right.price
		end

		return left.price > right.price
	end)

	return candidates
end

local function getNextShopItemToBuy()
	if #state.selectedShopItems == 0 then
		state.lastShopBuyAction = "Select shop items first"
		return nil
	end

	local candidates = getSelectedShopCandidates()
	if #candidates == 0 then
		state.lastShopBuyAction = "No selected shop item is affordable/in stock"
		return nil
	end

	if state.shopBuyMode == "Random Selected" then
		return candidates[math.random(1, #candidates)]
	end

	return candidates[1]
end

local function findTemplate(baseName)
	for _, folder in ipairs(ReplicatedStorage:GetChildren()) do
		if folder:IsA("Folder") and folder.Name ~= "Meats" then
			local template = folder:FindFirstChild(baseName)
			if template and (template:IsA("Tool") or template:IsA("Model")) then
				return template, folder.Name
			end
		end
	end
end

local objectPriceCache = {}

local function getObjectPrice(baseName)
	if objectPriceCache[baseName] ~= nil then
		return objectPriceCache[baseName]
	end

	local template = findTemplate(baseName)
	local price = 0

	if template then
		local templatePrice = template:GetAttribute("Price")
		if typeof(templatePrice) == "number" then
			price = templatePrice
		end
	end

	objectPriceCache[baseName] = price
	return price
end

local function sortObjectsByValue(objects)
	table.sort(objects, function(left, right)
		local leftPrice = left.price or getObjectPrice(left.name)
		local rightPrice = right.price or getObjectPrice(right.name)

		if leftPrice == rightPrice then
			if left.area == right.area then
				return left.name < right.name
			end

			return left.area > right.area
		end

		return leftPrice > rightPrice
	end)
end

local function getTemplateInfo(baseName)
	local template, category = findTemplate(baseName)
	if not template then
		return nil
	end

	local clone = template:Clone()
	local boxCFrame, boxSize = clone:GetBoundingBox()
	local pivot = clone:GetPivot()
	local bottomOffset = pivot.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	clone:Destroy()

	return {
		name = baseName,
		category = category,
		price = getObjectPrice(baseName),
		width = math.max(1, boxSize.X),
		depth = math.max(1, boxSize.Z),
		height = boxSize.Y,
		bottomOffset = bottomOffset,
		area = math.max(1, boxSize.X) * math.max(1, boxSize.Z),
	}
end

local function isPlaceableTool(tool)
	return tool:IsA("Tool") and findTemplate(getToolBaseName(tool)) ~= nil
end

local function isHammerTool(tool)
	return tool and getToolBaseName(tool) == "Hammer [Pick up]"
end

local function isRawMeatTool(tool)
	return tool:IsA("Tool") and cleanToolName(tool.Name):lower():find("^raw ") ~= nil
end

local function isMeatTool(tool)
	return tool:IsA("Tool") and (
		tool:GetAttribute("CookTime") ~= nil
		or tool:GetAttribute("Cooked") ~= nil
		or isRawMeatTool(tool)
	)
end

local function isCookedMeatTool(tool)
	return isMeatTool(tool) and not isRawMeatTool(tool)
end

local function isPerfectMeatTool(tool)
	return cleanToolName(tool.Name):lower():find("perfect", 1, true) ~= nil
end

local function shouldDiscardTool(tool)
	if not tool or not tool:IsA("Tool") or isHammerTool(tool) then
		return false
	end

	local mode = state.discardMode

	if mode == "Name Contains" then
		local needle = trim(state.discardNameFilter):lower()
		return needle ~= "" and tool.Name:lower():find(needle, 1, true) ~= nil
	elseif mode == "Raw Meat" then
		return isRawMeatTool(tool)
	elseif mode == "All Cooked Meat" then
		return isCookedMeatTool(tool)
	elseif mode == "All Meat" then
		return isMeatTool(tool)
	elseif mode == "Objects Only" then
		return isPlaceableTool(tool)
	elseif mode == "Everything Except Hammer" then
		return true
	end

	return isCookedMeatTool(tool) and not isPerfectMeatTool(tool)
end

local function getNextDiscardTool()
	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if shouldDiscardTool(tool) then
					return tool
				end
			end
		end
	end
end

local function discardTool(tool)
	if not tool or not tool.Parent then
		return false
	end

	equipTool(tool, 0.12)

	if tool.Parent ~= LocalPlayer.Character then
		return false
	end

	local displayName = cleanToolName(tool.Name)
	discardHeldTool:FireServer()
	state.lastDiscardAction = "Discarded " .. displayName
	task.wait(0.25)
	return true
end

local function sortObjectQueue()
	table.sort(state.objectQueue, function(left, right)
		local leftPrice = getObjectPrice(left)
		local rightPrice = getObjectPrice(right)

		if leftPrice == rightPrice then
			return tostring(left) < tostring(right)
		end

		return leftPrice > rightPrice
	end)
end

local function enqueueObject(baseName, count)
	for _ = 1, count do
		table.insert(state.objectQueue, baseName)
	end

	sortObjectQueue()
	state.lastObjectAction = "Queued " .. baseName
end

local function getOccupiedRects()
	local lot = getLot()
	local rects = {}

	if not lot then
		return rects
	end

	for _, object in ipairs(lot:GetChildren()) do
		if object:IsA("Model") and object.Name:match("_Placed$") then
			local boxCFrame, boxSize = object:GetBoundingBox()
			table.insert(rects, {
				minX = boxCFrame.Position.X - boxSize.X / 2 - 0.65,
				maxX = boxCFrame.Position.X + boxSize.X / 2 + 0.65,
				minZ = boxCFrame.Position.Z - boxSize.Z / 2 - 0.65,
				maxZ = boxCFrame.Position.Z + boxSize.Z / 2 + 0.65,
			})
		end
	end

	return rects
end

local function overlapsAny(rect, rects)
	for _, other in ipairs(rects) do
		if rect.minX < other.maxX and rect.maxX > other.minX and rect.minZ < other.maxZ and rect.maxZ > other.minZ then
			return true
		end
	end

	return false
end

local function findOpenPlacement(info, extraOccupiedRects)
	local lot = getLot()
	local placementPart = getPlacementParts(lot)

	if not placementPart then
		return nil
	end

	local margin = 1.25
	local step = 1.25
	local minX = placementPart.Position.X - placementPart.Size.X / 2 + margin
	local maxX = placementPart.Position.X + placementPart.Size.X / 2 - margin
	local minZ = placementPart.Position.Z - placementPart.Size.Z / 2 + margin
	local maxZ = placementPart.Position.Z + placementPart.Size.Z / 2 - margin
	local occupiedRects = getOccupiedRects()

	for _, rect in ipairs(extraOccupiedRects or {}) do
		table.insert(occupiedRects, rect)
	end

	local options = {
		{ width = info.width, depth = info.depth, rotation = 0 },
		{ width = info.depth, depth = info.width, rotation = math.rad(90) },
	}

	table.sort(options, function(left, right)
		if left.depth == right.depth then
			return left.width > right.width
		end

		return left.depth < right.depth
	end)

	local z = minZ
	while z <= maxZ do
		local x = minX
		while x <= maxX do
			for _, option in ipairs(options) do
				local rect = {
					minX = x,
					maxX = x + option.width,
					minZ = z,
					maxZ = z + option.depth,
				}

				if rect.maxX <= maxX and rect.maxZ <= maxZ and not overlapsAny(rect, occupiedRects) then
					return {
						x = x + option.width / 2,
						z = z + option.depth / 2,
						rotation = option.rotation,
						rect = rect,
					}
				end
			end

			x += step
		end

		z += step
	end
end

local function placeQueuedObject(baseName)
	local lot = getLot()
	local placementPart, pivotPart = getPlacementParts(lot)
	local info = getTemplateInfo(baseName)

	if not placementPart or not pivotPart or not info then
		return false
	end

	local tool = findToolByBaseName(baseName)
	if not tool then
		return false
	end

	local blockedRects = {}

	for _ = 1, 25 do
		local openPlacement = findOpenPlacement(info, blockedRects)
		if not openPlacement then
			state.lastObjectAction = "No open land for " .. baseName
			return false
		end

		equipTool(tool, 0.2)

		local floorY = placementPart.Position.Y + placementPart.Size.Y / 2
		local targetPivot = CFrame.new(openPlacement.x, floorY + info.bottomOffset, openPlacement.z) * CFrame.Angles(0, openPlacement.rotation, 0)
		local relativePivot = pivotPart.CFrame:ToObjectSpace(targetPivot)
		local result
		local resultConnection

		resultConnection = placeResult.OnClientEvent:Connect(function(placeResultData)
			result = placeResultData
		end)

		state.lastObjectAction = "Placing " .. baseName
		placeObject:FireServer(baseName, relativePivot)

		local started = os.clock()
		while not result and os.clock() - started < 2 do
			task.wait()
		end

		resultConnection:Disconnect()

		if result and result.success then
			state.lastObjectAction = "Placed " .. baseName
			return true
		end

		if openPlacement.rect then
			table.insert(blockedRects, openPlacement.rect)
		end

		task.wait(0.1)
	end

	return false
end

local function watchObjectTool(tool, queueCurrentStack)
	if state.objectKnownStacks[tool] or not isPlaceableTool(tool) then
		return
	end

	local baseName = getToolBaseName(tool)
	local stackCount = getToolStackCount(tool)
	state.objectKnownStacks[tool] = stackCount

	if queueCurrentStack and state.autoPlaceObjects then
		enqueueObject(baseName, stackCount)
	end

	local function refreshStack()
		if not tool.Parent then
			return
		end

		local newBaseName = getToolBaseName(tool)
		local newStackCount = getToolStackCount(tool)
		local oldStackCount = state.objectKnownStacks[tool] or 0

		if state.autoPlaceObjects and newBaseName == baseName and newStackCount > oldStackCount then
			enqueueObject(baseName, newStackCount - oldStackCount)
		end

		state.objectKnownStacks[tool] = newStackCount
	end

	table.insert(state.objectConnections, tool:GetAttributeChangedSignal("StackCount"):Connect(refreshStack))
	table.insert(state.objectConnections, tool:GetPropertyChangedSignal("Name"):Connect(refreshStack))
end

local function watchObjectContainer(container)
	if not container then
		return nil
	end

	for _, tool in ipairs(container:GetChildren()) do
		if tool:IsA("Tool") then
			watchObjectTool(tool, false)
		end
	end

	return container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.05)
			watchObjectTool(child, state.autoPlaceObjects)
		end
	end)
end

local function queueCurrentPlaceableTools()
	state.objectQueue = {}
	state.objectQueuedCurrent = {}

	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and not state.objectQueuedCurrent[tool] and isPlaceableTool(tool) then
					state.objectQueuedCurrent[tool] = true
					enqueueObject(getToolBaseName(tool), getToolStackCount(tool))
				end
			end
		end
	end
end

local function getPlacedObjects(lot)
	local objects = {}

	for _, object in ipairs(lot:GetChildren()) do
		if object:IsA("Model") and object.Name:match("_Placed$") then
			local baseName = object.Name:gsub("_Placed$", "")
			local info = getTemplateInfo(baseName)

			if info then
				info.model = object
				table.insert(objects, info)
			end
		end
	end

	sortObjectsByValue(objects)

	return objects
end

local function getInventoryObjects()
	local objects = {}

	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					local info = getTemplateInfo(getToolBaseName(tool))

					if info then
						for _ = 1, getToolStackCount(tool) do
							table.insert(objects, {
								name = info.name,
								category = info.category,
								price = info.price,
								width = info.width,
								depth = info.depth,
								height = info.height,
								bottomOffset = info.bottomOffset,
								area = info.area,
							})
						end
					end
				end
			end
		end
	end

	sortObjectsByValue(objects)

	return objects
end

local function pickupAllMeat(lot)
	local count = 0

	for _, object in ipairs(lot:GetChildren()) do
		for _, folderName in ipairs({ "GrillSpots", "Plates" }) do
			local slots = object:FindFirstChild(folderName)
			if slots then
				for _, slot in ipairs(slots:GetChildren()) do
					if slotHasMeat(slot) then
						pickupMeat:FireServer(slot)
						count += 1
						task.wait(0.08)
					end
				end
			end
		end
	end

	return count
end

local function pickupAllPlacedObjects(lot)
	local objects = getPlacedObjects(lot)

	if #objects == 0 then
		return 0
	end

	local hammer = findToolByBaseName("Hammer [Pick up]")
	if not hammer then
		state.lastPickupAllAction = "Hammer not found"
		return 0
	end

	local count = 0
	equipTool(hammer, 0.15)

	for _, object in ipairs(objects) do
		if object.model and object.model.Parent then
			equipTool(hammer, 0.08)
			pickupObject:FireServer(object.model)
			count += 1
			task.wait(0.1)
		end
	end

	return count
end

local function pickupEverythingOnce()
	if state.pickupEverythingRunning then
		return false
	end

	state.pickupEverythingRunning = true

	local success, err = pcall(function()
		local lot = getLot()
		if not lot then
			state.lastPickupAllAction = "No lot found"
			return
		end

		local meatCount = pickupAllMeat(lot)
		local objectCount = pickupAllPlacedObjects(lot)
		state.lastPickupAllAction = "Picked meat " .. tostring(meatCount) .. ", objects " .. tostring(objectCount)
	end)

	if not success then
		state.lastPickupAllAction = "Error"
		state.lastError = tostring(err)
	end

	state.pickupEverythingRunning = false
	return true
end

local function makePlan(objects, placementPart)
	sortObjectsByValue(objects)

	local margin = 1.25
	local minX = placementPart.Position.X - placementPart.Size.X / 2 + margin
	local maxX = placementPart.Position.X + placementPart.Size.X / 2 - margin
	local minZ = placementPart.Position.Z - placementPart.Size.Z / 2 + margin
	local maxZ = placementPart.Position.Z + placementPart.Size.Z / 2 - margin
	local plan = {}
	local skipped = {}
	local cursorX = minX
	local cursorZ = minZ
	local rowDepth = 0

	for _, object in ipairs(objects) do
		local options = {
			{ width = object.width, depth = object.depth, rotation = 0 },
			{ width = object.depth, depth = object.width, rotation = math.rad(90) },
		}

		table.sort(options, function(left, right)
			if left.depth == right.depth then
				return left.width > right.width
			end

			return left.depth < right.depth
		end)

		local chosen
		for _, option in ipairs(options) do
			if cursorX + option.width <= maxX and cursorZ + option.depth <= maxZ then
				chosen = option
				break
			end
		end

		if not chosen then
			cursorX = minX
			cursorZ += rowDepth + margin
			rowDepth = 0

			for _, option in ipairs(options) do
				if cursorX + option.width <= maxX and cursorZ + option.depth <= maxZ then
					chosen = option
					break
				end
			end
		end

		if chosen then
			table.insert(plan, {
				object = object,
				x = cursorX + chosen.width / 2,
				z = cursorZ + chosen.depth / 2,
				rotation = chosen.rotation,
			})

			cursorX += chosen.width + margin
			rowDepth = math.max(rowDepth, chosen.depth)
		else
			table.insert(skipped, object.name)
		end
	end

	return plan, skipped
end

local function runAutoOrganize()
	if state.autoOrganizeRunning then
		notify("Auto Organize", "Already running.")
		return
	end

	state.autoOrganizeRunning = true
	state.lastOrganizeAction = "Starting"
	notify("Auto Organize", "Started")

	task.spawn(function()
		local success, err = pcall(function()
			local lot = getLot()
			if not lot then
				state.lastOrganizeAction = "No lot found"
				return
			end

			local placementPart, pivotPart = getPlacementParts(lot)
			if not placementPart or not pivotPart then
				state.lastOrganizeAction = "Missing placement parts"
				return
			end

			local placedObjects = getPlacedObjects(lot)

			state.lastOrganizeAction = "Picking up meat"
			pickupAllMeat(lot)
			task.wait(0.5)
			pickupAllMeat(lot)
			task.wait(0.75)

			if #placedObjects > 0 then
				state.lastOrganizeAction = "Picking up objects"
				local hammer = findToolByBaseName("Hammer [Pick up]")
				if not hammer then
					state.lastOrganizeAction = "Hammer not found"
					return
				end

				equipTool(hammer, 0.15)

				for _ = 1, 3 do
					local pickedSomething = false

					for _, object in ipairs(placedObjects) do
						if object.model and object.model.Parent then
							equipTool(hammer, 0.15)
							pickupObject:FireServer(object.model)
							pickedSomething = true
							task.wait(0.12)
						end
					end

					if not pickedSomething then
						break
					end

					task.wait(0.5)
				end
			end

			task.wait(1)

			local objects = getInventoryObjects()
			if #objects == 0 then
				state.lastOrganizeAction = "No object tools found"
				return
			end

			local plan, skipped = makePlan(objects, placementPart)
			local floorY = placementPart.Position.Y + placementPart.Size.Y / 2
			state.lastOrganizeAction = "Placing objects"

			for _, entry in ipairs(plan) do
				local object = entry.object
				local tool = findToolByBaseName(object.name)

				if tool then
					equipTool(tool, 0.15)

					local targetPivot = CFrame.new(entry.x, floorY + object.bottomOffset, entry.z) * CFrame.Angles(0, entry.rotation, 0)
					local relativePivot = pivotPart.CFrame:ToObjectSpace(targetPivot)

					state.lastOrganizeAction = "Placing " .. object.name
					placeObject:FireServer(object.name, relativePivot)
					task.wait(0.65)
				else
					table.insert(skipped, object.name)
				end
			end

			if #skipped > 0 then
				state.lastOrganizeAction = "Done, skipped " .. tostring(#skipped)
			else
				state.lastOrganizeAction = "Done"
			end
		end)

		if not success then
			state.lastOrganizeAction = "Error"
			state.lastError = tostring(err)
		end

		state.autoOrganizeRunning = false
		notify("Auto Organize", state.lastOrganizeAction)
	end)
end

local upgradeDefinitions = {
	{
		id = "CookTime",
		displayName = "Cook Time",
		upgradeRemote = Remotes:WaitForChild("UpgradeCookTime"),
	},
	{
		id = "EatTime",
		displayName = "Eat Time",
		upgradeRemote = Remotes:WaitForChild("UpgradeEatTime"),
	},
	{
		id = "RestockChance",
		displayName = "Restock Chances",
		upgradeRemote = Remotes:WaitForChild("UpgradeRestockChance"),
	},
	{
		id = "RestockTimer",
		displayName = "Restock Timer",
		upgradeRemote = Remotes:WaitForChild("UpgradeRestockTimer"),
	},
}

local requestCookTimeState = Remotes:WaitForChild("RequestCookTimeUpgradeState")
local requestEatTimeState = Remotes:WaitForChild("RequestEatTimeUpgradeState")
local requestRestockState = Remotes:WaitForChild("RequestRestockUpgradeState")

local function clearUpgradeStates()
	for key in pairs(state.upgradeStates) do
		state.upgradeStates[key] = nil
	end
end

local function hasAllUpgradeStates()
	return state.upgradeStates.CookTime ~= nil
		and state.upgradeStates.EatTime ~= nil
		and state.upgradeStates.RestockChance ~= nil
		and state.upgradeStates.RestockTimer ~= nil
end

local function requestUpgradeStates()
	clearUpgradeStates()
	requestCookTimeState:FireServer()
	requestEatTimeState:FireServer()
	requestRestockState:FireServer()

	local started = os.clock()
	while state.running and not hasAllUpgradeStates() and os.clock() - started < 3 do
		task.wait()
	end

	return hasAllUpgradeStates()
end

local function getCheapestAffordableUpgrade(money)
	local bestUpgrade

	for _, definition in ipairs(upgradeDefinitions) do
		local upgradeState = state.upgradeStates[definition.id]
		local isBlocked = state.blockedUpgradeUntil[definition.id] and os.clock() < state.blockedUpgradeUntil[definition.id]

		if upgradeState and typeof(upgradeState.nextPrice) == "number" and upgradeState.nextPrice <= money and not isBlocked then
			if not bestUpgrade or upgradeState.nextPrice < bestUpgrade.price then
				bestUpgrade = {
					definition = definition,
					state = upgradeState,
					price = upgradeState.nextPrice,
				}
			end
		end
	end

	return bestUpgrade
end

local function getUpgradeStatusText()
	local lines = {}

	for _, definition in ipairs(upgradeDefinitions) do
		local upgradeState = state.upgradeStates[definition.id]
		if upgradeState then
			local level = tostring(upgradeState.level or "?")
			local maxLevel = tostring(upgradeState.maxLevel or "?")
			local nextPrice = upgradeState.nextPrice and ("$" .. formatMoney(upgradeState.nextPrice)) or "MAX"
			table.insert(lines, definition.displayName .. ": " .. level .. "/" .. maxLevel .. " | " .. nextPrice)
		else
			table.insert(lines, definition.displayName .. ": unknown")
		end
	end

	return table.concat(lines, "\n")
end

local lastPickupBySpot = {}
local lastPlaceBySpot = {}
local lastPlaceByPlate = {}

table.insert(state.connections, npcOffer.OnClientEvent:Connect(function(npcModel, _, _, offerId)
	if not state.autoNpcResponse or not offerId then
		return
	end

	npcResponse:FireServer(offerId, true)
	state.lastAction = "Accepted NPC offer"

	task.defer(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local head = npcModel and npcModel:FindFirstChild("Head")
		if not playerGui then
			return
		end

		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui.Name == "NPCOfferBillboard" and (not head or gui.Adornee == head) then
				gui:Destroy()
			end
		end
	end)
end))

table.insert(state.connections, cookUpdate.OnClientEvent:Connect(function(meatModel, _, _, cookState)
	local spot = meatModel and meatModel.Parent
	if spot then
		state.cookStateBySpot[spot] = cookState
	end

	if state.autoCook and spot and cookState == "Perfect" and (not lastPickupBySpot[spot] or os.clock() - lastPickupBySpot[spot] > 0.5) then
		pickupMeat:FireServer(spot)
		lastPickupBySpot[spot] = os.clock()
		state.lastCookAction = "Picked up perfect meat"
	end
end))

table.insert(state.connections, meatBuyResult.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		return
	end

	if result.success then
		state.lastBuyAction = "Bought " .. tostring(result.meatName or "meat")
	elseif result.meatName then
		state.meatFailedUntil[result.meatName] = os.clock() + 20
		state.lastBuyAction = "Buy failed: " .. tostring(result.meatName)
	end
end))

table.insert(state.connections, buyResult.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		return
	end

	local itemName = result.itemName or "item"

	if result.success then
		state.lastShopBuyAction = "Bought " .. tostring(itemName)
		refreshTotemStock()
	else
		state.lastShopBuyAction = "Buy failed: " .. tostring(itemName)

		if result.itemName then
			for _, item in ipairs(getShopItems("")) do
				if item.name == result.itemName then
					state.shopFailedUntil[item.option] = os.clock() + 15
				end
			end
		end

		if result.reason == "out_of_stock" or result.reason == "already_bought" then
			refreshTotemStock()
		end
	end
end))

table.insert(state.connections, totemStockUpdate.OnClientEvent:Connect(function(stock)
	state.totemStockState = {
		alreadyBought = false,
		stock = stock,
	}
end))

table.insert(state.connections, Remotes:WaitForChild("CookTimeUpgradeState").OnClientEvent:Connect(function(upgradeState)
	if typeof(upgradeState) == "table" then
		state.upgradeStates.CookTime = upgradeState
	end
end))

table.insert(state.connections, Remotes:WaitForChild("EatTimeUpgradeState").OnClientEvent:Connect(function(upgradeState)
	if typeof(upgradeState) == "table" then
		state.upgradeStates.EatTime = upgradeState
	end
end))

table.insert(state.connections, Remotes:WaitForChild("RestockUpgradeState").OnClientEvent:Connect(function(upgradeState)
	if typeof(upgradeState) ~= "table" then
		return
	end

	if upgradeState.kind == "Chance" then
		state.upgradeStates.RestockChance = upgradeState
	elseif upgradeState.kind == "Timer" then
		state.upgradeStates.RestockTimer = upgradeState
	end
end))

local function connectObjectWatchers()
	disconnectAll(state.objectConnections)
	table.insert(state.objectConnections, watchObjectContainer(LocalPlayer:WaitForChild("Backpack")))

	local function watchCharacter(character)
		table.insert(state.objectConnections, watchObjectContainer(character))
		if state.autoPlaceObjects then
			task.defer(queueCurrentPlaceableTools)
		end
	end

	if LocalPlayer.Character then
		watchCharacter(LocalPlayer.Character)
	end

	table.insert(state.objectConnections, LocalPlayer.CharacterAdded:Connect(watchCharacter))
end

connectObjectWatchers()

table.insert(state.loops, task.spawn(function()
	while state.running do
		if state.autoCook then
			local now = os.clock()

			for _, spot in ipairs(getAllGrillSpots()) do
				if getCookState(spot) == "Perfect" and (not lastPickupBySpot[spot] or now - lastPickupBySpot[spot] > 0.5) then
					pickupMeat:FireServer(spot)
					lastPickupBySpot[spot] = now
					state.lastCookAction = "Picked up perfect meat"
					task.wait(0.1)
				end
			end

			for _, emptySpot in ipairs(getEmptyGrillSpots()) do
				now = os.clock()

				if not lastPlaceBySpot[emptySpot] or now - lastPlaceBySpot[emptySpot] > 1.25 then
					local tool = findRawMeatTool()
					if not tool then
						state.lastCookAction = "No raw meat"
						break
					end

					equipTool(tool, 0.1)
					placeMeat:FireServer(emptySpot, getMeatRemoteName(tool))
					lastPlaceBySpot[emptySpot] = os.clock()
					state.lastCookAction = "Placed " .. getMeatRemoteName(tool)
					task.wait(0.35)
				end
			end
		end

		task.wait(0.15)
	end
end))

table.insert(state.loops, task.spawn(function()
	while state.running do
		if state.autoPlaceCooked then
			local placedFood = false

			for _, plate in ipairs(getEmptyPlates()) do
				local now = os.clock()

				if not lastPlaceByPlate[plate] or now - lastPlaceByPlate[plate] > 1.25 then
					local tool = findCookedTool()
					if not tool then
						state.lastPlaceCookedAction = "No cooked food"
						break
					end

					equipTool(tool, 0.1)
					placeMeat:FireServer(plate, getMeatRemoteName(tool))
					lastPlaceByPlate[plate] = os.clock()
					state.lastPlaceCookedAction = "Placed " .. getMeatRemoteName(tool)
					placedFood = true
					task.wait(0.5)
				end
			end

			if not placedFood then
				task.wait(0.2)
			end
		else
			task.wait(0.2)
		end
	end
end))

table.insert(state.loops, task.spawn(function()
	local lastBuy = 0
	local lastStockRefresh = 0

	while state.running do
		if state.autoBuyMeat then
			local now = os.clock()

			if now - lastStockRefresh > 5 then
				refreshMeatStock()
				lastStockRefresh = now
			end

			local emptySpotCount = #getEmptyGrillSpots()
			local rawMeatCount = getRawMeatCount()
			local neededMeatCount = math.max(0, emptySpotCount - rawMeatCount)
			state.lastBuyAction = "Open slots: " .. emptySpotCount .. ", raw meat: " .. rawMeatCount

			if neededMeatCount > 0 and now - lastBuy > 1.25 then
				local previousBuyAction = state.lastBuyAction
				local meatName = getChosenMeatName()
				if meatName then
					buyMeat:FireServer(meatName, false)
					state.lastBuyAction = "Buying " .. meatName
					lastBuy = now
				elseif state.lastBuyAction == previousBuyAction then
					state.lastBuyAction = "No affordable in-stock meat"
				end
			end
		end

		task.wait(0.35)
	end
end))

table.insert(state.loops, task.spawn(function()
	local lastBuy = 0
	local lastTotemStockRefresh = 0

	while state.running do
		if state.autoBuyShopItems then
			local now = os.clock()

			if now - lastTotemStockRefresh > 5 then
				refreshTotemStock()
				lastTotemStockRefresh = now
			end

			if now - lastBuy > 1.25 then
				local item = getNextShopItemToBuy()

				if item then
					state.lastShopBuyAction = "Buying " .. item.name
					buyShopItem:FireServer(item.name, false)
					lastBuy = now
				end
			end
		end

		task.wait(0.35)
	end
end))

table.insert(state.loops, task.spawn(function()
	while state.running do
		if state.autoPlaceObjects then
			local nextObject = state.objectQueue[1]

			if nextObject then
				local placed = placeQueuedObject(nextObject)
				if placed then
					table.remove(state.objectQueue, 1)
				else
					task.wait(1)
				end
			else
				state.lastObjectAction = "Waiting for bought objects"
				task.wait(0.25)
			end
		else
			task.wait(0.25)
		end
	end
end))

table.insert(state.loops, task.spawn(function()
	while state.running do
		if state.autoPickupEverything then
			local ran = pickupEverythingOnce()
			task.wait(ran and 1.25 or 0.5)
		else
			task.wait(0.5)
		end
	end
end))

table.insert(state.loops, task.spawn(function()
	while state.running do
		if state.autoDiscard then
			local tool = getNextDiscardTool()

			if tool then
				state.lastDiscardAction = "Discarding " .. cleanToolName(tool.Name)
				if not discardTool(tool) then
					state.lastDiscardAction = "Could not discard " .. cleanToolName(tool.Name)
					task.wait(0.75)
				end
			else
				state.lastDiscardAction = "Waiting for matches"
				task.wait(0.75)
			end
		else
			task.wait(0.5)
		end
	end
end))

table.insert(state.loops, task.spawn(function()
	while state.running do
		if state.autoUpgrade then
			local hasStates = requestUpgradeStates()
			local money = getMoney()

			if not hasStates then
				state.lastUpgradeAction = "Waiting for upgrade states"
				task.wait(2)
			else
				local nextUpgrade = getCheapestAffordableUpgrade(money)

				if nextUpgrade then
					local definition = nextUpgrade.definition
					local beforeState = nextUpgrade.state
					local beforeLevel = beforeState.level
					local beforePrice = beforeState.nextPrice

					state.lastUpgradeAction = "Upgrading " .. definition.displayName .. " for $" .. formatMoney(beforePrice)
					definition.upgradeRemote:FireServer()

					task.wait(0.45)
					requestUpgradeStates()

					local afterState = state.upgradeStates[definition.id]
					local didNotChange = afterState
						and afterState.level == beforeLevel
						and afterState.nextPrice == beforePrice

					if didNotChange then
						state.failedUpgradeAttempts[definition.id] = (state.failedUpgradeAttempts[definition.id] or 0) + 1

						if state.failedUpgradeAttempts[definition.id] >= 3 then
							state.blockedUpgradeUntil[definition.id] = os.clock() + 15
							state.lastUpgradeAction = "Waiting before retrying " .. definition.displayName
						end

						task.wait(1)
					else
						state.failedUpgradeAttempts[definition.id] = 0
						state.blockedUpgradeUntil[definition.id] = nil
						task.wait(0.2)
					end
				else
					state.lastUpgradeAction = "Waiting for affordable upgrades"
					task.wait(3)
				end
			end
		else
			task.wait(0.5)
		end
	end
end))

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

function state:Cleanup()
	self.running = false
	self.autoNpcResponse = false
	self.autoCook = false
	self.autoPlaceCooked = false
	self.autoBuyMeat = false
	self.autoBuyShopItems = false
	self.autoPlaceObjects = false
	self.autoPickupEverything = false
	self.autoDiscard = false
	self.autoUpgrade = false
	self.autoRejoin = false
	self.antiAfk = false

	disconnectAll(self.connections)
	disconnectAll(self.objectConnections)
	cancelAll(self.loops)

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

local Window = Rayfield:CreateWindow({
	Name = "BaconHub - BBQ It",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "BBQ It",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "BBQIt",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local AutomationTab = Window:CreateTab("Automation", 0)
local ShopTab = Window:CreateTab("Shop", 0)
local ObjectsTab = Window:CreateTab("Objects", 0)
local InventoryTab = Window:CreateTab("Inventory", 0)
local UpgradesTab = Window:CreateTab("Upgrades", 0)
local StatusTab = Window:CreateTab("Status", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

local statusParagraph = createParagraph(StatusTab, {
	Title = "Status",
	Content = "Ready.",
})

local upgradeParagraph = createParagraph(UpgradesTab, {
	Title = "Upgrade Levels",
	Content = "Press Refresh Upgrade Status or turn on Auto Upgrade.",
})

local function refreshStatusParagraph()
	local content = table.concat({
		"NPC: " .. (state.autoNpcResponse and "On" or "Off"),
		"Cook: " .. state.lastCookAction,
		"Food: " .. state.lastPlaceCookedAction,
		"Buy: " .. state.lastBuyAction .. " | " .. state.buyMeatMode .. " | selected " .. tostring(#state.selectedBuyMeats),
		"Shop: " .. state.lastShopBuyAction .. " | " .. state.shopBuyMode .. " | selected " .. tostring(#state.selectedShopItems),
		"Objects: " .. state.lastObjectAction .. " | queue " .. tostring(#state.objectQueue),
		"Pickup: " .. state.lastPickupAllAction,
		"Discard: " .. state.lastDiscardAction .. " | " .. state.discardMode,
		"Upgrade: " .. state.lastUpgradeAction,
		"Organize: " .. state.lastOrganizeAction,
		state.lastError and ("Last error: " .. state.lastError) or nil,
	}, "\n")

	setParagraph(statusParagraph, "Status", content)
	setParagraph(upgradeParagraph, "Upgrade Levels", getUpgradeStatusText())
end

table.insert(state.loops, task.spawn(function()
	while state.running do
		refreshStatusParagraph()
		task.wait(1)
	end
end))

local buyModeOptions = {
	"Most Expensive Affordable",
	"Cheapest Affordable",
	"Selected First",
	"Selected Only",
	"Random Affordable",
}
local meatOptions = getMeatOptions()
local meatDropdown
local shopBuyModeOptions = {
	"Most Expensive Selected",
	"Cheapest Selected",
	"Random Selected",
}
local discardModeOptions = {
	"Cooked Not Perfect",
	"Raw Meat",
	"All Cooked Meat",
	"All Meat",
	"Objects Only",
	"Everything Except Hammer",
	"Name Contains",
}
local shopItemOptions = getShopOptions(state.shopSearchText)
local shopItemDropdown

local function refreshShopItemDropdown()
	shopItemOptions = getShopOptions(state.shopSearchText)
	refreshDropdownOptions(shopItemDropdown, shopItemOptions, false)
end

AutomationTab:CreateToggle({
	Name = "Auto NPC Response",
	CurrentValue = false,
	Flag = "AutoNPCResponse",
	Callback = function(value)
		state.autoNpcResponse = value
		notify("Auto NPC Response", value and "Enabled" or "Disabled")
	end,
})

AutomationTab:CreateToggle({
	Name = "Auto Cook",
	CurrentValue = false,
	Flag = "AutoCook",
	Callback = function(value)
		state.autoCook = value
		notify("Auto Cook", value and "Enabled" or "Disabled")
	end,
})

AutomationTab:CreateToggle({
	Name = "Auto Place Cooked Food",
	CurrentValue = false,
	Flag = "AutoPlaceCookedFood",
	Callback = function(value)
		state.autoPlaceCooked = value
		notify("Auto Place Food", value and "Enabled" or "Disabled")
	end,
})

AutomationTab:CreateToggle({
	Name = "Auto Buy Meat",
	CurrentValue = false,
	Flag = "AutoBuyMeat",
	Callback = function(value)
		state.autoBuyMeat = value
		if value then
			refreshMeatStock()
		end
		notify("Auto Buy Meat", value and "Enabled" or "Disabled")
	end,
})

AutomationTab:CreateDropdown({
	Name = "Auto Buy Mode",
	Options = buyModeOptions,
	CurrentOption = { state.buyMeatMode },
	MultipleOptions = false,
	Flag = "AutoBuyMeatMode",
	Callback = function(option)
		state.buyMeatMode = getSingleOption(option, "Most Expensive Affordable")
		notify("Auto Buy Mode", state.buyMeatMode)
	end,
})

meatDropdown = AutomationTab:CreateDropdown({
	Name = "Meats To Buy",
	Options = meatOptions,
	CurrentOption = state.selectedBuyMeats,
	MultipleOptions = true,
	Flag = "AutoBuySelectedMeats",
	Callback = function(option)
		state.selectedBuyMeats = getMultiOptions(option)
		notify("Meats To Buy", tostring(#state.selectedBuyMeats) .. " selected")
	end,
})

AutomationTab:CreateButton({
	Name = "Select All Meats",
	Callback = function()
		state.selectedBuyMeats = copyList(meatOptions)
		setDropdownSelection(meatDropdown, state.selectedBuyMeats)
		notify("Meats To Buy", "Selected all meats.")
	end,
})

AutomationTab:CreateButton({
	Name = "Clear Selected Meats",
	Callback = function()
		state.selectedBuyMeats = {}
		setDropdownSelection(meatDropdown, state.selectedBuyMeats)
		notify("Meats To Buy", "Cleared selected meats.")
	end,
})

ShopTab:CreateInput({
	Name = "Shop Search",
	CurrentValue = "",
	PlaceholderText = "Search grills, tables, smokers, totems, gear",
	RemoveTextAfterFocusLost = false,
	Flag = "ShopItemSearch",
	Callback = function(value)
		state.shopSearchText = tostring(value or "")
		refreshShopItemDropdown()
	end,
})

ShopTab:CreateDropdown({
	Name = "Shop Buy Mode",
	Options = shopBuyModeOptions,
	CurrentOption = { state.shopBuyMode },
	MultipleOptions = false,
	Flag = "ShopBuyMode",
	Callback = function(option)
		state.shopBuyMode = getSingleOption(option, "Most Expensive Selected")
		notify("Shop Buy Mode", state.shopBuyMode)
	end,
})

shopItemDropdown = ShopTab:CreateDropdown({
	Name = "Shop Items To Buy",
	Options = shopItemOptions,
	CurrentOption = state.selectedShopItems,
	MultipleOptions = true,
	Flag = "ShopItemsToBuy",
	Callback = function(option)
		state.selectedShopItems = getMultiOptions(option)
		notify("Shop Items", tostring(#state.selectedShopItems) .. " selected")
	end,
})

ShopTab:CreateButton({
	Name = "Select Filtered Shop Items",
	Callback = function()
		state.selectedShopItems = copyList(shopItemOptions)
		setDropdownSelection(shopItemDropdown, state.selectedShopItems)
		notify("Shop Items", "Selected filtered items.")
	end,
})

ShopTab:CreateButton({
	Name = "Select All Shop Items",
	Callback = function()
		state.selectedShopItems = getShopOptions("")
		setDropdownSelection(shopItemDropdown, state.selectedShopItems)
		notify("Shop Items", "Selected all shop items.")
	end,
})

ShopTab:CreateButton({
	Name = "Clear Shop Items",
	Callback = function()
		state.selectedShopItems = {}
		setDropdownSelection(shopItemDropdown, state.selectedShopItems)
		notify("Shop Items", "Cleared selected shop items.")
	end,
})

ShopTab:CreateButton({
	Name = "Refresh Totem Stock",
	Callback = function()
		refreshTotemStock()
		notify("Totem Stock", "Refreshed")
	end,
})

ShopTab:CreateToggle({
	Name = "Auto Buy Selected Shop Items",
	CurrentValue = false,
	Flag = "AutoBuyShopItems",
	Callback = function(value)
		state.autoBuyShopItems = value
		if value then
			refreshTotemStock()
		end
		notify("Auto Buy Shop", value and "Enabled" or "Disabled")
	end,
})

ObjectsTab:CreateToggle({
	Name = "Auto Place Bought Objects",
	CurrentValue = false,
	Flag = "AutoPlaceBoughtObjects",
	Callback = function(value)
		state.autoPlaceObjects = value
		if value then
			queueCurrentPlaceableTools()
		else
			state.objectQueue = {}
		end
		notify("Auto Place Objects", value and "Enabled" or "Disabled")
	end,
})

ObjectsTab:CreateButton({
	Name = "Auto Organize Objects",
	Callback = runAutoOrganize,
})

ObjectsTab:CreateButton({
	Name = "Queue Current Object Tools",
	Callback = function()
		queueCurrentPlaceableTools()
		notify("Object Queue", "Queued current object tools.")
	end,
})

InventoryTab:CreateToggle({
	Name = "Auto Pickup Everything",
	CurrentValue = false,
	Flag = "AutoPickupEverything",
	Callback = function(value)
		state.autoPickupEverything = value
		notify("Auto Pickup Everything", value and "Enabled" or "Disabled")
	end,
})

InventoryTab:CreateButton({
	Name = "Pickup Everything Once",
	Callback = function()
		task.spawn(function()
			pickupEverythingOnce()
			notify("Pickup Everything", state.lastPickupAllAction)
		end)
	end,
})

InventoryTab:CreateToggle({
	Name = "Auto Discard",
	CurrentValue = false,
	Flag = "AutoDiscard",
	Callback = function(value)
		state.autoDiscard = value
		notify("Auto Discard", value and "Enabled" or "Disabled")
	end,
})

InventoryTab:CreateDropdown({
	Name = "Discard Mode",
	Options = discardModeOptions,
	CurrentOption = { state.discardMode },
	MultipleOptions = false,
	Flag = "DiscardMode",
	Callback = function(option)
		state.discardMode = getSingleOption(option, "Cooked Not Perfect")
		notify("Discard Mode", state.discardMode)
	end,
})

InventoryTab:CreateInput({
	Name = "Discard Name Contains",
	CurrentValue = "",
	PlaceholderText = "Chicken, Salmon, Raw, etc.",
	RemoveTextAfterFocusLost = false,
	Flag = "DiscardNameContains",
	Callback = function(value)
		state.discardNameFilter = tostring(value or "")
	end,
})

UpgradesTab:CreateToggle({
	Name = "Auto Upgrade",
	CurrentValue = false,
	Flag = "AutoUpgrade",
	Callback = function(value)
		state.autoUpgrade = value
		if value then
			task.spawn(requestUpgradeStates)
		end
		notify("Auto Upgrade", value and "Enabled" or "Disabled")
	end,
})

UpgradesTab:CreateButton({
	Name = "Refresh Upgrade Status",
	Callback = function()
		task.spawn(function()
			requestUpgradeStates()
			refreshStatusParagraph()
			notify("Upgrade Status", "Refreshed")
		end)
	end,
})

SettingsTab:CreateSection("Connection")

SettingsTab:CreateToggle({
	Name = "Auto Rejoin",
	CurrentValue = false,
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
	CurrentValue = false,
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
task.spawn(requestUpgradeStates)
notify("BaconHub", "BBQ It GUI loaded. Press K to toggle.")
