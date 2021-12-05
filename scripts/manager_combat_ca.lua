-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

local addNPCOriginal;
local addNPCHelperOriginal;
local resetHealthOriginal;

local nodeNewEntry;

function onInit()
	CombatManager.setCustomTurnStart(onTurnStart);

	addNPCOriginal = CombatManager.getCustomAddNPC();
	CombatManager.setCustomAddNPC(addNPC);

	addNPCHelperOriginal = CombatManager.addNPCHelper;
	CombatManager.addNPCHelper = addNPCHelper;

	resetHealthOriginal = CombatManager2.resetHealth;
	CombatManager2.resetHealth = resetHealth;
end

function onTurnStart(nodeEntry)
	if not nodeEntry then
		return;
	end

	-- Copy/paste of original with change to handle NPCs
	if OptionsManager.isOption("HRST", "on") then
		if nodeEntry then
			local sClass, sRecord = DB.getValue(nodeEntry, "link");
			if sClass == "npc" and sRecord then
				local nHP = DB.getValue(nodeEntry, "hptotal", 0);
				local nWounds = DB.getValue(nodeEntry, "wounds", 0);
				local nDeathSaveFail = DB.getValue(nodeEntry, "deathsavefail", 0);
				if (nHP > 0) and (nWounds >= nHP) and (nDeathSaveFail < 3) then
					local rActor = ActorManager.resolveActor(nodeEntry);
					if not EffectManager5E.hasEffect(rActor, "Stable") then
						ActionSave.performDeathRoll(nil, rActor, true);
					end
				end
			end
		end
	end
end

function addNPC(sClass, nodeNPC, sName)
	addNPCOriginal(sClass, nodeNPC, sName);
	if nodeNewEntry then
		-- Account for Max/Random NPC HP settings.
		DB.setValue(nodeNewEntry, "hp", "number", DB.getValue(nodeNewEntry, "hptotal", 0));
		 -- Undo for the automated update from the CT field
		DB.setValue(nodeNewEntry, "hpadjust", "number", 0);
		nodeNewEntry = nil;
	end
end

function addNPCHelper(nodeNPC, sName)
	local nodeEntry, nodeLastMatch = addNPCHelperOriginal(nodeNPC, sName);
	nodeNewEntry = nodeEntry;
	return nodeEntry, nodeLastMatch;
end

function resetHealth(nodeChar, bLong)
	resetHealthOriginal(nodeChar, bLong);

	local bResetHitDice = false;
	local bResetHalfHitDice = false;
	local bResetQuarterHitDice = false;
	
	local sOptHRHV = OptionsManager.getOption("HRHV");
	if sOptHRHV == "fast" then
		if bLong then
			bResetHitDice = true;
		else
			bResetQuarterHitDice = true;
		end
	elseif sOptHRHV == "slow" then
		if bLong then
			bResetHalfHitDice = true;
		end
	else
		if bLong then
			bResetHalfHitDice = true;
		end
	end
	
	-- Reset all hit dice
	if bResetHitDice then
		for _,vClass in pairs(DB.getChildren(nodeChar, "classes")) do
			DB.setValue(vClass, "hdused", "number", 0);
		end
	end

	-- Reset half or quarter of hit dice (assume biggest hit dice selected first)
	if bResetHalfHitDice or bResetQuarterHitDice then
		local nHDUsed, nHDTotal = CharManager.getClassHDUsage(nodeChar);
		if nHDUsed > 0 then
			local nHDRecovery;
			if bResetQuarterHitDice then
				nHDRecovery = math.max(math.floor(nHDTotal / 4), 1);
			else
				nHDRecovery = math.max(math.floor(nHDTotal / 2), 1);
			end
			if nHDRecovery >= nHDUsed then
				for _,vClass in pairs(DB.getChildren(nodeChar, "classes")) do
					DB.setValue(vClass, "hdused", "number", 0);
				end
			else
				local nodeClassMax, nClassMaxHDSides, nClassMaxHDUsed;
				while nHDRecovery > 0 do
					nodeClassMax = nil;
					nClassMaxHDSides = 0;
					nClassMaxHDUsed = 0;
					
					for _,vClass in pairs(DB.getChildren(nodeChar, "classes")) do
						local nClassHDUsed = DB.getValue(vClass, "hdused", 0);
						if nClassHDUsed > 0 then
							local aClassDice = DB.getValue(vClass, "hddie", {});
							if #aClassDice > 0 then
								local nClassHDSides = tonumber(aClassDice[1]:sub(2)) or 0;
								if nClassHDSides > 0 and nClassMaxHDSides < nClassHDSides then
									nodeClassMax = vClass;
									nClassMaxHDSides = nClassHDSides;
									nClassMaxHDUsed = nClassHDUsed;
								end
							end
						end
					end
					
					if nodeClassMax then
						if nHDRecovery >= nClassMaxHDUsed then
							DB.setValue(nodeClassMax, "hdused", "number", 0);
							nHDRecovery = nHDRecovery - nClassMaxHDUsed;
						else
							DB.setValue(nodeClassMax, "hdused", "number", nClassMaxHDUsed - nHDRecovery);
							nHDRecovery = 0;
						end
					else
						break;
					end
				end
			end
		end
	end
	
	if bLong and OptionsManager.getOption("LRAD") == "" then
		DB.setValue(nodeChar, "hpadjust", "number", 0);
		HpManager.recalculateTotal(nodeChar);
	end
end