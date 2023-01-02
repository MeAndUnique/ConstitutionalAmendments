--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local helperAddClassHPOriginal;
local applyDraconicResilienceOriginal;

function onInit()
	helperAddClassHPOriginal = CharClassManager.helperAddClassHP;
	CharClassManager.helperAddClassHP = helperAddClassHP;

	applyDraconicResilienceOriginal = CharClassManager.applyDraconicResilience;
	CharClassManager.applyDraconicResilience = applyDraconicResilience;
end

function helperAddClassHP(rAdd)
	HpManager.beginCalculating();
	helperAddClassHPOriginal(rAdd);
	HpManager.recalculateBase(rAdd.nodeChar);
	HpManager.endCalculating();
end

function applyDraconicResilience(nodeChar, bInitialAdd)
	applyDraconicResilienceOriginal(nodeChar, bInitialAdd);
	HpManager.recalculateBase(nodeChar);
end