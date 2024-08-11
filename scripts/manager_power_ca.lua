--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local getPCPowerHealActionTextOriginal;
local parseDamagePhraseOriginal;

function onInit()
	getPCPowerHealActionTextOriginal = PowerManager.getPCPowerHealActionText;
	PowerManager.getPCPowerHealActionText = getPCPowerHealActionText;

	parseDamagePhraseOriginal = PowerManager.parseDamagePhrase;
	PowerManager.parseDamagePhrase = parseDamagePhrase;
end

function getPCPowerHealActionText(nodeAction)
	local sHeal = getPCPowerHealActionTextOriginal(nodeAction);
	if sHeal ~= "" and DB.getValue(nodeAction, "healtype", "") == "maxhp" then
		local nPos = string.find(sHeal, " %[SELF%]");
		if nPos then
			sHeal = sHeal:sub(1, nPos-1) .. " maximum" .. sHeal:sub(nPos);
		else
			sHeal = sHeal .. " maximum";
		end
	end
	return sHeal;
end

function parseDamagePhrase(aWords, i)
	StringManagerCA.beginContainsPattern();
	local result = {parseDamagePhraseOriginal(aWords, i)};
	StringManagerCA.endContainsPattern();
	return unpack(result);
end