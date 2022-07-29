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
	table.insert(DataCommon.dmgtypes, "max");
	table.insert(DataCommon.dmgtypes, "steal");
	table.insert(DataCommon.dmgtypes, "hsteal");
	table.insert(DataCommon.dmgtypes, "stealtemp");
	table.insert(DataCommon.dmgtypes, "hstealtemp");
	table.insert(DataCommon.dmgtypes, DAMAGE_RATE_PATTERN);
	table.insert(DataCommon.specialdmgtypes, "max");
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

function applyDamage(rSource, rTarget, vRollOrSecret, sDamage, nTotal)
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if not nodeTarget then
		return;
	end

	local rRoll;
	if type(vRollOrSecret) == "table" then
		rRoll = vRollOrSecret;
		sDamage = vRollOrSecret.sDesc;
		nTotal = vRollOrSecret.nTotal;
	end

	local decodeResult = ActionDamage.decodeDamageText(nTotal, sDamage);
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
			if string.match(sDamage, "%[HEAL") and string.match(sDamage, "%[MAX%]") then
				applyMaxHeal(rTarget, nTotal);
			end
		elseif decodeResult.sType == "recovery" and (sTargetNodeType ~= "pc") then
			-- Hijack NPC recovery, since it doesn't work in the ruleset anyway.
			sDamage = applyNPCRecovery(nodeTarget, sDamage);
		end
	end

	return applyDamageOriginal(rSource, rTarget, vRollOrSecret, sDamage, nTotal);
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
	if string.match(sDamageDesc, "%[HEAL") and string.match(sDamageDesc, "%[MAX%]") then
		decodeResult.sTypeOutput = "Maximum hit points";
	end
	return decodeResult;
end

function messageDamage(rSource, rTarget, vRollOrSecret, sDamageText, sDamageDesc, sTotal, sExtraResult)
	local rComplexDamage = {};
	local rRoll;

	if type(vRollOrSecret) == "table" then
		rRoll = vRollOrSecret;

		if rRoll.sType == "damage" then
			resolveDamage(rSource, rTarget, rRoll, rComplexDamage);
		elseif rRoll.sType == "recovery" then
			rRoll.sDamageText = rRoll.sDamageText:gsub("%[HEAL", "[RECOVERY")
		elseif rRoll.sType == "heal" then
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
	end

	messageDamageOriginal(rSource, rTarget, vRollOrSecret, sDamageText, sDamageDesc, sTotal, sExtraResult);

	if rRoll then
		if rComplexDamage.nStolen and (rComplexDamage.nStolen > 0) then
			local rNewRoll = createShallowCopy(rRoll);
			rNewRoll.sType = "heal";
			rNewRoll.sDesc = "[HEAL][STOLEN]";
			rNewRoll.nTotal = rComplexDamage.nStolen;
			ActionDamage.applyDamage(rSource, rSource, rNewRoll);
		end
		if rComplexDamage.nTempStolen and (rComplexDamage.nTempStolen > 0) then
			local rNewRoll = createShallowCopy(rRoll);
			rNewRoll.sType = "heal";
			rNewRoll.sDesc = "[HEAL][STOLEN][TEMP]";
			rNewRoll.nTotal = rComplexDamage.nTempStolen;
			ActionDamage.applyDamage(rSource, rSource, rNewRoll);
		end
		if rComplexDamage.nTransfered and (rComplexDamage.nTransfered > 0) then
			local rNewRoll = createShallowCopy(rRoll);
			rNewRoll.sType = "heal";
			rNewRoll.sDesc = "[HEAL][TRANSFER]";
			rNewRoll.nTotal = rComplexDamage.nTransfered;
			ActionDamage.applyDamage(rSource, rSource, rNewRoll);
		end
		if rComplexDamage.tSharingTargets then
			shareDamageWithTargets(rTarget, rComplexDamage.tSharingTargets, rRoll)
		end
	end
end

function shareDamageWithTargets(rTarget, tSharingTargets, rRoll)
	local bIsHeal = rRoll.nTotal < 0;
	if bIsHeal then
		rRoll.tSharedHealWith = rRoll.tSharedHealWith or {};
		rRoll.tSharedHealWith[ActorManager.getCTNodeName(rTarget)] = true;
	else
		rRoll.tSharedDamageWith = rRoll.tSharedDamageWith or {};
		rRoll.tSharedDamageWith[ActorManager.getCTNodeName(rTarget)] = true;
	end

	local rTempRoll = createShallowCopy(rRoll);
	rTempRoll.sDesc = "[SHARED]";
	if bIsHeal then
		rTempRoll.sDesc = "[HEAL][SHARED]";
	end
	for sSharingTarget,nRate in pairs(tSharingTargets) do
		tryShareDamage(rTarget, rTempRoll, sSharingTarget, nRate)
	end
end

function tryShareDamage(rTarget, rRoll, sSharingTarget, nRate)
	Debug.chat("tryShareDamage", rTarget, rRoll, sSharingTarget, nRate)
	local rNewRoll = createShallowCopy(rRoll);
	rNewRoll.nTotal = math.floor(rRoll.nTotal * nRate);

	local bIsHeal = rNewRoll.nTotal < 0;
	local tAlreadySharedWith;
	if bIsHeal then
		tAlreadySharedWith = rRoll.tSharedHealWith or {};
	else
		tAlreadySharedWith = rRoll.tSharedDamageWith or {};
	end

	if tAlreadySharedWith[sSharingTarget] then
		return;
	end

	ActionDamage.applyDamage(rTarget, ActorManager.resolveActor(sSharingTarget), rNewRoll);
end

function resolveDamage(rSource, rTarget, rRoll, rComplexDamage)
	local _,nodeTarget = ActorManager.getTypeAndNode(rTarget);
	local nMax = 0;
	for sTypes,nDamage in pairs(rRoll.aDamageTypes or{}) do
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
				local sRate = string.match(type, DAMAGE_RATE_PATTERN);
				if sRate then
					if bCheckSteal then
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
			local rDamageOutput = {aDamageTypes={[sTypes]=nDamage}, nVal=nDamage, tNotifications={}};
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
		resolveMaxDamage(nMax, rRoll, nodeTarget);
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
	HpManager.recalculateTotal(nodeTarget);

	local nTotal = DB.getValue(nodeTarget, fields.total, 0);
	if nTotal <= 0 then
		if not string.match(rRoll.sResults, "%[INSTANT DEATH%]") then
			rRoll.sResults = rRoll.sResults .. " [INSTANT DEATH]";
		end
		nAdjust = nAdjust - nTotal;
		DB.setValue(nodeTarget, fields.total, "number", 0);
		DB.setValue(nodeTarget, fields.adjust, "number", nAdjust);
		DB.setValue(nodeTarget, fields.deathsavefail, "number", 3);
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
			for i = 1, #aEffectComps do
				local sCheckFor = "SHAREDMG";
				if bIsHeal then
					sCheckFor = "SHAREHEAL";
				end

				local rEffectComp = EffectManager5E.parseEffectComp(aEffectComps[i]);
				if rEffectComp.type == sCheckFor then
					rComplexDamage.tSharingTargets = rComplexDamage.tSharingTargets or {};
					for _,sSharingTarget in ipairs(getSharingTargets(sTargetPath, nodeEffect)) do
						rComplexDamage.tSharingTargets[sSharingTarget]
							= (rComplexDamage.tSharingTargets[sSharingTarget] or 0) + rEffectComp.mod;
					end
				end
			end
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

function createShallowCopy(rRoll)
	local rNewRoll = {};
	for sName, vValue in pairs(rRoll) do
		rNewRoll[sName] = vValue;
	end
	return rNewRoll;
end