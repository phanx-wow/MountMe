-- API_CanFly.lua
-- Written by Phanx <addons@phanx.net>
-- This file provides a single function addons can call to determine
-- whether the player can actually use a flying mount at present, since
-- the game API function IsFlyableArea is unusable for this purpose.
-- This is free and unencumbered software released into the public domain.
-- Feel free to include this file or code from it in your own addons.

local _, ns = ...
-- TODO: Find out when Wintergrasp isn't flyable? Or too old to bother with?

local flyingSpell = {
	[0]    =  90267, -- Eastern Kingdoms = Flight Master's License
	[1]    =  90267, -- Kalimdor = Flight Master's License
	[646]  =  90267, -- Deepholm = Flight Master's License
	[571]  =  54197, -- Northrend = Cold Weather Flying
	[870]  = 115913, -- Pandaria = Wisdom of the Four Winds
	[1116] = -1, -- Draenor
	[1191] = -1, -- Ashran - World PvP
	[1265] = -1, -- Tanaan Jungle Intro
	[1152] = -1, -- FW Horde Garrison Level 1
	[1330] = -1, -- FW Horde Garrison Level 2
	[1153] = -1, -- FW Horde Garrison Level 3
	[1154] = -1, -- FW Horde Garrison Level 4
	[1158] = -1, -- SMV Alliance Garrison Level 1
	[1331] = -1, -- SMV Alliance Garrison Level 2
	[1159] = -1, -- SMV Alliance Garrison Level 3
	[1160] = -1, -- SMV Alliance Garrison Level 4
}

local GetInstanceInfo, IsFlyableArea, IsSpellKnown = GetInstanceInfo, IsFlyableArea, IsSpellKnown

function ns.CanFly()
	if IsFlyableArea() then
		local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
		local reqSpell = flyingSpell[instanceMapID]
		if reqSpell then
			return reqSpell > 0 and IsSpellKnown(reqSpell)
		else
			return IsSpellKnown(34090) or IsSpellKnown(34091) or IsSpellKnown(90265)
		end
	end
end