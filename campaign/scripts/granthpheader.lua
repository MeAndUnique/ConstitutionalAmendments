-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local updateOriginal;

function onInit()
	updateOriginal = super.update;
	super.update = update;
	super.onInit();
end

function update()
	-- This can get called before onInit by other controls. (Specifically seen from ref_ability.onLockChanged)
	if updateOriginal then
		updateOriginal();
	else
		super.update();
	end

	local node = getDatabaseNode();
	local bReadOnly = WindowManager.getReadOnlyState(node);
	hpadd.setReadOnly(bReadOnly);

	local bShow = DB.getValue(node, "granthp") == 1;
	hpadd.setVisible(bShow);
	hpicon.setVisible(bShow);

	resetMenuItems();
	if bReadOnly then
		hpadd.setFrame(nil);
	else
		hpadd.setFrame("fielddark", 7, 5, 7, 5);
		if bShow then
			registerMenuItem(Interface.getString("hide_hp_header"), "deletepointer", 6);
		else
			registerMenuItem(Interface.getString("show_hp_header"), "radial_heal", 5);
		end
	end
end

function onMenuSelection(selection)
	local node = getDatabaseNode();
	if selection == 5 then
		DB.setValue(node, "granthp", "number", 1);
		DB.setValue(node, "hpadd", "number", 1);
		update();
	elseif selection == 6 then
		DB.setValue(node, "granthp", "number", 0);
		DB.setValue(node, "hpadd", "number", 0);
		update();
	end
end