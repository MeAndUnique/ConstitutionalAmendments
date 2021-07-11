-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

local bShowWounds = true;
local bUpdating = false;
local sTotal;
local sWounds;
local sLink = nil;

-- For reasons known only to the Old Gods, and perhaps the Lunar Arcanum,
-- the OptionsManager is sometimes a nil value during updateDisplayMode, so a local reference is needed.
local optionsManager;

function onInit()
	if super and super.onInit then
		super.onInit();
	end

	local node = window.getDatabaseNode();
	sTotal = node.getPath(sourceTotal[1]);
	sWounds = node.getPath(sourceWounds[1]);
	onSourceTotalUpdate();
	DB.addHandler(sTotal, "onUpdate", onSourceTotalUpdate);
	DB.addHandler(sWounds, "onUpdate", onSourceWoundsUpdate);

	optionsManager = OptionsManager;
	updateDisplayMode()
	OptionsManager.registerCallback("HPDM", updateDisplayMode);
end

function onClose()
	DB.removeHandler(sTotal, "onUpdate", onSourceTotalUpdate)
	DB.removeHandler(sWounds, "onUpdate", onSourceWoundsUpdate)
	if sLink then
		DB.removeHandler(sLink, "onUpdate", onLinkUpdated);
	end
end

function onDrop(x, y, draginfo)
	if Session.IsHost then
		if draginfo.getType() == "number" then
			local node = window.getDatabaseNode();
			local rActor = ActorManager.getActorFromCT(node);
			ActionDamage.applyDamage(nil, rActor, CombatManager.isCTHidden(node), draginfo.getDescription(), draginfo.getNumberData());
			return true;
		end

		return false;
	end
end

function onSourceTotalUpdate()
	if bUpdating then
		return;
	end

	local nTotal = DB.getValue(sTotal, 0);
	setMaxValue(nTotal);

	bUpdating = true;
	if not bShowWounds then
		local nWounds = DB.getValue(sWounds, 0);
		setValue(nTotal - nWounds);
	end
	
	update();
	bUpdating = false;
end

function onSourceWoundsUpdate()
	if bUpdating then
		return;
	end

	bUpdating = true;
	local nWounds = DB.getValue(sWounds, 0);
	if bShowWounds then
		setValue(nWounds);
	else
		local nTotal = DB.getValue(sTotal, 0);
		setValue(nTotal - nWounds);
	end

	if sLink and not isReadOnly() then
		DB.setValue(sLink, "number", nWounds);
	end

	update();
	bUpdating = false;
end

function onValueChanged()
	if bUpdating or isReadOnly() then
		return;
	end

	bUpdating = true;
	local nWounds;
	if bShowWounds then
		nWounds = getValue()
	else
		local nTotal = DB.getValue(sTotal, 0);
		local nCurrent = getValue();
		nWounds = nTotal - nCurrent;
	end

	if sLink then
		DB.setValue(sLink, "number", nWounds);
	end
	
	DB.setValue(sWounds, "number", nWounds);
	
	update();
	bUpdating = false;
end

function onLinkUpdated()
	if bUpdating or isReadOnly() then
		return;
	end

	bUpdating = true;
	local nWounds = DB.getValue(sLink, 0);
	if bShowWounds then
		setValue(nWounds);
	else
		local nTotal = DB.getValue(sTotal, 0);
		setValue(nTotal - nWounds);
	end
	DB.setValue(sWounds, "number", nWounds);

	update();
	bUpdating = false;
end

function setLink(dbnode, bLock)
	if sLink then
		DB.removeHandler(sLink, "onUpdate", onLinkUpdated);
		sLink = nil;
	end
		
	if dbnode then
		sLink = dbnode.getNodeName();

		if not nolinkwidget then
			addBitmapWidget("field_linked").setPosition("bottomright", 0, -2);
		end
		
		if bLock == true then
			setReadOnly(true);
		end

		DB.addHandler(sLink, "onUpdate", onLinkUpdated);
		onLinkUpdated();
	end
end

function update()
	window.onHealthChanged();
end

function updateDisplayMode()
	bShowWounds = optionsManager.isOption("HPDM", "");
	if bUpdating then
		return;
	end

	bUpdating = true;
	if bShowWounds then
		setValue(DB.getValue(sWounds, 0));
	else
		local nTotal = DB.getValue(sTotal, 0);
		local nWounds = DB.getValue(sWounds, 0);
		setValue(nTotal - nWounds);
	end
	bUpdating = false;
end