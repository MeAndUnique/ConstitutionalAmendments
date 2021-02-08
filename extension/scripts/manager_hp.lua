-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

OOB_MSGTYPE_ROLLHP = "rollhp";

local addInfoDBOriginal;
local resetHealthOriginal;
local addPcOriginal;
local addPregenCharOriginal;

local bAddingPregen = false;
local nodeAddedPregenChar;

local bAddingInfo = false;
local bAddingUnconscious = false;

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ROLLHP, handleRollHp);
	ActionsManager.registerResultHandler("hp", onHpRoll);

	if User.isHost() then
		for _,node in pairs(DB.getChildren("charsheet")) do
			firstTimeSetup(node);
		end

		resetHealthOriginal = CharManager.resetHealth;
		CharManager.resetHealth = resetHealth;

		addInfoDBOriginal = CharManager.addInfoDB;
		CharManager.addInfoDB = addInfoDB;

		addPcOriginal = CombatManager.addPC;
		CombatManager.addPC = addPC;

		addPregenCharOriginal = CampaignDataManager2.addPregenChar;
		CampaignDataManager2.addPregenChar = addPregenChar;

		DB.addHandler("charsheet", "onChildAdded", onCharAdded);
		DB.addHandler("charsheet.*.classes", "onChildDeleted", onClassDeleted);
		DB.addHandler("charsheet.*.classes.*.level", "onUpdate", onLevelChanged);
		DB.addHandler("charsheet.*.classes.*.rolls.*", "onUpdate", onRollChanged);

		initializeEffects();
	end
end

-- Overrides
function resetHealth(nodeChar, bLong)
	resetHealthOriginal(nodeChar, bLong);
	if bLong and OptionsManager.getOption("LRAD") == "" then
		DB.setValue(nodeChar, "hp.adjust", "number", 0);
		recalculateTotal(nodeChar);
	end
end

function addInfoDB(nodeChar, sClass, sRecord)
	bAddingInfo = true;

	local nAdjustHP = DB.getValue(nodeChar, "hp.adjust", 0);
	local nInitialHP = DB.getValue(nodeChar, "hp.total", 0);
	addInfoDBOriginal(nodeChar, sClass, sRecord);
	local nUpdatedHp = DB.getValue(nodeChar, "hp.total", 0);

	if nInitialHP ~= nUpdatedHp then
		DB.setValue(nodeChar, "hp.adjust", "number", nAdjustHP);
		recalculateBase(nodeChar);
	end
	
	bAddingInfo = false;
end

function addPC(nodePC)
	addPcOriginal(nodePC);
	local nodeCT = CombatManager.getCTFromNode(nodePC);
	DB.addHandler(nodeCT.getPath("effects"), "onChildUpdate", onCombatantEffectUpdated);
	nodeCT.onDelete = onCombatantDeleted;
end

function addPregenChar(nodeSource)
	bAddingPregen = true;
	addPregenCharOriginal(nodeSource);
	if nodeAddedPregenChar then
		firstTimeSetup(nodeAddedPregenChar);
		nodeAddedPregenChar = nil;
	end
	bAddingPregen = false;
end

-- Event Handlers
function onCharAdded(nodeParent, nodeChar)
	if bAddingPregen then
		nodeAddedPregenChar = nodeChar;
	end
end

function onClassDeleted(nodeClasses)
	local nodeChar = nodeClasses.getParent();
	DB.deleteNode(nodeChar.getPath("hp.discrepancy"));
	recalculateBase(nodeChar);
end

function onLevelChanged(nodeLevel)
	local nOffset = -1;
	local nodeClass = nodeLevel.getParent();
	local nodeChar = nodeClass.getChild("...");
	local nLevel = nodeLevel.getValue();
	if not bAddingInfo then
		nOffset = DB.getChildCount(nodeClass, "rolls") - nLevel;
	end

	local bFirstLevel = DB.getValue(nodeChar, "hp.base", 0) == 0;
	if nOffset > 0 then
		for i=nLevel+1,nLevel+nOffset do
			DB.deleteNode(nodeClass.getPath(getRollNodePath(i)))
			DB.deleteNode(nodeChar.getPath("hp.discrepancy"));
		end
	else
		for i=nLevel+nOffset+1, nLevel do
			local nValue = getHpRoll(nodeClass, bFirstLevel, i);
			bFirstLevel = false;
			if nValue > 0 then
				DB.setValue(nodeClass, getRollNodePath(i), "number", nValue);
			end
		end
	end

	if not bAddingInfo then
		recalculateBase(nodeChar);
	end
end

function onRollChanged(nodeRoll)
	local nodeChar = nodeRoll.getChild(".....");
	DB.deleteNode(nodeChar.getPath("hp.discrepancy"));
	recalculateBase(nodeChar);
end

function onCombatantDeleted(nodeCombatant)
	DB.removeHandler(nodeCombatant.getPath("effects"), "onChildUpdate", onCombatantEffectUpdated);
end

function onCombatantEffectUpdated(nodeEffectList)
	if bAddingUnconscious then
		return;
	end

	local nodeCombatant = nodeEffectList.getParent();
	local class, record = DB.getValue(nodeCombatant, "link");
	if class == "charsheet" then
		local nodeChar = DB.findNode(record);
		if nodeChar then
			local nOriginal = DB.getValue(nodeChar, "hp.total", 0);
			local nTotal = recalculateTotal(nodeChar);

			if nOriginal ~= nTotal then
				local nWounds = DB.getValue(nodeChar, "hp.wounds", 0);
				if nWounds >= nTotal then
					if not EffectManager5E.hasEffect(nodeChar, "Unconscious") then
						EffectManager.addEffect("", "", nodeCombatant, { sName = "Unconscious", nDuration = 0 }, true);
						Comm.deliverChatMessage({font="msgfont", text="[STATUS: Dying]"});
						DB.setValue(nodeChar, "hp.wounds", "number", nTotal);
					end
				end
			end
		end
	end
end

function onHpRoll(rSource, rTarget, rRoll)
	local nodeChar = DB.findNode(rSource.sCreatureNode);
	if nodeChar then
		local nodeClass = nodeChar.getChild("classes." .. rRoll.sClass);
		if nodeClass then
			local nClassLevel = DB.getValue(nodeClass, "level", 0);
			local nLevel = tonumber(rRoll.sLevel);
			if nLevel <= nClassLevel then
				local nResult = ActionsManager.total(rRoll);
				DB.setValue(nodeClass, getRollNodePath(nLevel), "number", nResult);

				local nConBonus = DB.getValue(nodeChar, "abilities.constitution.bonus", 0);
				local nMiscBonus = getMiscHpBonus(nodeChar);
				messageHP(rSource, nResult, nConBonus, nMiscBonus);
				recalculateBase(nodeChar);
			end
		end
	end
end

function handleRollHp(msgOOB)
	local nodeClass = DB.findNode(msgOOB.sClass);
	if nodeClass then
		local aDice = DB.getValue(nodeClass, "hddie");
		local hpRoll = {sType="hp", aDice=aDice, sClass=nodeClass.getName(), sLevel=msgOOB.sLevel};
		ActionsManager.roll(nodeClass.getChild("..."), nil, hpRoll, false);
	end
end

-- Core functionality
function firstTimeSetup(nodeChar)
	local baseNode = nodeChar.getChild("hp.base");
	if not baseNode then
		local nTotal = DB.getValue(nodeChar, "hp.total", 0)
		if nTotal > 0 then
			local nConBonus = DB.getValue(nodeChar, "abilities.constitution.bonus", 0);
			local nMiscBonus = getMiscHpBonus(nodeChar);

			local nCalculated = 0;
			for _,nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
				local nHDMult, nHDSides = getHdInfo(nodeClass);
				if nHDMult > 0 then
					local nLevel = DB.getValue(nodeClass, "level", 0);
					for i=1,nLevel do
						local nValue = 0;
						if nCalculated == 0 then
							nValue = nHDMult * nHDSides;
						else
							nValue = getAverageHp(nHDMult, nHDSides);
						end
						DB.setValue(nodeClass, getRollNodePath(i), "number", nValue);
						nCalculated = nCalculated + math.max(1, nValue + nConBonus) + nMiscBonus;
					end
				end
			end

			if nCalculated ~= nTotal then
				local nDifference = nTotal - nCalculated;
				DB.setValue(nodeChar, "hp.discrepancy", "number", nDifference);
			end
		end

		DB.setValue(nodeChar, "hp.base", "number", nTotal);
	end
end

function initializeEffects()
	for _,nodeCT in pairs(CombatManager.getCombatantNodes()) do
		local class, record = DB.getValue(nodeCT, "link");
		if class == "charsheet" then
			local nodeChar = DB.findNode(record);
			if nodeChar then
				DB.addHandler(nodeCT.getPath("effects"), "onChildUpdate", onCombatantEffectUpdated);
				nodeCT.onDelete = onCombatantDeleted;
				recalculateTotal(nodeChar);
			end
		end
	end
end

function recalculateTotal(nodeChar)
	local nBaseHP = DB.getValue(nodeChar, "hp.base", 0)
	local nAdjustHP = DB.getValue(nodeChar, "hp.adjust", 0)
	local nConAdjustment = getConAdjustment(nodeChar);
	local nTotal = nBaseHP + nAdjustHP + nConAdjustment;
	DB.setValue(nodeChar, "hp.total", "number", nTotal);
	return nTotal;
end

function recalculateAdjust(nodeChar)
	local nTotalHP = DB.getValue(nodeChar, "hp.total", 0)
	local nBaseHP = DB.getValue(nodeChar, "hp.base", 0)
	local nConAdjustment = getConAdjustment(nodeChar);
	local nAdjust = nTotalHP - nBaseHP - nConAdjustment;
	DB.setValue(nodeChar, "hp.adjust", "number", nAdjust);
	return nAdjust;
end

function recalculateBase(nodeChar)
	local nConBonus = DB.getValue(nodeChar, "abilities.constitution.bonus", 0);
	local nMiscBonus = getMiscHpBonus(nodeChar);
	local nSum = DB.getValue(nodeChar, "hp.discrepancy", 0);
	for _,nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
		for _,nodeRoll in pairs(DB.getChildren(nodeClass, "rolls")) do
			nSum = nSum + math.max(1, nodeRoll.getValue() + nConBonus) + nMiscBonus;
		end
	end

	DB.setValue(nodeChar, "hp.base", "number", nSum);
	recalculateTotal(nodeChar);
	return nSum;
end

-- Utility
function getConAdjustment(nodeChar)
	local nMod, _ = ActorManager5E.getAbilityEffectsBonus(nodeChar, "constitution")
	local nLevels = getTotalLevel(nodeChar);
	return nMod * nLevels;
end

function getTotalLevel(nodeChar)
	local nTotal = 0;
	for _,nodeChild in pairs(DB.getChildren(nodeChar, "classes")) do
		local nLevel = DB.getValue(nodeChild, "level", 0);
		if nLevel > 0 then
			nTotal = nTotal + nLevel;
		end
	end
	return nTotal;
end

function getMiscHpBonus(nodeChar)
	-- TODO add extensibility point for HP modifiers
	local nMiscBonus = 0;
	if CharManager.hasTrait(nodeChar, CharManager.TRAIT_DWARVEN_TOUGHNESS) then
		nMiscBonus = 1;
	end
	if CharManager.hasFeature(nodeChar, CharManager.FEATURE_DRACONIC_RESILIENCE) then
		nMiscBonus = nMiscBonus + 1;
	end
	if CharManager.hasFeat(nodeChar, CharManager.FEAT_TOUGH) then
		nMiscBonus = nMiscBonus + 2
	end
	return nMiscBonus;
end

function getHdInfo(nodeClass)
	local aDice = DB.getValue(nodeClass, "hddie");
	local nHDMult = 0;
	local nHDSides = 0;
	if aDice then
		nHDMult = table.getn(aDice);
		if nHDMult > 0 then
			nHDSides = tonumber(aDice[1]:sub(2));
		end
	end
	return nHDMult, nHDSides;
end

function getAverageHp(nHDMult, nHDSides)
	return math.floor(((nHDMult * (nHDSides + 1)) / 2) + 0.5);
end

function getHpRoll(nodeClass, bFirstLevel, nClassLevel)
	local bRoll = OptionsManager.getOption("HRHP") == "roll";
	local aDice = DB.getValue(nodeClass, "hddie");
	local nHDMult = table.getn(aDice);
	local nValue = 0;
	if nHDMult > 0 then
		local nHDSides = tonumber(aDice[1]:sub(2));
		if bFirstLevel then
			nValue = nHDMult * nHDSides;
		elseif bRoll then
			notifyRollHp(nodeClass, nClassLevel, aDice);
		else
			nValue = math.floor(((nHDMult * (nHDSides + 1)) / 2) + 0.5);
		end
	end
	return nValue;
end

function getRollNodePath(nLevel)
	return string.format("rolls.lvl-%03d", nLevel);
end

function notifyRollHp(nodeClass, nClassLevel, aDice)
	local messageOOB = {type=OOB_MSGTYPE_ROLLHP, sClass=nodeClass.getPath(), sLevel=tostring(nClassLevel)};
	
	if User.isHost() then
		local sOwner = DB.getOwner(nodeClass);
		if sOwner ~= "" then
			for _,vUser in ipairs(User.getActiveUsers()) do
				if vUser == sOwner then
					Comm.deliverOOBMessage(messageOOB, sOwner);
					return;
				end
			end
		end
	end
	
	handleRollHp(messageOOB);
end

function messageHP(rSource, nRoll, nCon, nMisc)
	local sName = ActorManager.getDisplayName(rSource);
	local message = {
		font = "msgfont",
		icon = "roll_heal",
		text = "HP Rolled [Roll: " .. nRoll .. "][CON: " .. nCon .. "][Misc: " .. nMisc .. "]  -> [to " .. sName .. "]"
	};
	Comm.deliverChatMessage(message);
end

function messageDiscrepancy(nodeChar)
	local nDiscrepancy = DB.getValue(nodeChar, "hp.discrepancy", 0);
	if nDiscrepancy ~= 0 then
		local message = {
			font = "msgfont",
			icon = "indicator_stop",
			text = "There is a discrepancy of " .. nDiscrepancy .. " hitpoints. Please update the roll values accordinly."
		};
		Comm.addChatMessage(message);
	end
end