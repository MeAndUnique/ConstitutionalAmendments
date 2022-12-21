--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local applyDraconicResilienceOriginal;

function onInit()
	applyDraconicResilienceOriginal = CharClassManager.applyDraconicResilience;
	CharClassManager.applyDraconicResilience = applyDraconicResilience;
end

function applyDraconicResilience(nodeChar, bInitialAdd)
	applyDraconicResilienceOriginal(nodeChar, bInitialAdd);
	HpManager.recalculateBase(nodeChar);
end