-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

local modRecoveryOriginal;

function onInit()
	modRecoveryOriginal = ActionRecovery.modRecovery;
	ActionHeal.modRecovery = modRecovery;
	ActionsManager.registerModHandler("recovery", modRecovery);

	ActionsManager.registerPostRollHandler("recovery", onRecoveryRoll)
end

function modRecovery(rSource, rTarget, rRoll)
	modRecoveryOriginal(rSource, rTarget, rRoll);

	if rSource then
		local bEffect = false;
		aDice, nMod, nHDEffects = EffectManager5E.getEffectsBonus(rSource, "HD");
		if nHDEffects > 0 then
			rRoll.sDesc = updateEffectsTag(rRoll.sDesc, aDice, nMod);
			
			for _,vDie in ipairs(aDice) do
				if vDie:sub(1,1) == "-" then
					table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
				else
					table.insert(rRoll.aDice, "p" .. vDie:sub(2));
				end
			end
			rRoll.nMod = rRoll.nMod + nMod;
		end
	end
end

function onRecoveryRoll(rSource, rRoll)
	local nMult = EffectManager5E.getEffectsBonus(rSource, "HDMULT", true) - 1;
	if (nMult ~= 0) and (nMult ~= -1) then
		local nAdd = rRoll.nMod * nMult;
		for _,vDie in ipairs(rRoll.aDice) do
			-- Only multiple the base (black) dice.
			if vDie.type:match("^[%-%+]?[dD]%d+") then
				nAdd = nAdd + (vDie.result * nMult);
			end
		end

		rRoll.nMod = rRoll.nMod + nAdd;
		rRoll.sDesc = updateEffectsTag(rRoll.sDesc, {}, nAdd);
	end
end

function updateEffectsTag(sDesc, aAddDice, nAddMod)
	local sTag = Interface.getString("effects_tag");
	local sPattern = "%[(" .. sTag .. "[^%]]+)%]";
	local nStart, nEnd = sDesc:find(sPattern);
	if nStart then
		local sMatch = sDesc:sub(nStart, nEnd);
		local aDice, nMod = StringManager.convertStringToDice(sMatch);
		nAddMod = nAddMod + nMod;
		for _,vDie in ipairs(aDice) do
			table.insert(aAddDice, vDie);
		end
	end

	local sEffects;
	local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
	if sMod ~= "" then
		sEffects = "[" .. sTag .. " " .. sMod .. "]";
	else
		sEffects = "[" .. sTag .. "]";
	end
	
	if nStart then
		sDesc = sDesc:sub(1, nStart - 1) .. sEffects .. sDesc:sub(nEnd + 1, #sDesc);
	else
		sDesc = sDesc .. sEffects;
	end
	return sDesc;
end