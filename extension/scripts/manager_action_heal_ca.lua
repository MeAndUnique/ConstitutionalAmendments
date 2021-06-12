-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local getRollOriginal;
local onHealOriginal;

function onInit()
	getRollOriginal = ActionHeal.getRoll;
	ActionHeal.getRoll = getRoll;
	
	onHealOriginal = ActionHeal.onHeal;
	ActionHeal.onHeal = onHeal;
	ActionsManager.registerResultHandler("heal", onHeal);
end

function getRoll(rActor, rAction)
	local rRoll = getRollOriginal(rActor, rAction);
	if rAction.subtype == "max" then
		rRoll.sDesc = rRoll.sDesc .. " [MAX]";
	end
	return rRoll;
end

function onHeal(rSource, rTarget, rRoll)
	if string.match(rRoll.sDesc, "%[HEAL") then
		if string.match(rRoll.sDesc, "%[MAX%]") then
			onMaxHeal(rSource, rTarget, rRoll);
		end
	end

	onHealOriginal(rSource, rTarget, rRoll);
end

function onMaxHeal(rSource, rTarget, rRoll)
	local nTotal = ActionsManager.total(rRoll);		
	local sTargetType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if sTargetType == "pc" then
		local nAdjust = DB.getValue(nodeTarget, "hp.adjust", 0) + nTotal;
		DB.setValue(nodeTarget, "hp.adjust", "number", nAdjust);
		HpManager.recalculateTotal(nodeTarget);

		-- Add wounds so that we can heal them and gain all of the benefits of ruleset logic.
		local nWounds = DB.getValue(nodeTarget, "hp.wounds", 0) + nTotal;
		DB.setValue(nodeTarget, "hp.wounds", "number", nWounds);
	else
		local nHpTotal = DB.getValue(nodeTarget, "hptotal", 0) + nTotal;
		DB.setValue(nodeTarget, "hptotal", "number", nHpTotal);

		-- Add wounds so that we can heal them and gain all of the benefits of ruleset logic.
		local nWounds = DB.getValue(nodeTarget, "wounds", 0) + nTotal;
		DB.setValue(nodeTarget, "wounds", "number", nWounds);
	end
end