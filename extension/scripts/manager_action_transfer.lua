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
	rRoll.bWeapon = rAction.bWeapon;
	
	rRoll.sDesc = "[TRANSFER";
	if rAction.order and rAction.order > 1 then
		rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
	end
	rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;
	
	-- Save the damage properties in the roll structure
	rRoll.clauses = rAction.clauses;
	
	-- Add the dice and modifiers
	for _,vClause in ipairs(rRoll.clauses) do
		for _,vDie in ipairs(vClause.dice) do
			table.insert(rRoll.aDice, vDie);
		end
		rRoll.nMod = rRoll.nMod + vClause.modifier;
	end
	
	-- Encode the damage types
	encodeTransferTypes(rRoll);
	
	return rRoll;
end

function encodeTransferTypes(rRoll)
	for _,vClause in ipairs(rRoll.clauses) do
		if vClause.dmgtype and vClause.dmgtype ~= "" then
			local sDice = StringManager.convertDiceToString(vClause.dice, vClause.modifier);
			rRoll.sDesc = rRoll.sDesc .. string.format(" [TYPE: %s (%s)(%s)(%s)@%d]",
				vClause.dmgtype,
				sDice,
				vClause.stat or "",
				vClause.statmult or 1,
				vClause.ration);
		end
	end
end

function onTransfer(rSource, rTarget, rRoll)
	if string.match(rRoll.sDesc, "%[HEAL") then
		if string.match(rRoll.sDesc, "%[MAX%]") then
			onMaxHeal(rSource, rTarget, rRoll);
		end
	end

	onHealOriginal(rSource, rTarget, rRoll);
end