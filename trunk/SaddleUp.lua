--[[--------------------------------------------------------------------
	SaddleUp
	One button to mount, dismount, and use travel forms.

	Copyright (c) 2014 Phanx <addons@phanx.net>. All rights reserved.
	Please DO NOT upload this addon to other websites, or post modified
	versions of it. However, you are welcome to include a copy of it
	WITHOUT CHANGES in compilations posted on Curse and/or WoWInterface.
	You are also welcome to use any/all of its code in your own addon, as
	long as you do not use my name or the name of this addon ANYWHERE in
	your addon, including its name, outside of an optional attribution.
----------------------------------------------------------------------]]

local MOD_TRAVEL_FORM = "ctrl"
local MOD_DISMOUNT_FLYING = "shift"

------------------------------------------------------------------------

local MOUNT_CONDITION = "[outdoors,nocombat,nomounted,novehicleui]"
local SAFE_DISMOUNT = "/stopmacro [flying,nomod:%s]"
local DISMOUNT = [[
/leavevehicle [canexitvehicle]
/dismount [mounted]
]]

local function HasRidingSkill(flyingOnly)
	local hasSkill = IsSpellKnown(90265) or IsSpellKnown(34091) or IsSpellKnown(34090)
	if flyingOnly then
		return hasSkill
	end
	return hasSkill or IsSpellKnown(33391) or IsSpellKnown(33388)
end

local GetAction

------------------------------------------------------------------------

local button = CreateFrame("Button", "AnyFavoriteMountButton", nil, "SecureActionButtonTemplate")
button:SetAttribute("type", "macro")

------------------------------------------------------------------------

if select(2, UnitClass("player")) == "DRUID" then

	local flyingSpell = {
		[0]   = 90267,  -- Flight Master's License / Eastern Kingdoms
		[1]   = 90267,  -- Flight Master's License / Kalimdor
		[646] = 90267,  -- Flight Master's License / Deepholm
		[571] = 54197,  -- Cold Weather Flying / Northrend
		[870] = 115913, -- Wisdom of the Four Winds / Pandaria
	}

	local function CanFly() -- because IsFlyableArea is a fucking liar
		if IsFlyableArea() and HasRidingSkill(true) then
			local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
			local reqSpell = flyingSpell[instanceMapID]
			if not reqSpell or IsSpellKnown(reqSpell) then
				return true
			end
		end
	end

	local CAT_FORM_ID, TRAVEL_FORM_ID = 768, 783
	local CAT_FORM, TRAVEL_FORM = GetSpellInfo(CAT_FORM_ID), GetSpellInfo(TRAVEL_FORM_ID)

	MOUNT_CONDITION = format("[outdoors,nocombat,nomounted,noform,novehicleui,nomod:%s]", MOD_TRAVEL_FORM)
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction()
		-- TODO: handle Glyph of the Stag (separate Flight Form)
		-- TODO: handle Glyph of Travel (TF = ground mount OOC)
		local mountOK = SecureCmdOptionParse(MOUNT_CONDITION)
		if mountOK and IsPlayerSpell(TRAVEL_FORM_ID) and CanFly() then
			return format("/cast %s", TRAVEL_FORM)
		elseif mountOK and not IsPlayerMoving() and HasRidingSkill() then
			return "/run C_MountJournal.Summon(0)"
		elseif IsPlayerSpell(TRAVEL_FORM_ID) and (IsOutdoors() or IsSubmerged()) then
			return format("/cast [nomounted,noform] %s", TRAVEL_FORM)
		elseif IsPlayerSpell(TRAVEL_FORM_ID) then
			return format("/cast [nomounted,noform] %s", CAT_FORM)
		end
	end

------------------------------------------------------------------------

elseif select(2, UnitClass("player")) == "SHAMAN" then

	local GHOST_WOLF_ID = 2645
	local GHOST_WOLF = GetSpellInfo(GHOST_WOLF_ID)

	MOUNT_CONDITION = format("[outdoors,nocombat,nomounted,noform,novehicleui,nomod:%s]", MOD_TRAVEL_FORM)
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction()
		-- TODO: handle Glyph of Ghostly Speed (GW = ground mount OOC)
		if not IsPlayerMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			return "/run C_MountJournal.Summon(0)"
		elseif IsPlayerSpell(GHOST_WOLF_ID) then
			return format("/cast [nomounted,noform] %s", GHOST_WOLF)
		end
	end

------------------------------------------------------------------------

else

	function GetAction()
		if not IsPlayerMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			return "/run C_MountJournal.Summon(0)"
		end
	end

end

------------------------------------------------------------------------

function button:Update()
	if InCombatLockdown() then return end

	local useMount
	local useForm = GetTravelForm and GetTravelForm()
	local safetyCheck = not GetCVarBool("autoDismountFlying") and format(SAFE_DISMOUNT, MOD_DISMOUNT_FLYING)

	if GetItemCount(37011) > 0 and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
		useMount = "/use " .. GetItemInfo(37011)
	else
		useMount = GetAction()
	end
	self:SetAttribute("macrotext", strtrim(strjoin("\n", useMount or "", safetyCheck or "", DISMOUNT)))
end

button:SetScript("PreClick", button.Update)

------------------------------------------------------------------------

button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("PLAYER_REGEN_DISABLED")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("UPDATE_BINDINGS")

button:SetScript("OnEvent", function(self, event)
	if event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
		ClearOverrideBindings(self)
		local a, b = GetBindingKey("DISMOUNT")
		if a then
			SetOverrideBinding(self, false, a, "CLICK AnyFavoriteMountButton:LeftButton")
		end
		if b then
			SetOverrideBinding(self, false, b, "CLICK AnyFavoriteMountButton:LeftButton")
		end
	else
		self:Update()
	end
end)