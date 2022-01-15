-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

OOB_MSGTYPE_ROLLHP = "rollhp";

local addInfoDBOriginal;
local resetHealthOriginal;
local addPregenCharOriginal;
local onImportFileSelectionOriginal;

local bAddingCharacter = false;
local nodeAddedCharacter;

local bAddingInfo = false;

local pcFields = {
	adjust = "hp.adjust",
	base = "hp.base",
	deathsavefail = "hp.deathsavefail",
	deathsavesuccess = "hp.deathsavesuccess",
	total = "hp.total",
	wounds = "hp.wounds",
};
local npcFields = {
	adjust = "hpadjust",
	base = "hp",
	deathsavefail = "deathsavefail",
	deathsavesuccess = "deathsavesuccess",
	total = "hptotal",
	wounds = "wounds",
};

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ROLLHP, handleRollHp);
	ActionsManager.registerResultHandler("hp", onHpRoll);

	if Session.IsHost then
		for _,node in pairs(DB.getChildren("charsheet")) do
			firstTimeSetup(node);
		end

		resetHealthOriginal = CharManager.resetHealth;
		CharManager.resetHealth = resetHealth;

		addInfoDBOriginal = CharManager.addInfoDB;
		CharManager.addInfoDB = addInfoDB;

		addPregenCharOriginal = CampaignDataManager2.addPregenChar;
		CampaignDataManager2.addPregenChar = addPregenChar;

		onImportFileSelectionOriginal = CampaignDataManager.onImportFileSelection;
		CampaignDataManager.onImportFileSelection = onImportFileSelection;

		DB.addHandler("charsheet", "onChildAdded", onCharAdded);
		DB.addHandler("charsheet.*.classes", "onChildDeleted", onClassDeleted);
		DB.addHandler("charsheet.*.classes.*.level", "onUpdate", onLevelChanged);
		DB.addHandler("charsheet.*.classes.*.rolls.*", "onUpdate", onRollChanged);
		DB.addHandler("charsheet.*.featlist.*.hpadd", "onUpdate", onAbilityHPChanged);
		DB.addHandler("charsheet.*.featurelist.*.hpadd", "onUpdate", onAbilityHPChanged);
		DB.addHandler("charsheet.*.traitlist.*.hpadd", "onUpdate", onAbilityHPChanged);
		DB.addHandler(CombatManager.CT_COMBATANT_PATH .. ".effects", "onChildUpdate", onCombatantEffectUpdated);

		initializeTotalHitPoints()

		if CharEffectsMNM then
			CharEffectsMNM.setMaxHP = mnmSetMaxHP;
		end
	end
end

function onClose()
	DB.removeHandler("charsheet", "onChildAdded", onCharAdded);
	DB.removeHandler("charsheet.*.classes", "onChildDeleted", onClassDeleted);
	DB.removeHandler("charsheet.*.classes.*.level", "onUpdate", onLevelChanged);
	DB.removeHandler("charsheet.*.classes.*.rolls.*", "onUpdate", onRollChanged);
	DB.removeHandler("charsheet.*.featlist.*.hpadd", "onUpdate", onAbilityHPChanged);
	DB.removeHandler("charsheet.*.featurelist.*.hpadd", "onUpdate", onAbilityHPChanged);
	DB.removeHandler("charsheet.*.traitlist.*.hpadd", "onUpdate", onAbilityHPChanged);
	DB.removeHandler(CombatManager.CT_COMBATANT_PATH .. ".effects", "onChildUpdate", onCombatantEffectUpdated);
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

function addPregenChar(nodeSource)
	bAddingCharacter = true;
	local nodeCharacter = addPregenCharOriginal(nodeSource);
	if nodeCharacter then
		firstTimeSetup(nodeCharacter);
	end
	bAddingCharacter = false;
	return nodeAddedCharacter;
end

function onImportFileSelection(result, vPath)
	bAddingCharacter = true;
	onImportFileSelectionOriginal(result, vPath);
	if nodeAddedCharacter then
		firstTimeSetup(nodeAddedCharacter);
		nodeAddedCharacter = nil;
	end
	bAddingCharacter = false;
	return nodeAddedCharacter;
end

function mnmSetMaxHP(nodeChar, nEffectValue)
	DB.setValue(nodeChar, "effects.maxhp", "number", nEffectValue);
end

-- Event Handlers
function onCharAdded(nodeParent, nodeChar)
	if bAddingCharacter then
		nodeAddedCharacter = nodeChar;
	end
end

function onClassDeleted(nodeClasses)
	local nodeChar = nodeClasses.getParent();
	DB.deleteNode(nodeChar.getPath("hp.discrepancy"));
	recalculateBase(nodeChar);
end

function onLevelChanged(nodeLevel)
	if bAddingCharacter then
		return;
	end

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

function onAbilityHPChanged(nodeHP)
	local nodeChar = nodeHP.getChild("....");
	recalculateBase(nodeChar);
end

function onCombatantEffectUpdated(nodeEffectList)
	local nodeCombatant = nodeEffectList.getParent();
	local rActor = ActorManager.resolveActor(nodeCombatant);
	local fields = getHealthFields(rActor);
	local nodeChar = ActorManager.getCreatureNode(rActor) or nodeCombatant;

	local nOriginal = DB.getValue(nodeChar, fields.total, 0);
	local nTotal = recalculateTotal(nodeChar);

	if nOriginal ~= nTotal then
		local nWounds = DB.getValue(nodeChar, fields.wounds, 0);
		if nWounds >= nTotal then
			if not EffectManager5E.hasEffect(nodeChar, "Unconscious") then
				EffectManager.addEffect("", "", nodeCombatant, { sName = "Unconscious", nDuration = 0 }, true);
				Comm.deliverChatMessage({font="msgfont", text="[STATUS: Dying]"});
				DB.setValue(nodeChar, fields.wounds, "number", nTotal);
			end
		end
	end
end

function onHpRoll(rSource, rTarget, rRoll)
	local nodeChar = rSource;
	if type(nodeChar) ~= "databasenode" then
		nodeChar = DB.findNode(rSource.sCreatureNode);
	end
	if nodeChar then
		local nodeClass = nodeChar.getChild("classes." .. rRoll.sClass);
		if nodeClass then
			local nClassLevel = DB.getValue(nodeClass, "level", 0);
			local nLevel = tonumber(rRoll.sLevel);
			if nLevel <= nClassLevel then
				local nResult = ActionsManager.total(rRoll);
				DB.setValue(nodeClass, getRollNodePath(nLevel), "number", nResult);

				local nConBonus = DB.getValue(nodeChar, "abilities.constitution.bonus", 0);
				local nMiscCharBonus = getMiscellaneousCharacterHpBonus(nodeChar);
				local nMiscClassBonus = getMiscellaneousClassHpBonus(nodeChar, nodeClass);
				messageHP(rSource, nResult, nConBonus, nMiscCharBonus + nMiscClassBonus);
				recalculateBase(nodeChar);
			end
		end
	end
end

function handleRollHp(msgOOB)
	local nodeClass = DB.findNode(msgOOB.sClass);
	if nodeClass then
		local aDice = DB.getValue(nodeClass, "hddie");
		local hpRoll = {sType="hp", aDice=aDice, sClass=nodeClass.getName(), sLevel=msgOOB.sLevel, nMod=0};
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
			local nMiscCharBonus = getMiscellaneousCharacterHpBonus(nodeChar);

			local nCalculated = 0;
			for _,nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
				local nHDMult, nHDSides = getHdInfo(nodeClass);
				if nHDMult > 0 then
					local nLevel = DB.getValue(nodeClass, "level", 0);
					local nMiscClassBonus = getMiscellaneousClassHpBonus(nodeChar, nodeClass);
					for i=1,nLevel do
						local nValue = 0;
						if nCalculated == 0 then
							nValue = nHDMult * nHDSides;
						else
							nValue = getAverageHp(nHDMult, nHDSides);
						end
						DB.setValue(nodeClass, getRollNodePath(i), "number", nValue);
						nCalculated = nCalculated + math.max(1, nValue + nConBonus) + nMiscCharBonus + nMiscClassBonus;
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

function initializeTotalHitPoints()
	for _,nodeCT in pairs(CombatManager.getCombatantNodes()) do
		local rActor = ActorManager.resolveActor(nodeCT);
		local nodeChar = ActorManager.getCreatureNode(rActor) or nodeCT;
		recalculateTotal(nodeChar);
	end
end

function recalculateTotal(nodeChar)
	local fields = getHealthFields(nodeChar);
	local nBaseHP = DB.getValue(nodeChar, fields.base, 0);
	local nAdjustHP = DB.getValue(nodeChar, fields.adjust, 0);
	local nConAdjustment = getConAdjustment(nodeChar);
	local nEffectHP = getEffectAdjustment(nodeChar);
	local nTotal = nBaseHP + nAdjustHP + nEffectHP + nConAdjustment;
	DB.setValue(nodeChar, fields.total, "number", nTotal);
	return nTotal;
end

function recalculateAdjust(nodeChar)
	local fields = getHealthFields(nodeChar);
	local nTotalHP = DB.getValue(nodeChar, fields.total, 0);
	local nBaseHP = DB.getValue(nodeChar, fields.base, 0);
	local nConAdjustment = getConAdjustment(nodeChar);
	local nEffectHP = getEffectAdjustment(nodeChar);
	local nAdjust = nTotalHP - nBaseHP - nEffectHP - nConAdjustment;
	DB.setValue(nodeChar, fields.adjust, "number", nAdjust);
	return nAdjust;
end

function recalculateBase(nodeChar)
	local nConBonus = DB.getValue(nodeChar, "abilities.constitution.bonus", 0);
	local nMiscCharBonus = getMiscellaneousCharacterHpBonus(nodeChar);
	local nSum = DB.getValue(nodeChar, "hp.discrepancy", 0);
	for _,nodeClass in pairs(DB.getChildren(nodeChar, "classes")) do
		local nMiscClassBonus = getMiscellaneousClassHpBonus(nodeChar, nodeClass);
		for _,nodeRoll in pairs(DB.getChildren(nodeClass, "rolls")) do
			nSum = nSum + math.max(1, nodeRoll.getValue() + nConBonus) + nMiscCharBonus + nMiscClassBonus;
		end
	end

	DB.setValue(nodeChar, "hp.base", "number", nSum);
	recalculateTotal(nodeChar);
	return nSum;
end

function getHealthFields(vChar)
	if ActorManager.isPC(vChar) then
		return pcFields;
	end
	return npcFields;
end

-- Utility
function getConAdjustment(nodeChar)
	local nMod = ActorManager5E.getAbilityEffectsBonus(nodeChar, "constitution")
	local nLevels = getTotalLevel(nodeChar);
	return nMod * nLevels;
end

function getEffectAdjustment(nodeChar)
	local nMod = EffectManager5E.getEffectsBonus(nodeChar, "MAXHP", true);
	return nMod;
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

function getMiscellaneousCharacterHpBonus(nodeChar)
	local nMiscBonus = 0;
	local sToughnessLower = StringManager.trim(CharManager.TRAIT_DWARVEN_TOUGHNESS):lower();
	local sToughLower = StringManager.trim(CharManager.FEAT_TOUGH):lower();
	for _,nodeTrait in pairs(DB.getChildren(nodeChar, "traitlist")) do
		if DB.getValue(nodeTrait, "granthp") == 1 then
			nMiscBonus = nMiscBonus + DB.getValue(nodeTrait, "hpadd", 0);
		elseif StringManager.trim(DB.getValue(nodeTrait, "name", "")):lower() == sToughnessLower then
			nMiscBonus = nMiscBonus + 1;
		end
	end
	for _,nodeFeat in pairs(DB.getChildren(nodeChar, "featlist")) do
		if DB.getValue(nodeFeat, "granthp") == 1 then
			nMiscBonus = nMiscBonus + DB.getValue(nodeFeat, "hpadd", 0);
		elseif StringManager.trim(DB.getValue(nodeFeat, "name", "")):lower() == sToughLower then
			nMiscBonus = nMiscBonus + 2;
		end
	end
	return nMiscBonus;
end

function getMiscellaneousClassHpBonus(nodeChar, nodeClass)
	local nMiscBonus = 0;
	local sClassNameLower = StringManager.trim(DB.getValue(nodeClass, "name", "")):lower();
	local sSorcererLower = StringManager.trim(CharManager.CLASS_SORCERER):lower();
	local sDraconicResilienceLower = StringManager.trim(CharManager.FEATURE_DRACONIC_RESILIENCE):lower();
	for _,nodeFeature in pairs(DB.getChildren(nodeChar, "featurelist")) do
		local sSourceNameLower = StringManager.trim(DB.getValue(nodeFeature, "source", "")):lower();
		local sFeatureNameLower = StringManager.trim(DB.getValue(nodeFeature, "name", "")):lower();
		if (sClassNameLower == sSourceNameLower) and (DB.getValue(nodeFeature, "granthp") == 1) then
			nMiscBonus = nMiscBonus + DB.getValue(nodeFeature, "hpadd", 0);
		elseif (sClassNameLower == sSorcererLower) and (sFeatureNameLower == sDraconicResilienceLower) then
			nMiscBonus = nMiscBonus + 1;
		end
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
	
	if Session.IsHost then
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
			text = "There is a discrepancy of " .. nDiscrepancy .. " hitpoints. Please update the roll values accordingly."
		};
		Comm.addChatMessage(message);
	end
end

-- Extra NPC health field handling
function updateNpcHitDice(nodeNPC)
	local nHDMult, nHDSides = getNpcHitDice(nodeNPC);
	if nHDMult and nHDSides then
		local nodeClasses = DB.createChild(nodeNPC, "classes");
		local nodeNpcClass;
		for _,nodeChild in pairs(DB.getChildren(nodeClasses)) do
			if DB.getValue(nodeChild, "name") == "NPC" then
				nodeNpcClass = nodeChild;
				break;
			end
		end

		if not nodeNpcClass then
			nodeNpcClass = DB.createChild(nodeClasses);
		end

		DB.setValue(nodeNpcClass, "name", "string", "NPC");
		DB.setValue(nodeNpcClass, "level", "number", nHDMult);
		DB.setValue(nodeNpcClass, "hddie", "dice", { "d" .. nHDSides });
	end
end

function getNpcHitDice(nodeNPC)
	local sHD = StringManager.trim(DB.getValue(nodeNPC, "hd", ""));
	if sHD then
		local sMult, sSides = sHD:match("(%d+)d(%d+)");
		if sMult and sSides then
			return tonumber(sMult), tonumber(sSides);
		end
	end
end

function canHandleExtraHealthFields(nodeNPC)
	return CombatManager.getCTFromNode(nodeNPC);
end

function hasExtraHealthFields(nodeNPC)
	local bDefault = OptionsManager.isOption("NPCHF", "");
	local nOverride = DB.getValue(nodeNPC, "showextrahealth");
	return HpManager.canHandleExtraHealthFields(nodeNPC) and ((nOverride == 1) or (bDefault and (nOverride ~= 0)));
end