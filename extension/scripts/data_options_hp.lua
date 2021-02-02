-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	OptionsManager.registerOption2("HPDM", true, "option_header_client", "option_label_HPDM", "option_entry_cycler", 
		{ labels="option_val_hp_current", values="current", baselabel="option_val_hp_wounds", baseval="", default="" });

	OptionsManager.registerOption2("LRAD", false, "option_header_game", "option_label_LRAD", "option_entry_cycler", 
		{ labels="option_val_off", values="off", baselabel="option_val_on", baseval="", default="" });
		
	OptionsManager.registerOption2("HRHP", false, "option_header_houserule", "option_label_HRHP", "option_entry_cycler", 
		{ labels="option_val_hp_roll", values="roll", baselabel="option_val_hp_average", baseval="", default="" });
end