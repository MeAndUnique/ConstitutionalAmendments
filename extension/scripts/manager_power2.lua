-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local getPCPowerHealActionTextOriginal;

function onInit()
	getPCPowerHealActionTextOriginal = PowerManager.getPCPowerHealActionText;
	PowerManager.getPCPowerHealActionText = getPCPowerHealActionText;
end

function getPCPowerHealActionText(nodeAction)
	local sHeal = getPCPowerHealActionTextOriginal(nodeAction);
	if sHeal ~= "" and DB.getValue(nodeAction, "healtype", "") == "max" then
		local nPos = string.find(sHeal, " %[SELF%]");
		if nPos then
			sHeal = sHeal:sub(1, nPos-1) .. " maximum" .. sHeal:sub(nPos);
		else
			sHeal = sHeal .. " maximum";
		end
	end
	return sHeal;
end