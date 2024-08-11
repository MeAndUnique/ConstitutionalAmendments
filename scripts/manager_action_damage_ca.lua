--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local getDamageTypesFromStringOriginal;
local applyDamageOriginal;
local applyDmgEffectsToModRollOriginal;
local decodeDamageTextOriginal;
local messageDamageOriginal;

local DAMAGE_RATE_PATTERN = "'(%d*%.?%d+)'";

function onInit()
	table.insert(DataCommon.dmgtypes, "maxhp");
	table.insert(DataCommon.dmgtypes, "steal");
	table.insert(DataCommon.dmgtypes, "hsteal");
	table.insert(DataCommon.dmgtypes, "stealtemp");
	table.insert(DataCommon.dmgtypes, "hstealtemp");
	table.insert(DataCommon.dmgtypes, DAMAGE_RATE_PATTERN);
	table.insert(DataCommon.specialdmgtypes, "maxhp");
	table.insert(DataCommon.specialdmgtypes, "steal");
	table.insert(DataCommon.specialdmgtypes, "hsteal");
	table.insert(DataCommon.specialdmgtypes, "stealtemp");
	table.insert(DataCommon.specialdmgtypes, "hstealtemp");
	table.insert(DataCommon.specialdmgtypes, DAMAGE_RATE_PATTERN);

	getDamageTypesFromStringOriginal = ActionDamage.getDamageTypesFromString;
	ActionDamage.getDamageTypesFromString = getDamageTypesFromString;

	applyDamageOriginal = ActionDamage.applyDamage;
	ActionDamage.applyDamage = applyDamage;

	applyDmgEffectsToModRollOriginal = ActionDamage.applyDmgEffectsToModRoll;
	ActionDamage.applyDmgEffectsToModRoll = applyDmgEffectsToModRoll;

	decodeDamageTextOriginal = ActionDamage.decodeDamageText;
	ActionDamage.decodeDamageText = decodeDamageText;

	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;
end

function getDamageTypesFromString(sDamageTypes)
	StringManagerCA.beginContainsPattern();
	local result = {getDamageTypesFromStringOriginal(sDamageTypes)};
	StringManagerCA.endContainsPattern();
	return unpack(result);
end

function applyDamage(rSource, rTarget, rRoll)
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if not nodeTarget then
		return;
	end

	local decodeResult = ActionDamage.decodeDamageText(rRoll.nTotal, rRoll.sDesc);
	if rRoll then
		rRoll.aDamageTypes = decodeResult.aDamageTypes;
	end

	if decodeResult then
		if decodeResult.sType == "damage" then
			if checkForTransfer(decodeResult) then
				local rSwap = rTarget;
				rTarget = rSource;
				rSource = rSwap;
			end
		elseif decodeResult.sType == "heal" then
			if string.match(rRoll.sDesc, "%[HEAL") and  rRoll.sSubtype == 'maxhp' then
				applyMaxHeal(rTarget, rRoll.nTotal);
			end
		elseif decodeResult.sType == "recovery" and (sTargetNodeType ~= "pc") then
			-- Hijack NPC recovery, since it doesn't work in the ruleset anyway.
			rRoll.sDesc = applyNPCRecovery(nodeTarget, rRoll.sDesc);
		end
	end

	EffectManager.startDelayedUpdates();
	applyDamageOriginal(rSource, rTarget, rRoll);
	EffectManager.endDelayedUpdates();
end

function checkForTransfer(decodeResult)
	for sTypes,_ in pairs(decodeResult.aDamageTypes) do
		local aTemp = StringManager.split(sTypes, ",", true);
		for _,type in ipairs(aTemp) do
			if type == "transfer" then
				return true;
			end
		end
	end

	return false;
end

function applyMaxHeal(rTarget, nTotal)
	local _, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	local fields = HpManager.getHealthFields(nodeTarget);
	local nAdjust = DB.getValue(nodeTarget, fields.adjust, 0) + nTotal;
	DB.setValue(nodeTarget, fields.adjust, "number", nAdjust);
	HpManager.recalculateTotal(nodeTarget);

	-- Add wounds so that we can heal them and gain all of the benefits of ruleset logic.
	local nWounds = DB.getValue(nodeTarget, fields.wounds, 0) + nTotal;
	DB.setValue(nodeTarget, fields.wounds, "number", nWounds);
end

function applyNPCRecovery(nodeTarget, sDamage)
	local sClassNode = string.match(sDamage, "%[NODE:([^]]+)%]");
	if sClassNode and DB.getValue(nodeTarget, "wounds", 0) > 0 then
		-- Determine whether HD available
		local nClassHD = 0;
		local nClassHDMult = 0;
		local nClassHDUsed = 0;
		local nodeClass = DB.findNode(sClassNode);
		if nodeClass then
			nClassHD = DB.getValue(nodeClass, "level", 0);
			nClassHDMult = #(DB.getValue(nodeClass, "hddie", {}));
			nClassHDUsed = DB.getValue(nodeClass, "hdused", 0);
		end

		if (nClassHD * nClassHDMult) <= nClassHDUsed then
			sDamage = sDamage .. "[INSUFFICIENT]";
		else
			sDamage = sDamage:gsub("%[RECOVERY", "[HEAL")
			-- Decrement HD used
			nodeClass = DB.findNode(sClassNode);
			if nodeClass then
				DB.setValue(nodeClass, "hdused", "number", nClassHDUsed + 1);
			end
		end
	end
	return sDamage;
end

function applyDmgEffectsToModRoll(rRoll, rSource, rTarget)
	StringManagerCA.beginContainsPattern();
	local result = {applyDmgEffectsToModRollOriginal(rRoll, rSource, rTarget)};
	StringManagerCA.endContainsPattern();
	return unpack(result);
end

function decodeDamageText(nDamage, sDamageDesc)
	local decodeResult = decodeDamageTextOriginal(nDamage, sDamageDesc);
	if string.match(sDamageDesc, "%[HEAL") and string.match(sDamageDesc, "%[MAXHP%]") then
		decodeResult.sTypeOutput = "Maximum hit points";
	end
	return decodeResult;
end

function messageDamage(rSource, rTarget, rRoll)
	local rComplexDamage = {};
	local bIsHeal = false;
	if rRoll.sType == "damage" then
		-- Nothing to resolve for shared damage
		if not string.match(rRoll.sDesc, "%[SHARED%]") then
			resolveDamage(rTarget, rRoll, rComplexDamage);
		end
	elseif rRoll.sType == "recovery" then
		rRoll.sDamageText = rRoll.sDamageText:gsub("%[HEAL", "[RECOVERY")
	elseif rRoll.sType == "heal" then
		bIsHeal = true;
		if string.match(rRoll.sDesc, "%[STOLEN%]") then
			rRoll.sResults = rRoll.sResults .. " [STOLEN]";
		end
		if string.match(rRoll.sDesc, "%[TRANSFER%]") then
			rRoll.sResults = rRoll.sResults .. " [TRANSFER]";
		end
		if not string.match(rRoll.sDesc, "%[MAX%]") then
			resolveShared(rTarget, rComplexDamage, true);
		end
	end

	if string.match(rRoll.sDesc, "%[SHARED%]") then
		rRoll.sResults = rRoll.sResults .. " [SHARED]";
	end

	messageDamageOriginal(rSource, rTarget, rRoll);

	if rComplexDamage.nStolen and (rComplexDamage.nStolen > 0) then
		local rNewRoll = UtilityManager.copyDeep(rRoll);
		rNewRoll.sType = "heal";
		rNewRoll.sDesc = "[HEAL][STOLEN]";
		rNewRoll.nTotal = rComplexDamage.nStolen;
		ActionDamage.applyDamage(rSource, rSource, rNewRoll);
	end
	if rComplexDamage.nTempStolen and (rComplexDamage.nTempStolen > 0) then
		local rNewRoll = UtilityManager.copyDeep(rRoll);
		rNewRoll.sType = "heal";
		rNewRoll.sDesc = "[HEAL][STOLEN][TEMP]";
		rNewRoll.nTotal = rComplexDamage.nTempStolen;
		ActionDamage.applyDamage(rSource, rSource, rNewRoll);
	end
	if rComplexDamage.nTransfered and (rComplexDamage.nTransfered > 0) then
		local rNewRoll = UtilityManager.copyDeep(rRoll);
		rNewRoll.sType = "heal";
		rNewRoll.sDesc = "[HEAL][TRANSFER]";
		rNewRoll.nTotal = rComplexDamage.nTransfered;
		ActionDamage.applyDamage(rSource, rSource, rNewRoll);
	end
	if rComplexDamage.rSharingTargets then
		local rTempRoll = UtilityManager.copyDeep(rRoll);
		rTempRoll.sDesc = "[SHARED]";
		if bIsHeal then
			rTempRoll.sDesc = "[HEAL][SHARED]";
		end
		for sSharingTarget,nRate in pairs(rComplexDamage.rSharingTargets) do
			local rNewRoll = UtilityManager.copyDeep(rTempRoll);
			rNewRoll.nTotal = math.floor(rRoll.nTotal * nRate);
			ActionDamage.applyDamage(rTarget, ActorManager.resolveActor(sSharingTarget), rNewRoll);
		end
	end
end

function resolveDamage(rTarget, rRoll, rComplexDamage)
	local _,nodeTarget = ActorManager.getTypeAndNode(rTarget);
	local nMaxTotal = 0;
	for sTypes,nDamage in pairs(rRoll.aDamageTypes or{}) do
		local aTemp = StringManager.split(sTypes, ",", true);
		local nMax = 0;
		local bCheckMax = false;
		local nSteal = 0;
		local bCheckSteal = false;
		local nTempSteal = 0;
		local bCheckTempSteal = false;
		local nTransfer = 0;
		local bCheckTransfer = false;
		for _,type in ipairs(aTemp) do
			if bCheckMax or bCheckSteal or bCheckTempSteal or bCheckTransfer then
				local sRate = string.match(type, DAMAGE_RATE_PATTERN);
				if sRate then
					if bCheckMax then
						nMax = tonumber(sRate);
					elseif bCheckSteal then
						nSteal = tonumber(sRate);
					elseif bCheckTempSteal then
						nTempSteal = tonumber(sRate);
					elseif bCheckTransfer then
						nTransfer = tonumber(sRate);
					end
				end
				bCheckSteal = false;
				bCheckTempSteal = false;
				bCheckTransfer = false;
			end

			if type == "maxhp" then
				nMax = 1;
				bCheckMax = true;
			elseif type == "steal" then
				nSteal = 1;
				bCheckSteal = true;
			elseif type == "hsteal" then
				nSteal = 0.5;
			elseif type == "stealtemp" then
				nTempSteal = 1;
				bCheckTempSteal = true;
			elseif type == "hstealtemp" then
				nTempSteal = 0.5;
			elseif type == "transfer" then
				nTransfer = 1;
				bCheckTransfer = true;
			end
		end

		if (nMax > 0) or (nSteal > 0) or (nTempSteal > 0) or (nTransfer > 0) then
			local rDamageOutput = {aDamageTypes={[sTypes]=nDamage}, nVal=nDamage, tNotifications={}};
			local nDamageAdjust = ActionDamage.getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput);
			nDamageAdjust = nDamageAdjust + nDamage;
			rComplexDamage.nStolen = (rComplexDamage.nStolen or 0) + math.floor(nDamageAdjust * nSteal);
			rComplexDamage.nTempStolen = (rComplexDamage.nTempStolen or 0) + math.floor(nDamageAdjust * nTempSteal)
			rComplexDamage.nTransfered = (rComplexDamage.nTransfered or 0) + math.floor(nDamageAdjust * nTransfer)

			if (nMax > 0) and (nDamageAdjust > 0) then
				nMaxTotal = nMaxTotal + (nMax * nDamageAdjust);
			end
		end
	end

	if nMaxTotal > 0 then
		resolveMaxDamage(nMaxTotal, rRoll, nodeTarget);
	end

	resolveShared(rTarget, rComplexDamage, false);
end

function resolveMaxDamage(nMax, rRoll, nodeTarget)
	local fields = HpManager.getHealthFields(nodeTarget);
	rRoll.sResults = rRoll.sResults .. " [MAX REDUCED]";
	local nWounds = DB.getValue(nodeTarget, fields.wounds, 0);
	DB.setValue(nodeTarget, fields.wounds, "number", math.max(0, nWounds - nMax));

	local nAdjust = DB.getValue(nodeTarget, fields.adjust, 0) - nMax;
	DB.setValue(nodeTarget, fields.adjust, "number", nAdjust);

	local nTotal = HpManager.recalculateTotal(nodeTarget);
	if nTotal <= 0 then
		HpManager.beginCalculating();
		if not string.match(rRoll.sResults, "%[INSTANT DEATH%]") then
			rRoll.sResults = rRoll.sResults .. " [INSTANT DEATH]";
		end
		nAdjust = nAdjust - nTotal;
		DB.setValue(nodeTarget, fields.total, "number", 0);
		DB.setValue(nodeTarget, fields.adjust, "number", nAdjust);
		DB.setValue(nodeTarget, fields.deathsavefail, "number", 3);
		HpManager.endCalculating();
	end
end

function resolveShared(rTarget, rComplexDamage, bIsHeal)
	local nodeTargetCT = ActorManager.getCTNode(rTarget);
	local sTargetPath = nodeTargetCT.getPath();
	for _,nodeEffect in pairs(DB.getChildren(nodeTargetCT, "effects")) do
		local nActive = DB.getValue(nodeEffect, "isactive", 0);
		if (nActive == 1) then
			local sLabel = DB.getValue(nodeEffect, "label", "");
			local aEffectComps = EffectManager.parseEffect(sLabel);
			local aTargetConditionComps = {};
			for i = 1, #aEffectComps do
				local sCheckFor = "SHAREDMG";
				if bIsHeal then
					sCheckFor = "SHAREHEAL";
				end

				local rEffectComp = EffectManager5E.parseEffectComp(aEffectComps[i]);
				if rEffectComp.type == "IF" then
					if not EffectManager5E.checkConditional(rTarget, nodeEffect, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "IFT" then
					table.insert(aTargetConditionComps, rEffectComp);
				elseif rEffectComp.type == sCheckFor then
					configureSharingTargets(rComplexDamage, rTarget, sTargetPath, nodeEffect, rEffectComp, aTargetConditionComps);
				end
			end
		end
	end
end

function configureSharingTargets(rComplexDamage, rTarget, sTargetPath, nodeEffect, rEffectComp, aTargetConditionComps)
	rComplexDamage.rSharingTargets = rComplexDamage.rSharingTargets or {};
	for _,sSharingTarget in ipairs(getSharingTargets(sTargetPath, nodeEffect)) do
		if checkTargetConditionals(aTargetConditionComps, rTarget, nodeEffect, sSharingTarget) then
			rComplexDamage.rSharingTargets[sSharingTarget]
			= (rComplexDamage.rSharingTargets[sSharingTarget] or 0) + rEffectComp.mod;
		end
	end
end

function getSharingTargets(sActorPath, nodeEffect)
	local aTargets = {};
	for _,nodeTarget in pairs(DB.getChildren(nodeEffect, "targets")) do
		tryAddSharingTarget(aTargets, sActorPath, DB.getValue(nodeTarget, "noderef"));
	end
	if #aTargets == 0 then
		tryAddSharingTarget(aTargets, sActorPath, DB.getValue(nodeEffect, "source_name"));
	end
	return aTargets;
end

function tryAddSharingTarget(aTargets, sActorPath, sTargetPath)
	if ((sTargetPath or "") ~= "") and (sTargetPath ~= sActorPath) then
		table.insert(aTargets, sTargetPath);
	end
end

function checkTargetConditionals(aTargetConditionComps, rTarget, nodeEffect, sSharingTarget)
	for _,rTargetConditionComp in ipairs(aTargetConditionComps) do
		if not EffectManager5E.checkConditional(rTarget, nodeEffect, rTargetConditionComp.remainder, sSharingTarget) then
			return false;
		end
	end
	return true;
end