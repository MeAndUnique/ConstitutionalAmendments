-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	local node = getDatabaseNode();
	if HpManager.canHandleExtraHealthFields(node) then
		onHealthChanged();
		OptionsManager.registerCallback("WNDC", onHealthChanged);
		changeHealthDisplay();
		OptionsManager.registerCallback("HPDM", changeHealthDisplay);
		showOrHideHealthFields();
		if not DB.getChild(node, "showextrahealth") then
			OptionsManager.registerCallback("NPCHF", showOrHideHealthFields);
		end

		if ColorManager.COLOR_TEMP_HP then
			hptemp.setColor(ColorManager.COLOR_TEMP_HP);
		end
		if ColorManager.COLOR_ADJUSTED_HP then
			hpadjust.setColor(ColorManager.COLOR_ADJUSTED_HP);
		end

		if DB.getChildCount(node, "classes") == 0 then
			HpManager.updateNpcHitDice(node);
		end
	else
		wounds.setVisible(false);
		wounds_label.setVisible(false);
		hptemp_label.setVisible(false);
		hptemp.setVisible(false);
		hpadjust_label.setVisible(false);
		hpadjust.setVisible(false);

		hd_label.setVisible(false);
		hitdice.setVisible(false);

		deathsave_label.setVisible(false);
		deathsave_roll.setVisible(false);
		deathsavesuccess.setVisible(false);
		deathsavesuccess_label.setVisible(false);
		deathsavefail.setVisible(false);
		deathsavefail_label.setVisible(false);
	end

	if super and super.onInit then
		super.onInit();
	end
end

function onClose()
	OptionsManager.unregisterCallback("WNDC", onHealthChanged);
	OptionsManager.unregisterCallback("HPDM", changeHealthDisplay);
	OptionsManager.unregisterCallback("NPCHF", showOrHideHealthFields);
end

function showOrHideHealthFields()
	local bShow = HpManager.hasExtraHealthFields(getDatabaseNode());

	hd_label.setVisible(bShow);
	hitdice.setVisible(bShow);

	deathsave_label.setVisible(bShow);
	deathsave_roll.setVisible(bShow);
	deathsavesuccess.setVisible(bShow);
	deathsavesuccess_label.setVisible(bShow);
	deathsavefail.setVisible(bShow);
	deathsavefail_label.setVisible(bShow);

	resetMenuItems();
	if bShow then
		registerMenuItem(Interface.getString("hide_extra_health_fields"), "delete", 7);
	else
		registerMenuItem(Interface.getString("show_extra_health_fields"), "radial_plus", 6);
	end
end

function onHealthChanged()
	local sColor = ActorHealthManager.getHealthColor(getDatabaseNode());
	wounds.setColor(sColor);
end

function changeHealthDisplay()
	if OptionsManager.isOption("HPDM", "") then
		wounds_label.setValue(Interface.getString("ct_tooltip_wounds"));
	else
		wounds_label.setValue(Interface.getString("char_tooltip_currenthp"));
	end
end

function onMenuSelection(selection)
	if selection == 6 then
		DB.setValue(getDatabaseNode(), "showextrahealth", "number", 1);
		OptionsManager.unregisterCallback("NPCHF", showOrHideHealthFields);
		showOrHideHealthFields();
	elseif selection == 7 then
		DB.setValue(getDatabaseNode(), "showextrahealth", "number", 0);
		OptionsManager.unregisterCallback("NPCHF", showOrHideHealthFields);
		showOrHideHealthFields();
	end
end