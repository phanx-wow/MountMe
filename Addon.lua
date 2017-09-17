--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright (c) 2014-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/MountMe
------------------------------------------------------------------------
	TODO:
	- Cancel transformation buffs that block mounting?
	- Ignore garrison stables training mounts
----------------------------------------------------------------------]]

local MOD_TRAVEL_FORM = "ctrl"
local MOD_DISMOUNT_FLYING = "shift"

------------------------------------------------------------------------

local _, ns = ...
local _, PLAYER_CLASS = UnitClass("player")

local GetItemCount, GetSpellInfo, HasDraenorZoneAbility, IsOutdoors, IsPlayerMoving
    = GetItemCount, GetSpellInfo, HasDraenorZoneAbility, IsOutdoors, IsPlayerMoving

local IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse
    = IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse

local MOUNT_CONDITION = "[nocombat,outdoors,nomounted,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. "]"
local GARRISON_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. "]"

local SAFE_DISMOUNT = "/stopmacro [flying,nomod:" .. MOD_DISMOUNT_FLYING .. "]"
local DISMOUNT = [[
/leavevehicle [canexitvehicle]
/dismount [mounted]
]]

local SpellID = {
	["Cat Form"] = 768,
	["Darkflight"] = 68992,
	["Garrison Ability"] = 161691,
	["Ghost Wolf"] = 2645,
	["Flight Form"] = 165962,
	["Summon Mechashredder 5000"] = 164050,
	["Travel Form"] = 783,
}

local SpellName = {}
for name, id in pairs(SpellID) do
	SpellName[name] = GetSpellInfo(id)
end

local ItemID = {
	["Magic Broom"] = 37011,
}

local ItemName = {}
for name, id in pairs(ItemID) do
	ItemName[name] = GetItemInfo(id)
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local function GetOverrideMount()
	local combat = UnitAffectingCombat("player")

	-- Magic Broom
	-- Instant but not usable in combat
	if not combat and GetItemCount(ItemID["Magic Broom"]) > 0 then
		return "/use " .. ItemName["Magic Broom"]
	end

	-- Nagrand garrison mounts: Frostwolf War Wolf, Telaari Talbuk
	-- Can be summoned in combat
	if GetZoneAbilitySpellInfo() == SpellID["Garrison Ability"] then
		local _, _, _, _, _, _, id = GetSpellInfo(SpellName["Garrison Ability"])
		if (id == 164222 or id == 165803) and SecureCmdOptionParse(GARRISON_MOUNT_CONDITION) and (UnitAffectingCombat("player") or not ns.CanFly()) then
			return "/cast " ..   SpellName["Garrison Ability"]
		end
	end
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local GetMount

do
	local GROUND, FLYING, SWIMMING = 1, 2, 3

	local GetMountInfoByID = C_MountJournal.GetMountInfoByID
	local GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID

	local mountTypeInfo = {
		[230] = {100,99,0}, -- * ground -- 99 flying to use in flying areas if the player doesn't have any flying mounts as favorites
		[231] = {20,0,60},  -- Riding Turtle / Sea Turtle
		[232] = {0,0,450},  -- Abyssal Seahorse -- only in Vashj'ir
		[241] = {101,0,0},  -- Qiraji Battle Tanks -- only in Temple of Ahn'Qiraj
		[247] = {99,310,0}, -- Red Flying Cloud
		[248] = {99,310,0}, -- * flying -- 99 ground to deprioritize in non-flying zones if any non-flying mounts are favorites
		[254] = {0,0,60},   -- Subdued Seahorse -- +300% swim speed in Vashj'ir, +60% swim speed elsewhere
		[269] = {100,0,0},  -- Water Striders
		[284] = {60,0,0},   -- Chauffeured Chopper
	}

	local flexMounts = { -- flying mounts that look OK on the ground
		[376] = true, -- Celestial Steed
		[532] = true, -- Ghastly Charger
		[594] = true, -- Grinning Reaver
		[219] = true, -- Headless Horseman's Mount
		[547] = true, -- Hearthsteed
		[468] = true, -- Imperial Quilen
		[363] = true, -- Invincible
		[457] = true, -- Jade Panther
		[451] = true, -- Jeweled Onyx Panther
		[455] = true, -- Obsidian Panther
		[458] = true, -- Ruby Panther
		[456] = true, -- Sapphire Panther
		[522] = true, -- Sky Golem
		[459] = true, -- Sunstone Panther
		[523] = true, -- Swift Windsteed
		[439] = true, -- Tyrael's Charger
		[593] = true, -- Warforged Nightmare
		[421] = true, -- Winged Guardian
	}

	local zoneMounts = { -- special mounts that don't need to be favorites
		[678] = true, -- Chauffeured Mechano-Hog
		[679] = true, -- Chauffeured Mekgineer's Chopper
		[312] = true, -- Sea Turtle
		[420] = true, -- Subdued Seahorse
		[373] = true, -- Vashj'ir Seahorse
		[117] = true, -- Blue Qiraji Battle Tank
		[120] = true, -- Green Qiraji Battle Tank
		[118] = true, -- Red Qiraji Battle Tank
		[119] = true, -- Yellow Qiraji Battle Tank
	}

	local vashjirMaps = {
		[614] = true, -- Abyssal Depths
		[610] = true, -- Kelp'thar Forest
		[615] = true, -- Shimmering Expanse
		[613] = true, -- Vashj'ir
	}

	local mountIDs = C_MountJournal.GetMountIDs()
	local randoms = {}

	local function FillMountList(targetType)
		-- print("Looking for:", targetType == SWIMMING and "SWIMMING" or targetType == FLYING and "FLYING" or "GROUND")
		wipe(randoms)

		local bestSpeed = 0
		local mapID = GetCurrentMapAreaID()
		for i = 1, #mountIDs do
			local mountID = mountIDs[i]
			local name, spellID, _, _, isUsable, _, isFavorite = GetMountInfoByID(mountID)
			if isUsable and (isFavorite or zoneMounts[mountID]) then
				local _, _, sourceText, isSelfMount, mountType = GetMountInfoExtraByID(mountID)
				local speed = mountTypeInfo[mountType][targetType]
				if speed == 99 and flexMounts[mountID] then
					speed = 100
				elseif mountType == 254 and vashjirMaps[mapID] then -- Subdued Seahorse is faster in Vashj'ir
					speed = 300
				elseif mountType == 264 then -- Water Strider, prioritize in water, deprioritize on land
					speed = IsSwimming() and 101 or 99
				end
				-- print("Checking:", name, mountType, "@", speed, "vs", bestSpeed)
				if speed > 0 and speed >= bestSpeed then
					if speed > bestSpeed then
						bestSpeed = speed
						wipe(randoms)
					end
					tinsert(randoms, spellID)
				end
			end
		end
		-- print("Found", #randoms, "possibilities")
		return randoms
	end

	function GetMount()
		-- TODO: Don't summon swimming mounts at water surface
		local targetType = IsSubmerged() and SWIMMING or ns.CanFly() and FLYING or GROUND
		FillMountList(targetType)

		if #randoms == 0 and targetType == SWIMMING then
			-- Fall back to non-swimming mounts
			targetType = ns.CanFly() and FLYING or GROUND
			FillMountList(targetType)
		end

		if #randoms > 0 then
			local spellID = randoms[random(#randoms)]
			return "/use " .. GetSpellInfo(spellID)
		end
	end
end

--[==[
	local GetMountInfoByID = C_MountJournal.GetMountInfoByID
	local SEA_LEGS = GetSpellInfo(73701)

	local SEA_TURTLE = 312
	local VASHJIR_SEAHORSE = 373
	local SUBDUED_SEAHORSE = 420
	local CHAUFFEUR = UnitFactionGroup("player") == "Horde" and 679 or 678

	local AQBUGS = {
		117, -- Blue Qiraji Battle Tank
		120, -- Green Qiraji Battle Tank
		118, -- Red Qiraji Battle Tank
		119, -- Yellow Qiraji Battle Tank
	}

	function GetMount()
		-- Use Chauffeured Chopper if no riding skill
		if not HasRidingSkill() then
			local name, _, _, _, usable = GetMountInfoByID(CHAUFFEUR)
			if usable then
				return "/cast " ..   name
			else
				return
			end
		end

		-- Use underwater mounts while swimming
		if IsSubmerged() then
			-- Vashj'ir Seahorse (+450% swim speed in Vashj'ir)
			local seahorseName, _, _, _, seahorseUsable = GetMountInfoByID(VASHJIR_SEAHORSE)
			if seahorseUsable then return "/cast " ..   seahorseName end

			-- Subdued Seahorse (+300% swim speed in Vashj'ir, +60% swim speed elsewhere)
			seahorseName, _, _, _, seahorseUsable = GetMountInfoByID(SUBDUED_SEAHORSE)
			if seahorseUsable and UnitBuff("player", SEA_LEGS) then return "/cast " ..   seahorseName end

			-- Sea Turtle (+60% swim speed)
			local turtleName, _, _, _, turtleUsable = GetMountInfoByID(SEA_TURTLE)
			if turtleUsable and seahorseUsable then
				return "/cast " ..   (math.random(1, 2) == 1 and turtleName or seahorseName)
			elseif turtle then
				return "/cast " ..   turtleName
			end
		end

		-- Use Qiraji Battle Tanks while in the Temple of Ahn'qiraj
		-- If any are marked as favorites, ignore ones that aren't
		local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
		if instanceMapID == 531 then
			local numBugs, onlyFavorites = 0
			for i = 1, #AQBUGS do
				local bug = AQBUGS[i]
				local name, _, _, _, usable, _, favorite = GetMountInfoByID(bug)
				if usable and not (onlyFavorites and not favorite) then
					if favorite and not onlyFavorites then
						numBugs = 0
						onlyFavorites = true
					end
					numBugs = numBugs + 1
					hasBugs[numBugs] = name
				end
			end
			if numBugs > 0 then
				return "/cast " ..   hasBugs[math.random(numBugs)]
			end
		end
	end
end
]==]
------------------------------------------------------------------------
------------------------------------------------------------------------

local GetAction

local function HasRidingSkill(flyingOnly)
	local hasSkill = IsSpellKnown(90265) and 310 or IsSpellKnown(34091) and 280 or IsSpellKnown(34090) and 150
	if flyingOnly then
		return hasSkill
	end
	return hasSkill or IsSpellKnown(33391) and 100 or IsSpellKnown(33388) and 60
end

local function HasGlyph(id)
	for i = 1, NUM_GLYPH_SLOTS do
		local _, _, _, _, _, glyphID = GetGlyphSocketInfo(i)
		if id == glyphID then
			return true
		end
	end
end

------------------------------------------------------------------------

if PLAYER_CLASS == "DRUID" then
	--[[
	Travel Form
	- outdoors,nocombat,flyable +310%
	- outdoors,nocombat +100% (level 38, new in 7.1)
	- outdoors +40%
	--]]

	local BLOCKING_FORMS
	local orig_DISMOUNT = DISMOUNT

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" ..   MOD_TRAVEL_FORM ..   "]"
	DISMOUNT = DISMOUNT ..   "\n/cancelform [form]"

	function GetAction(force)
		if force or not BLOCKING_FORMS then
			BLOCKING_FORMS = "" -- in case of force
			for i = 1, GetNumShapeshiftForms() do
				local icon = strlower(GetShapeshiftFormInfo(i))
				if not strmatch(icon, "spell_nature_forceofnature") then -- Moonkin Form OK
					if BLOCKING_FORMS == "" then
						BLOCKING_FORMS = ":" ..   i
					else
						BLOCKING_FORMS = BLOCKING_FORMS ..   "/" ..   i
					end
				end
			end
			MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform" ..   BLOCKING_FORMS ..   ",novehicleui,nomod:" ..   MOD_TRAVEL_FORM ..   "]"
			DISMOUNT = orig_DISMOUNT ..   "\n/cancelform [form" ..   BLOCKING_FORMS ..   "]"
		end

		local mountOK, flightOK = SecureCmdOptionParse(MOUNT_CONDITION), ns.CanFly()
		if mountOK and flightOK and IsPlayerSpell(SpellID["Travel Form"]) then
			return "/cast " ..   SpellName["Travel Form"]
		end

		local mount = mountOK and not IsPlayerMoving() and GetMount()
		if mount then
			return mount
		elseif IsPlayerSpell(SpellID["Travel Form"]) and (IsOutdoors() or IsSubmerged()) then
			return "/cast [nomounted,noform] " ..   SpellName["Travel Form"]
		elseif IsPlayerSpell(SpellID["Cat Form"]) then
			return "/cast [nomounted,noform" ..   BLOCKING_FORMS ..   "] " ..   SpellName["Cat Form"]
		end
	end

------------------------------------------------------------------------
elseif PLAYER_CLASS == "SHAMAN" then

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" ..   MOD_TRAVEL_FORM ..   "]"
	DISMOUNT = DISMOUNT ..   "\n/cancelform [form]"

	function GetAction()
		local mount = SecureCmdOptionParse(MOUNT_CONDITION) and not IsPlayerMoving() and GetMount()
		if mount then
			return mount
		elseif IsPlayerSpell(SpellID["Ghost Wolf"]) then
			return "/cast [nomounted,noform] " ..   SpellName["Ghost Wolf"]
		end
	end

------------------------------------------------------------------------
else
	local ClassActionIDs = {
		196555, -- Demon Hunter: Netherwalk (1.5m)
		125883, -- Monk: Zen Flight
		115008, -- Monk: Chi Torpedo (2x 20s)
		109132, -- Monk: Roll (2x 20s)
		190784, -- Paladin: Divine Speed (45s)
		202273, -- Paladin: Seal of Light
		  2983, -- Rogue: Sprint (1m)
		111400, -- Warlock: Burning Rush
		 68992, -- Worgen: Darkflight (2m)
	}
	local ClassActionLimited = {
		[125883] = function(combat) return combat or IsIndoors() end, -- Zen Flight
	}

	function GetAction()
		local combat = UnitAffectingCombat("player")

		local classAction
		for i = 1, #ClassActionIDs do
			local id = ClassActionIDs[i]
			if IsPlayerSpell(id) and not (ClassActionLimited[id] and ClassActionLimited[id](combat)) then
				classAction = GetSpellInfo(id)
				break
			end
		end

		local moving = IsPlayerMoving()
		if classAction and (moving or combat) then
			return "/cast [nomounted,novehicleui] " ..   classAction
		elseif not moving then
			local action
			if SecureCmdOptionParse(MOUNT_CONDITION) then
				action = GetMount()
			end
			if classAction and PLAYER_CLASS == "WARLOCK" then
				-- TODO: why is /cancelform in here???
				action = "/cancelaura " ..   classAction ..   (action and ("\n/cancelform [form]\n" ..   action) or "")
			end
			return action
		end
	end
end

------------------------------------------------------------------------

local button = CreateFrame("Button", "MountMeButton", nil, "SecureActionButtonTemplate")
button:SetAttribute("type", "macro")

function button:Update()
	if InCombatLockdown() then return end

	self:SetAttribute("macrotext", strtrim(strjoin("\n",
		GetOverrideMount() or GetAction() or "",
		GetCVarBool("autoDismountFlying") and "" or SAFE_DISMOUNT,
		DISMOUNT
	)))
end

button:SetScript("PreClick", button.Update)

------------------------------------------------------------------------

button:RegisterEvent("PLAYER_LOGIN")

button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("UPDATE_BINDINGS")

button:RegisterEvent("LEARNED_SPELL_IN_TAB")
button:RegisterEvent("PLAYER_REGEN_DISABLED")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
button:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
button:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- zone changed
button:RegisterEvent("ZONE_CHANGED") -- indoor/outdoor transition

button:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if not MountJournalSummonRandomFavoriteButton then
			CollectionsJournal_LoadUI()
		end
	elseif event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
		ClearOverrideBindings(self)
		local a, b = GetBindingKey("DISMOUNT")
		if a then
			SetOverrideBinding(self, false, a, "CLICK MountMeButton:LeftButton")
		end
		if b then
			SetOverrideBinding(self, false, b, "CLICK MountMeButton:LeftButton")
		end
	else
		self:Update(event == "UPDATE_SHAPESHIFT_FORMS") -- force extra update for druids
	end
end)
