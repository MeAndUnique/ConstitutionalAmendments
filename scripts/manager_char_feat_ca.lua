--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local applyToughOriginal;

function onInit()
	applyToughOriginal = CharFeatManager.applyTough;
	CharFeatManager.applyTough = applyTough;
end

function applyTough(nodeChar, bInitialAdd)
	applyToughOriginal(nodeChar, bInitialAdd);
	HpManager.recalculateBase(nodeChar);
end