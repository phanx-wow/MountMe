------------------------------------------------------------------------

local MOD_TRAVEL_FORM = "ctrl"
local MOD_DISMOUNT_FLYING = "shift"

------------------------------------------------------------------------

local mountItems = {
	[37011] = "/use %s %s", -- Magic Broom
}

local DISMOUNT = [[
/leavevehicle [canexitvehicle]
/dismount [mounted]
/cancelform [form]
]]

local SAFE_DISMOUNT = "/stopmacro [flying,nomod:%s]"

local button = CreateFrame("Button", "AnyFavoriteMountButton", nil, "SecureActionButtonTemplate")
button:SetAttribute("type", "macro")

local function GetMountCondition()
	return("[outdoors,nocombat,nomounted,novehicleui]")
end

local function GetMount()
	return format("/run if not IsPlayerMoving() and not UnitInVehicle('player') and SecureCmdOptionParse('%s') then C_MountJournal.Summon(0) end", GetMountCondition())
end

local GetTravelForm

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
		if IsFlyableArea() and (IsSpellKnown(34090) or IsSpellKnown(34091) or IsSpellKnown(90265)) then
			local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
			local reqSpell = flyingSpell[instanceMapID]
			if not reqSpell or IsSpellKnown(reqSpell) then
				return true
			end
		end
	end

	local CAT_FORM_ID, TRAVEL_FORM_ID = 768, 783
	local CAT_FORM, TRAVEL_FORM = GetSpellInfo(CAT_ID), GetSpellInfo(TRAVEL_ID)

	function GetMountCondition()
		return format("[outdoors,nocombat,nomounted,noform,novehicleui,nomod:%s]", MOD_TRAVEL_FORM)
	end

	function GetMount()
		local str = format("/run if not IsPlayerMoving() and not UnitInVehicle('player') and SecureCmdOptionParse('%s') then C_MountJournal.Summon(0) end", GetMountCondition())
		if CanFly() then
			return format("/cast [outdoors,nocombat,nomounted,noform,novehicleui,nomod:%s] %s\n%s", MOD_TRAVEL_FORM, TRAVEL_FORM, str)
		end
		return str
	end

	function GetTravelForm()
		if IsPlayerSpell(TRAVEL_FORM_ID) then
			return format("/cast [outdoors] [swimming] %s\n/cast %s", TRAVEL_FORM, CAT_FORM)
		elseif IsPlayerSpell(TRAVEL_FORM_ID) then
			return format("/cast %s", CA_FORMT)
		end
	end

------------------------------------------------------------------------

elseif select(2, UnitClass("player")) == "SHAMAN" then

	local GHOST_WOLF_ID = 2645
	local GHOST_WOLF = GetSpellInfo(GHOST_WOLF_ID)

	function GetMountCondition()
		return format("[outdoors,nocombat,nomounted,noform,novehicleui,nomod:%s]", MOD_TRAVEL_FORM)
	end

	function GetMount()
		return format("/run if not IsPlayerMoving() and not UnitInVehicle('player') and SecureCmdOptionParse('%s') then C_MountJournal.Summon(0) end", GetMountCondition())
	end

	function GetTravelForm()
		if IsPlayerSpell(GHOST_WOLF_ID) then
			return format("/cast %s", GHOST_WOLF)
		end
	end

end

------------------------------------------------------------------------

function button:Update(event)
	print(event)
	if not InCombatLockdown() then
		local useMount
		local useForm = GetTravelForm and GetTravelForm()
		local safetyCheck = not GetCVarBool("autoDismountFlying") and format(SAFE_DISMOUNT, MOD_DISMOUNT_FLYING)
		for id, line in pairs(mountItems) do
			if GetItemCount(id) > 0 then
				useMount = format(line, GetMountCondition(), GetItemInfo(id))
				break
			end
		end
		if not useMount then
			useMount = GetMount()
		end
		self:SetAttribute("macrotext", strtrim(strjoin("\n", useMount or "", useForm or "", safetyCheck or "", DISMOUNT)))

		ClearOverrideBindings(self)
		local a, b = GetBindingKey("DISMOUNT")
		if a then
			SetOverrideBinding(self, false, a, "CLICK AnyFavoriteMountButton:LeftButton")
		end
		if b then
			SetOverrideBinding(self, false, b, "CLICK AnyFavoriteMountButton:LeftButton")
		end
		SetOverrideBinding(self, false, "CTRL-`", "CLICK AnyFavoriteMountButton:LeftButton")
	end
end

button:SetScript("OnEvent", button.Update)
button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("UPDATE_BINDINGS")