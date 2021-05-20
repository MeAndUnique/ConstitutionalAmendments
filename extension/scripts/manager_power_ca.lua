-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local getPCPowerActionOriginal;
local getPCPowerHealActionTextOriginal;
local performActionOriginal;

function onInit()
	getPCPowerActionOriginal = PowerManager.getPCPowerAction;
	PowerManager.getPCPowerAction = getPCPowerAction;
	
	getPCPowerHealActionTextOriginal = PowerManager.getPCPowerHealActionText;
	PowerManager.getPCPowerHealActionText = getPCPowerHealActionText;

	performActionOriginal = PowerManager.performAction;
	PowerManager.performAction = performAction;
end

function  getPCPowerAction(nodeAction, sSubRoll)
	local rAction, rActor = getPCPowerActionOriginal(nodeAction, sSubRoll);
	if not rActor then
		return;
	end

	if rAction.type == "transfer" then
		rAction.clauses = {};
		local aDamageNodes = UtilityManager.getSortedTable(DB.getChildren(nodeAction, "transferlist"));
		for _,v in ipairs(aDamageNodes) do
			local sAbility = DB.getValue(v, "stat", "");
			local nMult = DB.getValue(v, "statmult", 1);
			local aDice = DB.getValue(v, "dice", {});
			local nMod = DB.getValue(v, "bonus", 0);
			local sDmgType = DB.getValue(v, "type", "");
			local nRatio = DB.getValue(v, "ratio", 1);
			
			table.insert(rAction.clauses, { dice = aDice, stat = sAbility, statmult = nMult, modifier = nMod, dmgtype = sDmgType, ratio = nRatio });
		end
	end

	return rAction, rActor;
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

function getPCPowerTransferActionText(nodeAction)
	local aOutput = {};
	local rAction, rActor = PowerManager.getPCPowerAction(nodeAction);
	if rAction then
		rAction.type = "damage"; --avoid duplicating eval logic
		PowerManager.evalAction(rActor, nodeAction.getChild("..."), rAction);
		rAction.type = "transfer"; --put it back the way it was
		
		local aTransfer = ActionTransfer.getTransferStrings(rAction.clauses);
		for _,rTransfer in ipairs(aTransfer) do
			local sDice = StringManager.convertDiceToString(rTransfer.aDice, rTransfer.nMod);
			local sComponent = sDice;
			if rTransfer.sType ~= "" then
				sComponent = string.format("%s %s", sDice, rTransfer.sType);
			end
			table.insert(aOutput, string.format("%s @%dx", sComponent, rTransfer.nRatio));
		end
	end
	return table.concat(aOutput, " + ");
end

function performAction(draginfo, rActor, rAction, nodePower)
	if not rActor or not rAction then
		return false;
	end
	
	if rAction.type == "transfer" then
		rAction.type = "damage"; --avoid duplicating eval logic
		PowerManager.evalAction(rActor, nodeAction.getChild("..."), rAction);
		rAction.type = "transfer"; --put it back the way it was

		local rRolls = {};
		table.insert(rRolls, ActionTransfer.getRoll(rActor, rAction));

		if #rRolls > 0 then
			ActionsManager.performMultiAction(draginfo, rActor, rRolls[1].sType, rRolls);
		end
	return true;
	else
		return performActionOriginal(draginfo, nodeAction, sSubRoll);
	end
end