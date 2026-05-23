local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shared = ReplicatedStorage:WaitForChild("Source"):WaitForChild("Shared")
local configs = shared:WaitForChild("Configs")
local stateFolder = shared:WaitForChild("State")
local helpers = shared:WaitForChild("Helpers")

local openPackEvent = remotes:WaitForChild("OpenPack")
local packSettingsEvent = remotes:WaitForChild("PackSettings")
local performWish = remotes:WaitForChild("PerformWish")
local collectSlotEvent = remotes:WaitForChild("CollectSlot")
local buyPackEvent = remotes:WaitForChild("BuyPack")
local rebirthEvent = remotes:WaitForChild("Rebirth")
local craftTrophyEvent = remotes:WaitForChild("CraftTrophy")
local tournamentRemote = remotes:WaitForChild("Tournament")
local tournamentShopRemote = remotes:WaitForChild("TournamentServer")
local buyGemShopItem = remotes:WaitForChild("BuyGemShopItem")
local claimAllIndexGemsEvent = remotes:WaitForChild("ClaimAllIndexGems")
local sellCardsEvent = remotes:WaitForChild("SellCards")
local spinWheelEvent = remotes:WaitForChild("SpinWheel")
local spinWheelData = remotes:WaitForChild("SpinWheelData")

local playerStore = require(stateFolder:WaitForChild("PlayerStore"))
local gemShopState = require(stateFolder:WaitForChild("GemShopState"))
local packConfig = require(configs:WaitForChild("PackConfig"))
local cardConfig = require(configs:WaitForChild("CardConfig"))
local trophyConfig = require(configs:WaitForChild("TrophyConfig"))
local gemShopConfig = require(configs:WaitForChild("GemShopConfig"))
local tournamentConfig = require(configs:WaitForChild("TournamentConfig"))
local rebirthConfig = require(configs:WaitForChild("RebirthConfig"))
local tournamentClock = require(helpers:WaitForChild("TournamentClock"))
local scalingIncome = require(helpers:WaitForChild("ScalingIncome"))
local slotController = require(ReplicatedStorage:WaitForChild("Source"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("SlotController"))

local state = {
	autoOpenPacks = false,
	autoWish = false,
	autoCollectMoney = false,
	autoBuyPacks = false,
	autoRebirth = false,
	autoCraft = false,
	autoEquipBest = false,
	autoJoinTournament = false,
	autoBuyGemShop = false,
	autoCollectGems = false,
	autoSellCards = false,
	autoBuyTournamentShop = false,
	autoSpin = false,
	autoRejoin = false,
	antiAfk = false,

	selectedOpenPacks = {"Cosmic"},
	selectedBuyPacks = {"Toxic"},
	selectedCraftTrophies = {"Golden Boot", "Champions League", "Ballon d'Or", "Eternal Crown", "Immortal Chalice"},
	selectedCraftMaterialPacks = {"Cosmic", "Infernal", "Transcendent"},
	selectedGemShopItems = {"AutoSkip"},
	selectedTournamentShopKinds = {"gems", "spin", "wish", "pack"},

	packSearchText = "",
	autoCraftOpenPacks = false,
	useAutoSkip = false,
	hideAnimationWhenAutoSkip = true,
	openDelay = 0.25,
	autoSkipOpenDelay = 0.1,
	wishDelay = 1,
	spinLoopDelay = 15,
	collectDelay = 0.15,
	collectLoopDelay = 2,
	buyPackDelay = 0.2,
	buyPackLoopDelay = 2,
	rebirthLoopDelay = 5,
	craftDelay = 0.5,
	craftLoopDelay = 3,
	equipBestDelay = 5,
	tournamentCheckDelay = 5,
	gemShopBuyDelay = 1,
	gemShopLoopDelay = 5,
	gemClaimDelay = 10,
	tournamentShopLoopDelay = 10,
	tournamentShopBuyDelay = 0.5,
	tournamentShopMinTokensToKeep = 0,
	tournamentShopMaxBuysPerCycle = 3,

	keepInventoryAt = 200,
	maxSellPerCycle = 25,
	sellLoopDelay = 10,
	sellLockedCards = false,
	protectTournamentTeam = true,
	protectThroneCards = true,
	protectRebirthCards = true,
	minimumIncomeToKeep = math.huge,
	protectedRarities = {"Secret Exclusive", "Exclusive", "Primordial", "Divine"},
	protectedMutations = {"Misprint", "Divine"},
	protectedCardIdsText = "OwnerVulnone",
}

local Window = Rayfield:CreateWindow({
	Name = "BaconHub",
	Icon = 0,
	LoadingTitle = "BaconHub",
	LoadingSubtitle = "Spin a Soccer Card",
	ShowText = "BaconHub",
	Theme = "Default",
	ToggleUIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BaconHub",
		FileName = "SpinASoccerCard",
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 0)
local PacksTab = Window:CreateTab("Packs", 0)
local ShopsTab = Window:CreateTab("Shops", 0)
local TournamentTab = Window:CreateTab("Tournament", 0)
local InventoryTab = Window:CreateTab("Inventory", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

local function notify(title, content)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = 3,
		Image = 0,
	})
end

local function createDivider(tab)
	pcall(function()
		tab:CreateDivider()
	end)
end

local function getPlayerData()
	local currentState = playerStore()
	local players = currentState and currentState.players
	return players and players[tostring(player.UserId)] or nil
end

local function toSet(list)
	local set = {}

	for _, value in ipairs(list or {}) do
		set[value] = true
	end

	return set
end

local function sortedKeys(values)
	local keys = {}

	for key in pairs(values or {}) do
		table.insert(keys, tostring(key))
	end

	table.sort(keys)
	return keys
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

local function getSortedPackOptions(searchText)
	local options = {}
	local needle = string.lower(tostring(searchText or ""))

	for packName in pairs(packConfig.Packs or {}) do
		if needle == "" or string.find(string.lower(tostring(packName)), needle, 1, true) then
			table.insert(options, tostring(packName))
		end
	end

	table.sort(options)
	return options
end

local packOptions = getSortedPackOptions()
local trophyOptions = sortedKeys(trophyConfig.Trophies or {})
local tournamentShopOptions = {"card", "wctrophy", "misprintpotion", "gems", "spin", "wish", "pack", "trophy", "potion"}
local gemShopOptionToKey = {
	["Auto Skip"] = "AutoSkip",
	["Auto Equip Best"] = "AutoEquipBest",
	["Inventory +500"] = "Inventory500",
	["Auto Collect Money"] = "1642051165",
	["Super Mutation Luck"] = "1688290078",
	["VIP"] = "1691541199",
	["Ultra Mutation Luck"] = "1688240071",
}
local gemShopKeyToOption = {
	AutoSkip = "Auto Skip",
	AutoEquipBest = "Auto Equip Best",
	Inventory500 = "Inventory +500",
	["1642051165"] = "Auto Collect Money",
	["1688290078"] = "Super Mutation Luck",
	["1691541199"] = "VIP",
	["1688240071"] = "Ultra Mutation Luck",
}
local gemShopOptions = {
	"Auto Skip",
	"Auto Equip Best",
	"Inventory +500",
	"Auto Collect Money",
	"Super Mutation Luck",
	"VIP",
	"Ultra Mutation Luck",
}
local rarityOptions = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Primordial", "Exclusive", "Secret Exclusive"}
local mutationOptions = {"Misprint", "Divine"}

local function getSelectedGemShopKeys()
	local keys = {}

	for _, option in ipairs(state.selectedGemShopItems) do
		local key = gemShopOptionToKey[option] or option
		keys[key] = true
	end

	return keys
end

local function getSelectedTournamentKinds()
	return toSet(state.selectedTournamentShopKinds)
end

local packDropdowns = {}

local function trackPackDropdown(dropdown)
	if dropdown then
		table.insert(packDropdowns, dropdown)
	end

	return dropdown
end

local function refreshPackDropdowns()
	local filteredOptions = getSortedPackOptions(state.packSearchText)

	if #filteredOptions == 0 then
		filteredOptions = packOptions
	end

	for _, dropdown in ipairs(packDropdowns) do
		if dropdown and dropdown.Refresh then
			pcall(function()
				dropdown:Refresh(filteredOptions, false)
			end)
		end
	end
end

local function setDropdownSelection(dropdown, selectedOptions)
	if not dropdown then
		return
	end

	if dropdown.Set then
		pcall(function()
			dropdown:Set(selectedOptions)
		end)
	elseif dropdown.Refresh then
		pcall(function()
			dropdown:Refresh(getSortedPackOptions(state.packSearchText), selectedOptions)
		end)
	end
end

local lastAutoSkipState = nil
local lastHideAnimationState = nil

local function applyPackOpeningSettings()
	if lastAutoSkipState == state.useAutoSkip and lastHideAnimationState == state.hideAnimationWhenAutoSkip then
		return
	end

	packSettingsEvent:FireServer("packAutoSkip", state.useAutoSkip)
	packSettingsEvent:FireServer("packHideAnimation", state.useAutoSkip and state.hideAnimationWhenAutoSkip or false)
	lastAutoSkipState = state.useAutoSkip
	lastHideAnimationState = state.hideAnimationWhenAutoSkip
end

local function getPackCount()
	local leaderstats = player:FindFirstChild("leaderstats")
	local packs = leaderstats and leaderstats:FindFirstChild("Packs")
	return packs and packs.Value or nil
end

local openPackCursor = 0
local lastPackOpenAt = 0

local function getOwnedPackCount(playerData, packName)
	local packs = playerData and playerData.packs
	return packs and (packs[packName] or 0) or 0
end

local function openPack(packName)
	if not packName or packName == "" then
		return false
	end

	local now = os.clock()
	local delay = state.useAutoSkip and state.autoSkipOpenDelay or state.openDelay
	if now - lastPackOpenAt < delay then
		task.wait(delay - (now - lastPackOpenAt))
	end

	openPackEvent:FireServer(packName)
	lastPackOpenAt = os.clock()
	return true
end

local function getNextOpenPack()
	local selectedPacks = state.selectedOpenPacks

	if type(selectedPacks) ~= "table" or #selectedPacks == 0 then
		return nil
	end

	local playerData = getPlayerData()

	for _ = 1, #selectedPacks do
		openPackCursor = (openPackCursor % #selectedPacks) + 1
		local packName = selectedPacks[openPackCursor]

		if getOwnedPackCount(playerData, packName) > 0 then
			return packName
		end
	end

	return selectedPacks[1]
end

local function canBuyPack(playerData, packName)
	local info = packConfig.Packs and packConfig.Packs[packName]
	local shop = playerData and playerData.shop
	local stocks = shop and shop.stocks
	local stock = stocks and (stocks[packName] or 0) or 0

	if not info or stock <= 0 then
		return false
	end

	if (playerData.rebirth or 0) < (info.RebirthReq or 0) then
		return false
	end

	local price = info.Price or 0
	if info.Currency == "Gems" then
		return (playerData.gems or 0) >= price
	end

	return (playerData.cash or 0) >= price
end

local function getSortedCardsByIncome(cards, incomeByUuid)
	local sortedCards = {}

	for _, card in ipairs(cards) do
		table.insert(sortedCards, card)
	end

	table.sort(sortedCards, function(left, right)
		local leftIncome = incomeByUuid[left.uuid] or 0
		local rightIncome = incomeByUuid[right.uuid] or 0

		if leftIncome == rightIncome then
			return (left.acquiredDate or 0) < (right.acquiredDate or 0)
		end

		return leftIncome < rightIncome
	end)

	return sortedCards
end

local function getRebirthRequirementCardSet(playerData, incomeByUuid)
	local protectedUuids = {}
	local usedUuids = {}
	local inventory = playerData and playerData.inventory or {}
	local rebirth = playerData and playerData.rebirth or 0
	local nextRebirth = rebirthConfig.GetRebirth(rebirth + 1)

	if not nextRebirth then
		return protectedUuids
	end

	incomeByUuid = incomeByUuid or scalingIncome.computeAll(inventory)

	for _, requirement in ipairs(nextRebirth.RequiredCards or {}) do
		local isAny, value = rebirthConfig.ParseCardRequirement(requirement)

		if not isAny then
			local choices = {}

			for _, card in ipairs(inventory) do
				if card.id == value and card.uuid and not usedUuids[card.uuid] then
					table.insert(choices, card)
				end
			end

			local card = getSortedCardsByIncome(choices, incomeByUuid)[1]
			if card then
				usedUuids[card.uuid] = true
				protectedUuids[card.uuid] = true
			end
		end
	end

	for _, requirement in ipairs(nextRebirth.RequiredCards or {}) do
		local isAny, value = rebirthConfig.ParseCardRequirement(requirement)

		if isAny then
			local choices = {}

			for _, card in ipairs(inventory) do
				local cardInfo = cardConfig.Cards[card.id]

				if card.uuid and not usedUuids[card.uuid] and cardInfo and cardInfo.Rarity == value then
					table.insert(choices, card)
				end
			end

			local card = getSortedCardsByIncome(choices, incomeByUuid)[1]
			if card then
				usedUuids[card.uuid] = true
				protectedUuids[card.uuid] = true
			end
		end
	end

	return protectedUuids
end

local function canRebirthNow(playerData)
	if not playerData then
		return false
	end

	local rebirth = playerData.rebirth or 0
	if rebirthConfig.GetMaxRebirth() <= rebirth then
		return false
	end

	local nextRebirth = rebirthConfig.GetRebirth(rebirth + 1)
	if not nextRebirth then
		return false
	end

	if (playerData.cash or 0) < (nextRebirth.CashRequired or 0) then
		return false
	end

	if nextRebirth.GemsRequired and (playerData.gems or 0) < nextRebirth.GemsRequired then
		return false
	end

	local protectedUuids = getRebirthRequirementCardSet(playerData)
	local requiredCount = #(nextRebirth.RequiredCards or {})
	local foundCount = 0

	for _ in pairs(protectedUuids) do
		foundCount += 1
	end

	return foundCount >= requiredCount
end

local function getPlacedCardSlots()
	local playerData = getPlayerData()
	local slots = playerData and playerData.slots
	local slotNumbers = {}

	if type(slots) ~= "table" then
		return slotNumbers
	end

	for slotNumber, slotData in pairs(slots) do
		if type(slotData) == "table" and slotData.card then
			table.insert(slotNumbers, tonumber(slotNumber) or slotNumber)
		end
	end

	table.sort(slotNumbers, function(a, b)
		return tonumber(a) < tonumber(b)
	end)

	return slotNumbers
end

local function getCardCounts(playerData)
	local countsById = {}
	local countsByRarity = {}
	local unlockedCountsById = {}
	local unlockedCountsByRarity = {}

	for _, card in ipairs(playerData and playerData.inventory or {}) do
		local cardId = card.id
		local cardInfo = cardId and cardConfig.Cards[cardId]
		local rarity = cardInfo and cardInfo.Rarity

		if cardId then
			countsById[cardId] = (countsById[cardId] or 0) + 1
		end

		if rarity then
			countsByRarity[rarity] = (countsByRarity[rarity] or 0) + 1
		end

		if not card.locked then
			if cardId then
				unlockedCountsById[cardId] = (unlockedCountsById[cardId] or 0) + 1
			end

			if rarity then
				unlockedCountsByRarity[rarity] = (unlockedCountsByRarity[rarity] or 0) + 1
			end
		end
	end

	return countsById, countsByRarity, unlockedCountsById, unlockedCountsByRarity
end

local function hasCraftRequirements(trophyInfo, countsById, countsByRarity, unlockedCountsById, unlockedCountsByRarity)
	for _, requirement in ipairs(trophyInfo.Requirements or {}) do
		local requiredAmount = requirement.amount or 0
		local total = 0
		local unlocked = 0

		if requirement.type == "specific" then
			total = countsById[requirement.cardId] or 0
			unlocked = unlockedCountsById[requirement.cardId] or 0
		elseif requirement.type == "any" then
			total = countsByRarity[requirement.rarity] or 0
			unlocked = unlockedCountsByRarity[requirement.rarity] or 0
		end

		if total < requiredAmount or unlocked < requiredAmount then
			return false
		end
	end

	return true
end

local function canCraftTrophy(playerData, trophyName)
	local trophyInfo = trophyConfig.Trophies and trophyConfig.Trophies[trophyName]
	local craftShop = playerData and playerData.craftShop
	local inStock = craftShop and craftShop.stocks and craftShop.stocks[trophyName] == true
	local alreadyCrafted = craftShop
		and craftShop.periodId == trophyConfig.getCurrentPeriodId()
		and craftShop.crafted
		and craftShop.crafted[trophyName] == true

	if not trophyInfo or not inStock or alreadyCrafted then
		return false
	end

	return hasCraftRequirements(trophyInfo, getCardCounts(playerData))
end

local function getMissingCraftRarities(playerData, trophyName)
	local trophyInfo = trophyConfig.Trophies and trophyConfig.Trophies[trophyName]
	local _, _, unlockedCountsById, unlockedCountsByRarity = getCardCounts(playerData)
	local missingRarities = {}

	if not trophyInfo then
		return missingRarities
	end

	for _, requirement in ipairs(trophyInfo.Requirements or {}) do
		local requiredAmount = requirement.amount or 0

		if requirement.type == "specific" then
			local unlocked = unlockedCountsById[requirement.cardId] or 0
			local cardInfo = cardConfig.Cards[requirement.cardId]

			if unlocked < requiredAmount and cardInfo and cardInfo.Rarity then
				missingRarities[cardInfo.Rarity] = true
			end
		elseif requirement.type == "any" then
			local unlocked = unlockedCountsByRarity[requirement.rarity] or 0

			if unlocked < requiredAmount then
				missingRarities[requirement.rarity] = true
			end
		end
	end

	return missingRarities
end

local function packHasRarity(packInfo, rarity)
	if not packInfo or not rarity then
		return false
	end

	if packInfo.Rewards and packInfo.Rewards[rarity] then
		return true
	end

	if packInfo.HiddenRewards and packInfo.HiddenRewards[rarity] then
		return true
	end

	for _, scaleRewards in ipairs(packInfo.ScaleRewards or {}) do
		if scaleRewards[rarity] then
			return true
		end
	end

	return false
end

local function packHasAnyMissingCraftRarity(packName, missingRarities)
	local packInfo = packConfig.Packs and packConfig.Packs[packName]

	for rarity in pairs(missingRarities) do
		if packHasRarity(packInfo, rarity) then
			return true
		end
	end

	return false
end

local function isTrophyInCraftShop(playerData, trophyName)
	local craftShop = playerData and playerData.craftShop
	local alreadyCrafted = craftShop
		and craftShop.periodId == trophyConfig.getCurrentPeriodId()
		and craftShop.crafted
		and craftShop.crafted[trophyName] == true

	return craftShop and craftShop.stocks and craftShop.stocks[trophyName] == true and not alreadyCrafted
end

local function getCraftMaterialPackToOpen(playerData, trophyName)
	if not state.autoCraftOpenPacks or not isTrophyInCraftShop(playerData, trophyName) or canCraftTrophy(playerData, trophyName) then
		return nil
	end

	local missingRarities = getMissingCraftRarities(playerData, trophyName)

	for _, packName in ipairs(state.selectedCraftMaterialPacks) do
		if getOwnedPackCount(playerData, packName) > 0 and packHasAnyMissingCraftRarity(packName, missingRarities) then
			return packName
		end
	end

	return nil
end

local function hasTournamentTeam(playerData)
	local tournament = playerData and playerData.tournament
	local team = tournament and tournament.team
	return type(team) == "table" and #team >= 5
end

local function isTournamentQueued(playerData)
	local tournament = playerData and playerData.tournament
	return tournament and tournament.queue ~= nil
end

local function canJoinTournament(playerData)
	if not playerData or isTournamentQueued(playerData) then
		return false
	end

	if (playerData.rebirth or 0) < (tournamentConfig.MinRebirth or 1) then
		return false
	end

	if tournamentClock.derivePhase(workspace:GetServerTimeNow()) ~= "join_window" then
		return false
	end

	local entryFee = tournamentClock.computeEntryFee(playerData.rebirth or 0, playerData.cash or 0)
	return (playerData.cash or 0) >= entryFee
end

local function hasGemShopGamepass(playerData, gamepassId)
	local gamepasses = playerData and playerData.gamepasses
	return gamepasses and gamepasses[tostring(gamepassId)] ~= nil
end

local function getFixedGemShopItem(key)
	local itemConfig = gemShopConfig.FixedGamepassesByKey and gemShopConfig.FixedGamepassesByKey[key]
	local currentGemShopState = gemShopState()
	local itemState = currentGemShopState and currentGemShopState.fixedItems and currentGemShopState.fixedItems[key]
	return itemConfig, itemState
end

local function getLuckyGemShopKey()
	local currentGemShopState = gemShopState()
	local luckyItem = currentGemShopState and currentGemShopState.luckyItem

	if not luckyItem then
		return nil, nil
	end

	for _, itemConfig in ipairs(gemShopConfig.FixedGamepasses or {}) do
		if itemConfig.Id == luckyItem.gamepassId then
			return itemConfig.Key, luckyItem
		end
	end

	return tostring(luckyItem.gamepassId), luckyItem
end

local function tryBuyFixedGemShopItem(playerData, key)
	local itemConfig, itemState = getFixedGemShopItem(key)

	if not itemConfig or not itemState or not itemState.inStock then
		return false
	end

	if hasGemShopGamepass(playerData, itemConfig.Id) then
		return false
	end

	if (playerData.gems or 0) < (itemState.price or math.huge) then
		return false
	end

	buyGemShopItem:FireServer("fixed", key)
	return true
end

local function tryBuyLuckyGemShopItem(playerData, selectedKeys)
	local luckyKey, luckyItem = getLuckyGemShopKey()

	if not luckyKey or not selectedKeys[luckyKey] then
		return false
	end

	if hasGemShopGamepass(playerData, luckyItem.gamepassId) then
		return false
	end

	if (playerData.gems or 0) < (luckyItem.price or math.huge) then
		return false
	end

	buyGemShopItem:FireServer("lucky")
	return true
end

local function getTournamentRewardKind(reward)
	local payload = reward and reward.payload
	return payload and payload.kind or reward and reward.kind or reward and reward.id
end

local tournamentShopKindPriority = {
	gems = 1,
	spin = 2,
	wish = 3,
	pack = 4,
	potion = 5,
	trophy = 6,
	misprintpotion = 7,
	wctrophy = 8,
	card = 9,
}

local function canBuyTournamentReward(playerData, reward, selectedKinds)
	local tournament = playerData and playerData.tournament
	local tokens = tournament and tournament.tokens or 0
	local kind = getTournamentRewardKind(reward)
	local price = reward and reward.price or math.huge
	local stock = reward and reward.stock or 0

	if not kind or selectedKinds[kind] ~= true then
		return false
	end

	if reward.claimed == true or stock <= 0 then
		return false
	end

	return price <= tokens and tokens - price >= state.tournamentShopMinTokensToKeep
end

local function getBuyableTournamentRewards(playerData)
	local shop = playerData and playerData.tournament and playerData.tournament.shop
	local rewards = shop and shop.rewards
	local selectedKinds = getSelectedTournamentKinds()
	local buyable = {}

	if type(rewards) ~= "table" then
		return buyable
	end

	for index, reward in ipairs(rewards) do
		if canBuyTournamentReward(playerData, reward, selectedKinds) then
			table.insert(buyable, {
				index = index,
				reward = reward,
				kind = getTournamentRewardKind(reward),
			})
		end
	end

	table.sort(buyable, function(left, right)
		local leftPriority = tournamentShopKindPriority[left.kind] or 999
		local rightPriority = tournamentShopKindPriority[right.kind] or 999

		if leftPriority == rightPriority then
			return (left.reward.price or math.huge) < (right.reward.price or math.huge)
		end

		return leftPriority < rightPriority
	end)

	return buyable
end

local function getTournamentTeamSet(playerData)
	local teamSet = {}
	local tournament = playerData and playerData.tournament
	local team = tournament and tournament.team

	if type(team) == "table" then
		for _, uuid in ipairs(team) do
			teamSet[uuid] = true
		end
	end

	return teamSet
end

local function getProtectedCardIdSet()
	local set = {}

	for id in string.gmatch(state.protectedCardIdsText or "", "[^,%s]+") do
		set[id] = true
	end

	return set
end

local function hasProtectedMutation(card, protectedMutations)
	for _, mutation in ipairs(card.mutations or {}) do
		if protectedMutations[mutation] then
			return true
		end
	end

	return false
end

local function canSellCard(card, cardInfo, teamSet, protectedRarities, protectedMutations, protectedCardIds, rebirthRequirementSet)
	if not card or not card.uuid or not cardInfo then
		return false
	end

	if card.locked and not state.sellLockedCards then
		return false
	end

	if state.protectThroneCards and card.throneCard then
		return false
	end

	if state.protectTournamentTeam and teamSet[card.uuid] then
		return false
	end

	if state.protectRebirthCards and rebirthRequirementSet[card.uuid] then
		return false
	end

	if protectedCardIds[card.id] or protectedRarities[cardInfo.Rarity] or hasProtectedMutation(card, protectedMutations) then
		return false
	end

	return true
end

local function getWorstSellCandidates(playerData)
	local inventory = playerData and playerData.inventory or {}
	local amountToSell = math.min(#inventory - state.keepInventoryAt, state.maxSellPerCycle)

	if amountToSell <= 0 then
		return {}
	end

	local incomeByUuid = scalingIncome.computeAll(inventory)
	local teamSet = getTournamentTeamSet(playerData)
	local protectedRarities = toSet(state.protectedRarities)
	local protectedMutations = toSet(state.protectedMutations)
	local protectedCardIds = getProtectedCardIdSet()
	local rebirthRequirementSet = getRebirthRequirementCardSet(playerData, incomeByUuid)
	local candidates = {}

	for _, card in ipairs(inventory) do
		local cardInfo = cardConfig.Cards[card.id]
		local income = incomeByUuid[card.uuid] or 0

		if income < state.minimumIncomeToKeep and canSellCard(card, cardInfo, teamSet, protectedRarities, protectedMutations, protectedCardIds, rebirthRequirementSet) then
			table.insert(candidates, {
				uuid = card.uuid,
				income = income,
				acquiredDate = card.acquiredDate or 0,
				id = card.id or "",
			})
		end
	end

	table.sort(candidates, function(a, b)
		if a.income == b.income then
			if a.acquiredDate == b.acquiredDate then
				return a.uuid < b.uuid
			end

			return a.acquiredDate < b.acquiredDate
		end

		return a.income < b.income
	end)

	local uuids = {}
	for index, candidate in ipairs(candidates) do
		if index > amountToSell then
			break
		end

		table.insert(uuids, candidate.uuid)
	end

	return uuids
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

task.spawn(function()
	while task.wait() do
		if state.autoOpenPacks then
			local success, err = pcall(function()
				applyPackOpeningSettings()
				local packCount = getPackCount()
				local packName = getNextOpenPack()

				if packName and (not packCount or packCount > 0) then
					openPack(packName)
				else
					task.wait(1)
				end
			end)

			if not success then
				warn("Auto Open Packs failed:", err)
				task.wait(1)
			end
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoWish then
			local playerData = getPlayerData()
			local tickets = playerData and playerData.wish and playerData.wish.tickets or 0

			if tickets > 0 then
				local success, result = pcall(function()
					return performWish:InvokeServer()
				end)

				if not success or (type(result) == "table" and result.reason == "rate_limited") then
					task.wait(3)
				else
					task.wait(state.wishDelay)
				end
			else
				task.wait(3)
			end
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoSpin then
			local success, data = pcall(function()
				return spinWheelData:InvokeServer()
			end)

			if success and data then
				if data.canClaimFree then
					pcall(function()
						spinWheelEvent:FireServer("claim_free")
					end)
					task.wait(0.5)
					pcall(function()
						spinWheelEvent:FireServer("spin")
					end)
				end

				task.wait(state.spinLoopDelay)
			else
				task.wait(3)
			end
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoCollectMoney then
			for _, slotNumber in ipairs(getPlacedCardSlots()) do
				if not state.autoCollectMoney then
					break
				end

				pcall(function()
					collectSlotEvent:FireServer(slotNumber)
				end)
				task.wait(state.collectDelay)
			end

			task.wait(state.collectLoopDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoBuyPacks then
			for _, packName in ipairs(state.selectedBuyPacks) do
				if not state.autoBuyPacks then
					break
				end

				local playerData = getPlayerData()
				if playerData and canBuyPack(playerData, packName) then
					pcall(function()
						buyPackEvent:FireServer(packName)
					end)
					task.wait(state.buyPackDelay)
				end
			end

			task.wait(state.buyPackLoopDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoRebirth then
			local playerData = getPlayerData()

			if canRebirthNow(playerData) then
				pcall(function()
					rebirthEvent:FireServer()
				end)
				task.wait(state.rebirthLoopDelay)
			else
				task.wait(state.rebirthLoopDelay)
			end
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoCraft then
			for _, trophyName in ipairs(state.selectedCraftTrophies) do
				if not state.autoCraft then
					break
				end

				local playerData = getPlayerData()
				if playerData and canCraftTrophy(playerData, trophyName) then
					pcall(function()
						craftTrophyEvent:FireServer(trophyName)
					end)
					task.wait(state.craftDelay)
				elseif playerData then
					local materialPackName = getCraftMaterialPackToOpen(playerData, trophyName)

					if materialPackName then
						pcall(function()
							openPack(materialPackName)
						end)
					end
				end
			end

			task.wait(state.craftLoopDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoEquipBest then
			pcall(function()
				slotController.equipBestCards(true)
			end)
			task.wait(state.equipBestDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoJoinTournament then
			local playerData = getPlayerData()

			if canJoinTournament(playerData) then
				pcall(function()
					tournamentRemote:FireServer("equip_best")
				end)
				task.wait(1)
				playerData = getPlayerData()

				if canJoinTournament(playerData) and hasTournamentTeam(playerData) then
					pcall(function()
						tournamentRemote:FireServer("join")
					end)
				end
			end

			task.wait(state.tournamentCheckDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoBuyGemShop then
			local playerData = getPlayerData()
			local selectedKeys = getSelectedGemShopKeys()

			if playerData then
				for key, enabled in pairs(selectedKeys) do
					if not state.autoBuyGemShop then
						break
					end

					if enabled and gemShopConfig.FixedGamepassesByKey and gemShopConfig.FixedGamepassesByKey[key] then
						local success, bought = pcall(function()
							return tryBuyFixedGemShopItem(playerData, key)
						end)

						if success and bought then
							task.wait(state.gemShopBuyDelay)
							playerData = getPlayerData()
						end
					end
				end

				local success, bought = pcall(function()
					return tryBuyLuckyGemShopItem(playerData, selectedKeys)
				end)

				if success and bought then
					task.wait(state.gemShopBuyDelay)
				end
			end

			task.wait(state.gemShopLoopDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoCollectGems then
			pcall(function()
				claimAllIndexGemsEvent:FireServer()
			end)
			task.wait(state.gemClaimDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoSellCards then
			local uuidsToSell = getWorstSellCandidates(getPlayerData())

			if #uuidsToSell > 0 then
				pcall(function()
					sellCardsEvent:FireServer(uuidsToSell)
				end)
				task.wait(1)
			end

			task.wait(state.sellLoopDelay)
		end
	end
end)

task.spawn(function()
	while task.wait(0.25) do
		if state.autoBuyTournamentShop then
			local boughtThisCycle = 0

			while state.autoBuyTournamentShop and boughtThisCycle < state.tournamentShopMaxBuysPerCycle do
				local entry = getBuyableTournamentRewards(getPlayerData())[1]

				if not entry then
					break
				end

				pcall(function()
					tournamentShopRemote:FireServer("buy", entry.index)
				end)
				boughtThisCycle += 1
				task.wait(state.tournamentShopBuyDelay)
			end

			task.wait(state.tournamentShopLoopDelay)
		end
	end
end)

MainTab:CreateSection("AFK")

MainTab:CreateToggle({
	Name = "Auto Collect Money",
	CurrentValue = false,
	Flag = "AutoCollectMoney",
	Callback = function(value)
		state.autoCollectMoney = value
		notify("Auto Collect Money", value and "Enabled" or "Disabled")
	end,
})

MainTab:CreateToggle({
	Name = "Auto Collect Gems",
	CurrentValue = false,
	Flag = "AutoCollectGems",
	Callback = function(value)
		state.autoCollectGems = value
		notify("Auto Collect Gems", value and "Enabled" or "Disabled")
	end,
})

MainTab:CreateToggle({
	Name = "Auto Equip Best",
	CurrentValue = false,
	Flag = "AutoEquipBest",
	Callback = function(value)
		state.autoEquipBest = value
		notify("Auto Equip Best", value and "Enabled" or "Disabled")
	end,
})

createDivider(MainTab)

MainTab:CreateSection("Free Rewards")

MainTab:CreateToggle({
	Name = "Auto Wish",
	CurrentValue = false,
	Flag = "AutoWish",
	Callback = function(value)
		state.autoWish = value
		notify("Auto Wish", value and "Enabled" or "Disabled")
	end,
})

MainTab:CreateToggle({
	Name = "Auto Spin Free Spin",
	CurrentValue = false,
	Flag = "AutoSpinFreeSpin",
	Callback = function(value)
		state.autoSpin = value
		notify("Auto Spin", value and "Enabled" or "Disabled")
	end,
})

createDivider(MainTab)

MainTab:CreateSection("Progression")

MainTab:CreateToggle({
	Name = "Auto Rebirth",
	CurrentValue = false,
	Flag = "AutoRebirth",
	Callback = function(value)
		state.autoRebirth = value
		notify("Auto Rebirth", value and "Enabled" or "Disabled")
	end,
})

PacksTab:CreateSection("Pack Selection")

local openPacksDropdown
local buyPacksDropdown

PacksTab:CreateInput({
	Name = "Pack Search",
	CurrentValue = "",
	PlaceholderText = "Type to filter pack dropdowns",
	RemoveTextAfterFocusLost = false,
	Flag = "PackSearch",
	Callback = function(value)
		state.packSearchText = tostring(value or "")
		refreshPackDropdowns()
	end,
})

createDivider(PacksTab)

PacksTab:CreateSection("Open Packs")

openPacksDropdown = trackPackDropdown(PacksTab:CreateDropdown({
	Name = "Open Packs",
	Options = packOptions,
	CurrentOption = state.selectedOpenPacks,
	MultipleOptions = true,
	Flag = "OpenPack",
	Callback = function(option)
		state.selectedOpenPacks = getMultiOptions(option)
	end,
}))

PacksTab:CreateButton({
	Name = "Select All Open Packs",
	Callback = function()
		state.selectedOpenPacks = copyList(packOptions)
		setDropdownSelection(openPacksDropdown, state.selectedOpenPacks)
		notify("Open Packs", "Selected all packs.")
	end,
})

PacksTab:CreateButton({
	Name = "Clear Open Packs",
	Callback = function()
		state.selectedOpenPacks = {}
		setDropdownSelection(openPacksDropdown, state.selectedOpenPacks)
		notify("Open Packs", "Cleared selected packs.")
	end,
})

PacksTab:CreateToggle({
	Name = "Auto Open Selected Packs",
	CurrentValue = false,
	Flag = "AutoOpenPacks",
	Callback = function(value)
		state.autoOpenPacks = value
		notify("Auto Open Packs", value and "Enabled" or "Disabled")
	end,
})

PacksTab:CreateToggle({
	Name = "Use Auto Skip",
	CurrentValue = false,
	Flag = "UseAutoSkip",
	Callback = function(value)
		state.useAutoSkip = value
		lastAutoSkipState = nil
	end,
})

PacksTab:CreateToggle({
	Name = "Hide Pack Animation With Auto Skip",
	CurrentValue = true,
	Flag = "HidePackAnimation",
	Callback = function(value)
		state.hideAnimationWhenAutoSkip = value
		lastHideAnimationState = nil
	end,
})

createDivider(PacksTab)

PacksTab:CreateSection("Buy Packs")

buyPacksDropdown = trackPackDropdown(PacksTab:CreateDropdown({
	Name = "Packs To Buy",
	Options = packOptions,
	CurrentOption = state.selectedBuyPacks,
	MultipleOptions = true,
	Flag = "PacksToBuy",
	Callback = function(option)
		state.selectedBuyPacks = getMultiOptions(option)
	end,
}))

PacksTab:CreateButton({
	Name = "Select All Buy Packs",
	Callback = function()
		state.selectedBuyPacks = copyList(packOptions)
		setDropdownSelection(buyPacksDropdown, state.selectedBuyPacks)
		notify("Buy Packs", "Selected all packs.")
	end,
})

PacksTab:CreateButton({
	Name = "Clear Buy Packs",
	Callback = function()
		state.selectedBuyPacks = {}
		setDropdownSelection(buyPacksDropdown, state.selectedBuyPacks)
		notify("Buy Packs", "Cleared selected packs.")
	end,
})

PacksTab:CreateToggle({
	Name = "Auto Buy Selected Packs",
	CurrentValue = false,
	Flag = "AutoBuyPacks",
	Callback = function(value)
		state.autoBuyPacks = value
		notify("Auto Buy Packs", value and "Enabled" or "Disabled")
	end,
})

ShopsTab:CreateSection("Crafting")

ShopsTab:CreateDropdown({
	Name = "Craft Trophies",
	Options = trophyOptions,
	CurrentOption = state.selectedCraftTrophies,
	MultipleOptions = true,
	Flag = "CraftTrophies",
	Callback = function(option)
		state.selectedCraftTrophies = getMultiOptions(option)
	end,
})

ShopsTab:CreateToggle({
	Name = "Auto Craft Selected Trophies",
	CurrentValue = false,
	Flag = "AutoCraft",
	Callback = function(value)
		state.autoCraft = value
		notify("Auto Craft", value and "Enabled" or "Disabled")
	end,
})

trackPackDropdown(ShopsTab:CreateDropdown({
	Name = "Craft Material Packs",
	Options = packOptions,
	CurrentOption = state.selectedCraftMaterialPacks,
	MultipleOptions = true,
	Flag = "CraftMaterialPacks",
	Callback = function(option)
		state.selectedCraftMaterialPacks = getMultiOptions(option)
	end,
}))

ShopsTab:CreateToggle({
	Name = "Open Material Packs For Crafting",
	CurrentValue = false,
	Flag = "OpenMaterialPacksForCrafting",
	Callback = function(value)
		state.autoCraftOpenPacks = value
		notify("Craft Materials", value and "Enabled" or "Disabled")
	end,
})

createDivider(ShopsTab)

ShopsTab:CreateSection("Gem Shop")

ShopsTab:CreateDropdown({
	Name = "Gem Shop Items",
	Options = gemShopOptions,
	CurrentOption = {"Auto Skip"},
	MultipleOptions = true,
	Flag = "GemShopItems",
	Callback = function(option)
		state.selectedGemShopItems = getMultiOptions(option)
	end,
})

ShopsTab:CreateToggle({
	Name = "Auto Buy Selected Gem Shop Items",
	CurrentValue = false,
	Flag = "AutoBuyGemShop",
	Callback = function(value)
		state.autoBuyGemShop = value
		notify("Auto Buy Gem Shop", value and "Enabled" or "Disabled")
	end,
})

TournamentTab:CreateSection("Queue")

TournamentTab:CreateToggle({
	Name = "Auto Join Tournament",
	CurrentValue = false,
	Flag = "AutoJoinTournament",
	Callback = function(value)
		state.autoJoinTournament = value
		notify("Auto Join Tournament", value and "Enabled" or "Disabled")
	end,
})

createDivider(TournamentTab)

TournamentTab:CreateSection("Tournament Shop")

TournamentTab:CreateDropdown({
	Name = "Reward Types To Buy",
	Options = tournamentShopOptions,
	CurrentOption = state.selectedTournamentShopKinds,
	MultipleOptions = true,
	Flag = "TournamentShopKinds",
	Callback = function(option)
		state.selectedTournamentShopKinds = getMultiOptions(option)
	end,
})

TournamentTab:CreateToggle({
	Name = "Auto Buy Tournament Shop Rewards",
	CurrentValue = false,
	Flag = "AutoBuyTournamentShop",
	Callback = function(value)
		state.autoBuyTournamentShop = value
		notify("Tournament Shop", value and "Enabled" or "Disabled")
	end,
})

TournamentTab:CreateSlider({
	Name = "Minimum Tokens To Keep",
	Range = {0, 5000},
	Increment = 1,
	Suffix = " tokens",
	CurrentValue = 0,
	Flag = "TournamentShopMinTokens",
	Callback = function(value)
		state.tournamentShopMinTokensToKeep = value
	end,
})

TournamentTab:CreateSlider({
	Name = "Max Buys Per Cycle",
	Range = {1, 10},
	Increment = 1,
	Suffix = " buys",
	CurrentValue = 3,
	Flag = "TournamentShopMaxBuys",
	Callback = function(value)
		state.tournamentShopMaxBuysPerCycle = value
	end,
})

InventoryTab:CreateSection("Selling")

InventoryTab:CreateToggle({
	Name = "Auto Sell Worst Cards",
	CurrentValue = false,
	Flag = "AutoSellCards",
	Callback = function(value)
		state.autoSellCards = value
		notify("Auto Sell Cards", value and "Enabled" or "Disabled")
	end,
})

InventoryTab:CreateSlider({
	Name = "Keep Inventory At",
	Range = {0, 500},
	Increment = 25,
	Suffix = " cards",
	CurrentValue = state.keepInventoryAt,
	Flag = "KeepInventoryAt",
	Callback = function(value)
		state.keepInventoryAt = math.clamp(value, 0, 500)
	end,
})

InventoryTab:CreateSlider({
	Name = "Max Sell Per Cycle",
	Range = {1, 500},
	Increment = 1,
	Suffix = " cards",
	CurrentValue = state.maxSellPerCycle,
	Flag = "MaxSellPerCycle",
	Callback = function(value)
		state.maxSellPerCycle = math.clamp(value, 1, 500)
	end,
})

InventoryTab:CreateInput({
	Name = "Minimum Income To Keep",
	CurrentValue = "inf",
	PlaceholderText = "inf or number",
	RemoveTextAfterFocusLost = false,
	Flag = "MinimumIncomeToKeep",
	Callback = function(value)
		local lowered = string.lower(tostring(value or ""))
		state.minimumIncomeToKeep = (lowered == "inf" or lowered == "infinite") and math.huge or tonumber(value) or math.huge
	end,
})

createDivider(InventoryTab)

InventoryTab:CreateDropdown({
	Name = "Protected Rarities",
	Options = rarityOptions,
	CurrentOption = state.protectedRarities,
	MultipleOptions = true,
	Flag = "ProtectedRarities",
	Callback = function(option)
		state.protectedRarities = getMultiOptions(option)
	end,
})

InventoryTab:CreateDropdown({
	Name = "Protected Mutations",
	Options = mutationOptions,
	CurrentOption = state.protectedMutations,
	MultipleOptions = true,
	Flag = "ProtectedMutations",
	Callback = function(option)
		state.protectedMutations = getMultiOptions(option)
	end,
})

InventoryTab:CreateInput({
	Name = "Protected Card Ids",
	CurrentValue = state.protectedCardIdsText,
	PlaceholderText = "Comma or space separated ids",
	RemoveTextAfterFocusLost = false,
	Flag = "ProtectedCardIds",
	Callback = function(value)
		state.protectedCardIdsText = tostring(value or "")
	end,
})

InventoryTab:CreateToggle({
	Name = "Sell Locked Cards",
	CurrentValue = false,
	Flag = "SellLockedCards",
	Callback = function(value)
		state.sellLockedCards = value
	end,
})

InventoryTab:CreateToggle({
	Name = "Protect Tournament Team",
	CurrentValue = true,
	Flag = "ProtectTournamentTeam",
	Callback = function(value)
		state.protectTournamentTeam = value
	end,
})

InventoryTab:CreateToggle({
	Name = "Protect Throne Cards",
	CurrentValue = true,
	Flag = "ProtectThroneCards",
	Callback = function(value)
		state.protectThroneCards = value
	end,
})

InventoryTab:CreateToggle({
	Name = "Protect Rebirth Requirement Cards",
	CurrentValue = true,
	Flag = "ProtectRebirthRequirementCards",
	Callback = function(value)
		state.protectRebirthCards = value
	end,
})

SettingsTab:CreateSection("Delays")

SettingsTab:CreateSlider({
	Name = "Open Delay",
	Range = {0.05, 2},
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = state.openDelay,
	Flag = "OpenDelay",
	Callback = function(value)
		state.openDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Auto Skip Open Delay",
	Range = {0.05, 1},
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = state.autoSkipOpenDelay,
	Flag = "AutoSkipOpenDelay",
	Callback = function(value)
		state.autoSkipOpenDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Collect Money Loop Delay",
	Range = {0.5, 10},
	Increment = 0.5,
	Suffix = "s",
	CurrentValue = state.collectLoopDelay,
	Flag = "CollectMoneyLoopDelay",
	Callback = function(value)
		state.collectLoopDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Shop Loop Delay",
	Range = {1, 30},
	Increment = 1,
	Suffix = "s",
	CurrentValue = state.gemShopLoopDelay,
	Flag = "ShopLoopDelay",
	Callback = function(value)
		state.gemShopLoopDelay = value
		state.tournamentShopLoopDelay = value
	end,
})

SettingsTab:CreateSlider({
	Name = "Auto Sell Loop Delay",
	Range = {2, 60},
	Increment = 1,
	Suffix = "s",
	CurrentValue = state.sellLoopDelay,
	Flag = "AutoSellLoopDelay",
	Callback = function(value)
		state.sellLoopDelay = value
	end,
})

createDivider(SettingsTab)

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
