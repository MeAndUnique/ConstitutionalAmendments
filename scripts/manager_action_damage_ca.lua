-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local applyDamageOriginal;
local decodeDamageTextOriginal;
local messageDamageOriginal;

local decodeResult;

function onInit()
	table.insert(DataCommon.dmgtypes, "max");
	table.insert(DataCommon.dmgtypes, "steal");
	table.insert(DataCommon.dmgtypes, "hsteal");
	table.insert(DataCommon.dmgtypes, "stealtemp");
	table.insert(DataCommon.dmgtypes, "hstealtemp");
	table.insert(DataCommon.specialdmgtypes, "max");
	table.insert(DataCommon.specialdmgtypes, "steal");
	table.insert(DataCommon.specialdmgtypes, "hsteal");
	table.insert(DataCommon.specialdmgtypes, "stealtemp");
	table.insert(DataCommon.specialdmgtypes, "hstealtemp");

	applyDamageOriginal = ActionDamage.applyDamage;
	ActionDamage.applyDamage = applyDamage;

	decodeDamageTextOriginal = ActionDamage.decodeDamageText;
	ActionDamage.decodeDamageText = decodeDamageText;

	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;
end

function applyDamage(rSource, rTarget, bSecret, sDamage, nTotal)
	decodeDamageText(nTotal, sDamage);

	local bSwapped = false;
	if decodeResult and decodeResult.sType == "damage" then
		for sTypes,nDamage in pairs(decodeResult.aDamageTypes) do
			local aTemp = StringManager.split(sTypes, ",", true);
			for _,type in ipairs(aTemp) do
				if type == "transfer" then
					local rSwap = rTarget;
					rTarget = rSource;
					rSource = rSwap;
					bSwapped = true;
					break;
				end
			end

			if bSwapped then
				break;
			end
		end
	end

	return applyDamageOriginal(rSource, rTarget, bSecret, sDamage, nTotal);
end

function decodeDamageText(nDamage, sDamageDesc)
	if not decodeResult then
		decodeResult = decodeDamageTextOriginal(nDamage, sDamageDesc);
		if string.match(sDamageDesc, "%[HEAL") and string.match(sDamageDesc, "%[MAX%]") then
			decodeResult.sTypeOutput = "Maximum hit points";
		end
	end
	return decodeResult;
end

function messageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
	local rComplexDamage = {};
	local bIsHeal = false;
	if decodeResult and decodeResult.sType == "damage" then
		-- Nothing to resolve for shared damage
		if not string.match(sDamageDesc, "%[SHARED%]") then
			resolveDamage(rSource, rTarget, sTotal, sExtraResult, rComplexDamage);
		end
	elseif decodeResult and decodeResult.sType == "heal" then
		bIsHeal = true;
		if string.match(sDamageDesc, "%[STOLEN%]") then
			sExtraResult = sExtraResult .. " [STOLEN]";
		end
		if string.match(sDamageDesc, "%[TRANSFER%]") then
			sExtraResult = sExtraResult .. " [TRANSFER]";
		end
		if not string.match(sDamageDesc, "%[MAX%]") then
			resolveShared(rTarget, rComplexDamage, true);
		end
	end
	decodeResult = nil;

	if string.match(sDamageDesc, "%[SHARED%]") then
		sExtraResult = sExtraResult .. " [SHARED]";
	end

	messageDamageOriginal(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult);

	if rComplexDamage.nStolen and (rComplexDamage.nStolen > 0) then
		local sDamage = "[HEAL][STOLEN]";
		ActionDamage.applyDamage(rSource, rSource, bSecret, sDamage, rComplexDamage.nStolen);
	end
	if rComplexDamage.nTempStolen and (rComplexDamage.nTempStolen > 0) then
		local sDamage = "[HEAL][STOLEN][TEMP]";
		ActionDamage.applyDamage(rSource, rSource, bSecret, sDamage, rComplexDamage.nTempStolen);
	end
	if rComplexDamage.nTransfered and (rComplexDamage.nTransfered > 0) then
		local sDamage = "[HEAL][TRANSFER]";
		ActionDamage.applyDamage(rSource, rSource, bSecret, sDamage, rComplexDamage.nTransfered);
	end
	if rComplexDamage.rSharingTargets then
		local nTotal = tonumber(sTotal);
		local sDamage = "[SHARED]";
		if bIsHeal then
			sDamage = "[HEAL][SHARED]";
		end
		for sSharingTarget,nRate in pairs(rComplexDamage.rSharingTargets) do
			ActionDamage.applyDamage(rTarget, sSharingTarget, bSecret, sDamage, math.floor(nTotal * nRate));
		end
	end
end

function resolveDamage(rSource, rTarget, sTotal, sExtraResult, rComplexDamage)
	local sTargetType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	local nMax = 0;
	for sTypes,nDamage in pairs(decodeResult.aDamageTypes) do
		local aTemp = StringManager.split(sTypes, ",", true);
		local bMax = false;
		local nSteal = 0;
		local bCheckSteal = false;
		local nTempSteal = 0;
		local bCheckTempSteal = false;
		local nTransfer = 0;
		local bCheckTransfer = false;
		for _,type in ipairs(aTemp) do
			bMax = bMax or type == "max";
			
			if bCheckSteal or bCheckTempSteal or bCheckTransfer then
				local sRate = string.match(type, "%[(%d+.?%d*)%]");
				if sRate then
					if bCheckSteal then
						nSteal = tonumber(sRate);
					elseif bCheckTempSteal then
						nTempSteal = tonumber(sRate);
					elseif bCheckTransfer then
						nTransfer = tonumber(sRate);
					end
				end
				local bCheckSteal = false;
				local bCheckTempSteal = false;
				local bCheckTransfer = false;
			end

			if type == "steal" then
				nSteal = 1;
				bCheckSteal = true;
			elseif type == "hsteal" then
				nSteal = 0.5;
			end
			if type == "stealtemp" then
				nTempSteal = 1;
				bCheckTempSteal = true;
			elseif type == "hstealtemp" then
				nTempSteal = 0.5;
			end
			if type == "transfer" then
				nTransfer = 1;
				bCheckTransfer = true;
			end
		end

		if bMax or (nSteal > 0) or (nTempSteal > 0) or (nTransfer > 0) then
			local rDamageOutput = {aDamageTypes={[sTypes]=nDamage}};
			local nDamageAdjust = ActionDamage.getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput);
			nDamageAdjust = nDamageAdjust + nDamage;
			rComplexDamage.nStolen = (rComplexDamage.nStolen or 0) + math.floor(nDamageAdjust * nSteal);
			rComplexDamage.nTempStolen = (rComplexDamage.nTempStolen or 0) + math.floor(nDamageAdjust * nTempSteal)
			rComplexDamage.nTransfered = (rComplexDamage.nTransfered or 0) + math.floor(nDamageAdjust * nTransfer)

			if bMax and (nDamageAdjust > 0) then
				nMax = nMax + nDamageAdjust;
			end
		end
	end

	if nMax > 0 then
		resolveMaxDamage(nMax, sExtraResult, sTargetType, nodeTarget);
	end

	resolveShared(rTarget, rComplexDamage, false)
end

function resolveMaxDamage(nMax, sExtraResult, sTargetType, nodeTarget)
	sExtraResult = sExtraResult .. " [MAX REDUCED]";
	if sTargetType == "pc" then
		local nWounds = DB.getValue(nodeTarget, "hp.wounds", 0);
		DB.setValue(nodeTarget, "hp.wounds", "number", math.max(0, nWounds - nMax));

		local nAdjust = DB.getValue(nodeTarget, "hp.adjust", 0) - nMax;
		DB.setValue(nodeTarget, "hp.adjust", "number", nAdjust);
		HpManager.recalculateTotal(nodeTarget);
		
		local nTotal = DB.getValue(nodeTarget, "hp.total", 0);
		if nTotal <= 0 then
			if not string.match(sExtraResult, "%[INSTANT DEATH%]") then
				sExtraResult = sExtraResult .. " [INSTANT DEATH]";
			end
			nAdjust = nAdjust - nTotal;
			DB.setValue(nodeTarget, "hp.total", "number", 0);
			DB.setValue(nodeTarget, "hp.adjust", "number", nAdjust);
			DB.setValue(nodeTarget, "hp.deathsavefail", "number", 3);
		end
	else
		local nWounds = DB.getValue(nodeTarget, "wounds", 0);
		DB.setValue(nodeTarget, "wounds", "number", math.max(0, nWounds - nMax));

		local nTotal = DB.getValue(nodeTarget, "hptotal", 0) - nMax;
		if nTotal < 0 then
			if not string.match(sExtraResult, "%[INSTANT DEATH%]") then
				sExtraResult = sExtraResult .. " [INSTANT DEATH]";
			end
			nTotal = 0;
		end
		DB.setValue(nodeTarget, "hptotal", "number", nTotal);
	end
end

function resolveShared(rTarget, rComplexDamage, bIsHeal)
	local nodeTargetCT = ActorManager.getCTNode(rTarget);
	for _,nodeEffect in pairs(DB.getChildren(nodeTargetCT, "effects")) do
		local nActive = DB.getValue(nodeEffect, "isactive", 0);
		if (nActive == 1) then
			local sLabel = DB.getValue(nodeEffect, "label", "");
			local aEffectComps = EffectManager.parseEffect(sLabel);
			for i = 1, #aEffectComps do
				local sCheckFor = "SHAREDMG";
				if bIsHeal then
					sCheckFor = "SHAREHEAL";
				end

				local rEffectComp = EffectManager5E.parseEffectComp(aEffectComps[i]);
				if rEffectComp.type == sCheckFor then
					rComplexDamage.rSharingTargets = rComplexDamage.rSharingTargets or {};
					for _,sSharingTarget in ipairs(getSharingTargets(nodeEffect)) do
						rComplexDamage.rSharingTargets[sSharingTarget]
							= (rComplexDamage.rSharingTargets[sSharingTarget] or 0) + rEffectComp.mod;
					end
				end
			end
		end
	end
end

function getSharingTargets(nodeEffect)
	local aTargets = {};
	for _,nodeTarget in pairs(DB.getChildren(nodeEffect, "targets")) do
		table.insert(aTargets, DB.getValue(nodeTarget, "noderef"));
	end
	if #aTargets == 0 then
		table.insert(aTargets, DB.getValue(nodeEffect, "source_name"));
	end
	return aTargets;
end