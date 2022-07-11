--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local onNPCPostAddOriginal;

function onInit()
	onNPCPostAddOriginal = CombatRecordManager.getRecordTypePostAddCallback("npc");
	CombatRecordManager.setRecordTypePostAddCallback("npc", onNPCPostAdd);
end

function onNPCPostAdd(tCustom)
	onNPCPostAddOriginal(tCustom);
	if tCustom.nodeCT then
		-- Account for Max/Random NPC HP settings.
		DB.setValue(tCustom.nodeCT, "hp", "number", DB.getValue(tCustom.nodeCT, "hptotal", 0));
		 -- Undo for the automated update from the CT field
		DB.setValue(tCustom.nodeCT, "hpadjust", "number", 0);
	end
end