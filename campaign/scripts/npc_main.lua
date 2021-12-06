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
			updateHitDice();
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

function updateHitDice()
	local node = getDatabaseNode();
	local nHDMult, nHDSides = getHitDice();
	if nHDMult and nHDSides then
		local nodeClasses = DB.createChild(node, "classes");
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

function getHitDice()
	local sHD = StringManager.trim(DB.getValue(getDatabaseNode(), "hd", ""));
	if sHD then
		local sMult, sSides = sHD:match("(%d+)d(%d+)");
		if sMult and sSides then
			return tonumber(sMult), tonumber(sSides);
		end
	end
end