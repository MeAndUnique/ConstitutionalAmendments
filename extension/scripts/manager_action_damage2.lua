-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

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

	decodeDamageTextOriginal = ActionDamage.decodeDamageText;
	ActionDamage.decodeDamageText = decodeDamageText;

	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;
end

function decodeDamageText(nDamage, sDamageDesc)
	decodeResult = decodeDamageTextOriginal(nDamage, sDamageDesc);
	if string.match(sDamageDesc, "%[HEAL") and string.match(sDamageDesc, "%[MAX%]") then
		decodeResult.sTypeOutput = "Maximum hit points";
	end
	return decodeResult;
end

function messageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
	local nStolen = 0;
	local nTempStolen = 0;
	if decodeResult and decodeResult.sType == "damage" then
		local sTargetType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
		local nMax = 0;
		for sTypes,nDamage in pairs(decodeResult.aDamageTypes) do
			local aTemp = StringManager.split(sTypes, ",", true);
			local bMax = false;
			local nSteal = 0;
			local nTempSteal = 0;
			for _,type in ipairs(aTemp) do
				bMax = bMax or type == "max";
				if type == "steal" then
					nSteal = 1;
				elseif type == "hsteal" then
					nSteal = 0.5;
				end
				if type == "stealtemp" then
					nTempSteal = 1;
				elseif type == "hstealtemp" then
					nTempSteal = 0.5;
				end
			end

			if bMax or (nSteal > 0) or (nTempSteal > 0) then
				local rDamageOutput = {aDamageTypes={[sTypes]=nDamage}};
				local nDamageAdjust = ActionDamage.getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput);
				nDamageAdjust = nDamageAdjust + nDamage;
				nStolen = nStolen + math.floor(nDamageAdjust * nSteal);
				nTempStolen = nTempStolen + math.floor(nDamageAdjust * nTempSteal)

				if bMax and (nDamageAdjust > 0) then
					nMax = nMax + nDamageAdjust;
				end
			end
		end

		if nMax > 0 then
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
	elseif string.match(sDamageDesc, "%[STOLEN%]") then
		sExtraResult = sExtraResult .. " [STOLEN]";
	end
	decodeResult = nil;

	messageDamageOriginal(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult);

	if nStolen > 0 then
		local sDamage = "[HEAL][STOLEN]";
		ActionDamage.applyDamage(rSource, rSource, bSecret, sDamage, nStolen);
	end
	if nTempStolen > 0 then
		local sDamage = "[HEAL][STOLEN][TEMP]";
		ActionDamage.applyDamage(rSource, rSource, bSecret, sDamage, nTempStolen);
	end
end