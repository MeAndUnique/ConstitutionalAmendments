--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local getEffectsByTypeOriginal;
local getEffectsBonusByTypeOriginal;
local getEffectsBonusOriginal;
local encodeEffectOriginal;

function onInit()
	getEffectsByTypeOriginal = EffectManager5E.getEffectsByType;
	EffectManager5E.getEffectsByType = getEffectsByType;

	getEffectsBonusByTypeOriginal = EffectManager5E.getEffectsBonusByType;
	EffectManager5E.getEffectsBonusByType = getEffectsBonusByType;

	getEffectsBonusOriginal = EffectManager5E.getEffectsBonus;
	EffectManager5E.getEffectsBonus = getEffectsBonus;

	encodeEffectOriginal = EffectManager5E.onEffectRollEncode;
	EffectManager5E.onEffectRollEncode = onEffectRollEncode;
	EffectManager.setCustomOnEffectRollEncode(onEffectRollEncode);
	EffectManager.setCustomOnEffectRollDecode(onEffectRollDecode);
end

function getEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
	StringManagerCA.beginContainsPattern();
	local result = {getEffectsByTypeOriginal(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)};
	StringManagerCA.endContainsPattern();
	return unpack(result);
end

function getEffectsBonusByType(rActor, aEffectType, bAddEmptyBonus, aFilter, rFilterActor, bTargetedOnly)
	StringManagerCA.beginContainsPattern();
	local result = {getEffectsBonusByTypeOriginal(rActor, aEffectType, bAddEmptyBonus, aFilter, rFilterActor, bTargetedOnly)};
	StringManagerCA.endContainsPattern();
	return unpack(result);
end

function getEffectsBonus(rActor, aEffectType, bModOnly, aFilter, rFilterActor, bTargetedOnly)
	StringManagerCA.beginContainsPattern();
	local result = {getEffectsBonusOriginal(rActor, aEffectType, bModOnly, aFilter, rFilterActor, bTargetedOnly)};
	StringManagerCA.endContainsPattern();
	return unpack(result);
end

function onEffectRollEncode(rRoll, rEffect)
	encodeEffectOriginal(rRoll, rEffect);
	rRoll.nDuration = rEffect.nDuration;
	local aEffectComps = EffectManager.parseEffect(rEffect.sName);
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
		if rEffectComp.type == "MAXHP" then
			rRoll.nMod = rRoll.nMod + rEffectComp.mod;
			rRoll.aDice.nMod = (rRoll.aDice.nMod or 0) + rEffectComp.mod;
			for _,die in ipairs(rEffectComp.dice) do
				table.insert(rRoll.aDice, die);
			end
		end
	end
end

function onEffectRollDecode(rRoll, rEffect)
	local nMainDieIndex = 0;
	local aEffectComps = EffectManager.parseEffect(rEffect.sName);
	for nEffectIndex=1,#aEffectComps do
		local sEffectComp = aEffectComps[nEffectIndex];
		local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
		if rEffectComp.type == "MAXHP" then
			local nMax = rEffectComp.mod;
			for _,die in ipairs(rEffectComp.dice) do
				nMainDieIndex = nMainDieIndex + 1;
				local nResult = (rRoll.aDice[nMainDieIndex].result or 0);
				nMax = nMax + nResult;
			end
			aEffectComps[nEffectIndex] = "MAXHP: " .. nMax;
		end
	end
	rEffect.nDuration = rRoll.nDuration;
	rEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps);
end