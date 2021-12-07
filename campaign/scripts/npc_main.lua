-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	if not shouldHandleExtraHealthFields() then
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
	else
		onHealthChanged();
		OptionsManager.registerCallback("WNDC", onHealthChanged);
		changeHealthDisplay();
		OptionsManager.registerCallback("HPDM", changeHealthDisplay);

		if ColorManager.COLOR_TEMP_HP then
			hptemp.setColor(ColorManager.COLOR_TEMP_HP);
		end
		if ColorManager.COLOR_ADJUSTED_HP then
			hpadjust.setColor(ColorManager.COLOR_ADJUSTED_HP);
		end

		if DB.getChildCount(getDatabaseNode(), "classes") == 0 then
			HpManager.updateNpcHitDice(getDatabaseNode());
		end
	end

	if super and super.onInit then
		super.onInit();
	end
end

function shouldHandleExtraHealthFields()
	local node = getDatabaseNode();
	return CombatManager.getCTFromNode(node);
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