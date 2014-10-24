-- Tiefer! Tiefer!

local MOD_DISMOUNT_FLYING = "shift"
local MOD_TRAVEL_FORM = "ctrl"

------------------------------------------------------------------------

local button = CreateFrame("Button", "PhanxMountButton", nil, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp")
button:SetAttribute("type", "macro")

local _, class = UnitClass("player")
local MOUNT_LINE, MOUNT_CONDITION, MACRO_LINES = 1

local MACRO_TEMPLATE = {
	format('/stopmacro [flying,nomod:%s]', MOD_DISMOUNT_FLYING),
	'/changeactionbar [form] 1',
	'/cancelform [form]',
	'/dismount [mounted]',
	'/leavevehicle [canexitvehicle]',
}

------------------------------------------------------------------------
if class == "DRUID" then
	local SPELL_TRAVEL_FORM = GetSpellInfo(783)
	MOUNT_CONDITION = format('/run if SecureCmdOptionParse("[nocombat,noform,nomounted,noswimming,outdoors,nomod:%s]', MOD_TRAVEL_FORM)
	MACRO_LINES = {
		format('/run if SecureCmdOptionParse("%s") and not UnitInVehicle("player") and not IsPlayerMoving() then C_MountJournal.Summon(0) end', MOUNT_CONDITION),
		format('/cast [noform,nomounted] %s', SPELL_TRAVEL_FORM),
	}

------------------------------------------------------------------------
elseif class == "SHAMAN" then
	local SPELL_GHOST_WOLF = GetSpellInfo(2645)
	MOUNT_CONDITION = format('[noform,nomounted,nocombat,outdoors,nomod:%s]', MOD_TRAVEL_FORM)
	MACRO_LINES = {
		format('/run if SecureCmdOptionParse("%s") and not UnitInVehicle("player") and not IsPlayerMoving() then C_MountJournal.Summon(0) end', MOUNT_CONDITION),
		format('/cast [noform,nomounted] %s', SPELL_GHOST_WOLF),
	}

------------------------------------------------------------------------
else
	MOUNT_CONDITION = '[nomounted,nocombat,outdoors]'
	MACRO_LINES = {
		format('/run if SecureCmdOptionParse("%s") and not UnitInVehicle("player") and not IsPlayerMoving() then C_MountJournal.Summon(0) end', MOUNT_CONDITION),
	}
end
------------------------------------------------------------------------

local specials = {
	[37011] = "/use %s %s", -- Magic Broom @ Hallow's End
}

button:RegisterEvent("PLAYER_LOGIN")
button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("ZONE_CHANGED_NEW_AREA")
button:SetScript("OnEvent", function(self, event)
	if InCombatLockdown() then return end

	local MOUNT = MACRO_LINES[MOUNT_LINE]
	for id, line in pairs(specials) do
		local name = GetItemInfo(id)
		if name and GetItemCount(id) > 0 then
			MOUNT = format(line, MOUNT_CONDITION, name)
			break
		end
	end

	local macro = ""
	for i = 1, #MACRO_LINES do
		local line = MACRO_LINES[i]
		if i == MOUNT_LINE then
			macro = macro .. "\n" .. MOUNT
		else
			macro = macro .. "\n" .. line
		end
	end
	for i = 1, #MACRO_TEMPLATE do
		macro = macro .. "\n", MACRO_TEMPLATE[i]
	end
	macro = strsub(macro, 2)

	self:SetAttribute("macrotext", macro)
end)

------------------------------------------------------------------------
-- Allow setting class mounts as favorites

local isFake = {}
local shouldFake = {}

local GetIsFavorite = C_MountJournal.GetIsFavorite
local SetIsFavorite = C_MountJournal.SetIsFavorite
local GetMountInfo  = C_MountJournal.GetMountInfo
local Summon        = C_MountJournal.Summon

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	for index = 1, C_MountJournal.GetNumMounts() do
		local _, canFavorite = GetIsFavorite(index)
		if not canFavorite then
			shouldFake = shouldFake or {}
			shouldFake[index] = true
		end
	end
end)

function C_MountJournal.GetIsFavorite(index)
	if shouldFake[index] then
		print("GetIsFavorite", (GetMountInfo(index)), index, isFake[index])
		return not not isFake[index], true -- return false instead of nil
	end
	return isFavorite, true
end

function C_MountJournal.SetIsFavorite(index, value)
	print("SetIsFavorite", (GetMountInfo(index)), index, value)
	if shouldFake[index] then
		isFake[index] = value or nil -- remove instead of setting to false
	else
		SetIsFavorite(index, value)
	end
end

function C_MountJournal.GetMountInfo(index)
	local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, _, isCollected = GetMountInfo(index)
	if shouldFake[index] then
		return creatureName, spellID, icon, active, isUsable, sourceType, isFake[index], isFactionSpecific, faction, _, isCollected
	end
	return creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, _, isCollected
end

local randoms = {}

function C_MountJournal.Summon(index)
	if index == 0 and IsMounted() and next(isFake) then
		wipe(randoms)
		for j = 1, C_MountJournal.GetNumMounts() do
			local _, _, _, _, isUsable, _, isFavorite = C_MountJournal.GetMountInfo(j)
			if isUsable and isFavorite then
				tinsert(randoms, j)
			end
		end
		index = randoms[random(num)]
	end
	Summon(index)
end