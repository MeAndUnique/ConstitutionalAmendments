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
	
end

function onEffectRollDecode(rRoll, rEffect)
end