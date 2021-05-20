-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	ActionsManager.registerResultHandler("transfer", onTransfer);
end

-- Collapse damage clauses by damage type (in the original order, if possible)
function getTransferStrings(clauses)
	local aOrderedTypes = {};
	local aDmgTypes = {};
	for _,vClause in ipairs(clauses) do
		local rDmgType = aDmgTypes[vClause.dmgtype];
		if not rDmgType then
			rDmgType = {};
			aDmgTypes[vClause.dmgtype] = rDmgType;
		end

		local rRatiodDamageType = rDmgType[vClause.ratio];
		if not rRatiodDamageType then
			rRatiodDamageType = {};
			rRatiodDamageType.aDice = {};
			rRatiodDamageType.nMod = 0;
			rRatiodDamageType.nTotal = 0;
			rRatiodDamageType.sType = vClause.dmgtype;
			rRatiodDamageType.nRatio = vClause.ratio;
			rDmgType[vClause.ratio] = rRatiodDamageType;
			table.insert(aOrderedTypes, rRatiodDamageType);
		end

		for _,vDie in ipairs(vClause.dice) do
			table.insert(rRatiodDamageType.aDice, vDie);
		end
		rRatiodDamageType.nMod = rRatiodDamageType.nMod + vClause.modifier;
		rRatiodDamageType.nTotal = rRatiodDamageType.nTotal + (vClause.nTotal or 0);
	end
	
	return aOrderedTypes;
end

function getRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "transfer";
	rRoll.aDice = {};
	rRoll.nMod = 0;
	
	-- Build description
	rRoll.sDesc = "[HEAL";
	if rAction.order and rAction.order > 1 then
		rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
	end
	rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;

	-- Save the heal clauses in the roll structure
	rRoll.clauses = rAction.clauses;
	
	-- Add the dice and modifiers, and encode ability scores used
	for _,vClause in pairs(rRoll.clauses) do
		for _,vDie in ipairs(vClause.dice) do
			table.insert(rRoll.aDice, vDie);
		end
		rRoll.nMod = rRoll.nMod + vClause.modifier;
		local sAbility = DataCommon.ability_ltos[vClause.stat];
		if sAbility then
			rRoll.sDesc = rRoll.sDesc .. string.format(" [MOD: %s (%s)]", sAbility, vClause.statmult or 1);
		end
	end
	
	-- Encode the damage types
	encodeHealClauses(rRoll);

	-- Handle temporary hit points
	if rAction.subtype == "temp" then
		rRoll.sDesc = rRoll.sDesc .. " [TEMP]";
	end

	-- Handle self-targeting
	if rAction.sTargeting == "self" then
		rRoll.bSelfTarget = true;
	end

	return rRoll;
end

function onTransfer(rSource, rTarget, rRoll)
	if string.match(rRoll.sDesc, "%[HEAL") then
		if string.match(rRoll.sDesc, "%[MAX%]") then
			onMaxHeal(rSource, rTarget, rRoll);
		end
	end

	onHealOriginal(rSource, rTarget, rRoll);
end