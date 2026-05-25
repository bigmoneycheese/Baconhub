local loaderSource = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/main.lua"))()'

local queueTeleport = queue_on_teleport
	or queueonteleport
	or (syn and syn.queue_on_teleport)
	or (fluxus and fluxus.queue_on_teleport)

if queueTeleport then
	pcall(queueTeleport, loaderSource)
end

local scripts = {
	[6170143659] = {
		name = "Demonology",
		path = "scripts/Demonology.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/Demonology.lua",
	},
	[9754968779] = {
		name = "+1 Health Per Click",
		path = "scripts/PlusOneHealthPerClick.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/PlusOneHealthPerClick.lua",
	},
	[10000383119] = {
		name = "Gun Evolution",
		path = "scripts/GunEvolution.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/GunEvolution.lua",
	},
	[9792947201] = {
		name = "Slime RNG",
		path = "scripts/SlimeRNG.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/SlimeRNG.lua",
	},
	[10011808151] = {
		name = "+1 Shrink per Step",
		path = "scripts/PlusOneShrinkPerStep.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/PlusOneShrinkPerStep.lua",
	},
	[6331902150] = {
		name = "Forsaken",
		path = "scripts/Forsaken.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/Forsaken.lua",
	},
	[8639693426] = {
		name = "SLAP",
		path = "scripts/Slap.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/Slap.lua",
	},
	[9272693470] = {
		name = "Spin a Soccer Card",
		path = "scripts/SpinASoccerCard.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/SpinASoccerCard.lua",
	},
	[4864117649] = {
		name = "untitled tag game",
		path = "scripts/UntitledTagGame.lua",
		url = "https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/scripts/UntitledTagGame.lua",
	},
}

local scriptInfo = scripts[game.GameId]

if not scriptInfo then
	warn("BaconHub does not support this game id: " .. tostring(game.GameId))
	return
end

local source = game:HttpGet(scriptInfo.url)
local loadedScript, loadError = loadstring(source)

if not loadedScript then
	error("Failed to load BaconHub script for " .. scriptInfo.name .. ": " .. tostring(loadError))
end

loadedScript()
