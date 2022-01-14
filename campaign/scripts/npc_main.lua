-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	if canHandleExtraHealthFields() then
		local node = getDatabaseNode();

		onHealthChanged();
		OptionsManager.registerCallback("WNDC", onHealthChanged);
		changeHealthDisplay();
		OptionsManager.registerCallback("HPDM", changeHealthDisplay);
		showOrHideHealthFields();
		if not DB.getChild(node, "instadeath") then
			OptionsManager.registerCallback("NPCDI", showOrHideHealthFields);
		end

		if ColorManager.COLOR_TEMP_HP then
			hptemp.setColor(ColorManager.COLOR_TEMP_HP);
		end
		if ColorManager.COLOR_ADJUSTED_HP then
			hpadjust.setColor(ColorManager.COLOR_ADJUSTED_HP);
		end

		if DB.getChildCount(getDatabaseNode(), "classes") == 0 then
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

function canHandleExtraHealthFields()
	local node = getDatabaseNode();
	return CombatManager.getCTFromNode(node);
end

function showOrHideHealthFields()
	--todo option and field names
	local bShowDefault = not OptionsManager.isOption("NPCDI", "");
	local nShowSetting = DB.getValue(getDatabaseNode(), "instadeath");
	local bShow = (nShowSetting == 0) or (bShowDefault and (nShowSetting ~= 1));

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
		--todo name icon etc
		registerMenuItem("hide", "delete", 7);
	else
		registerMenuItem("show", "delete", 6);
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
		DB.setValue(getDatabaseNode(), "instadeath", "number", 0);
		OptionsManager.unregisterCallback("NPCDI", showOrHideHealthFields);
		showOrHideHealthFields();
	elseif selection == 7 then
		DB.setValue(getDatabaseNode(), "instadeath", "number", 1);
		OptionsManager.unregisterCallback("NPCDI", showOrHideHealthFields);
		showOrHideHealthFields();
	end
end