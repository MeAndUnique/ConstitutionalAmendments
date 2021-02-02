-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	DataSpell.parsedata["vampiric touch"] = {
		{ type = "attack", range = "M", spell = true, base = "group" },
		{ type = "damage", clauses = { { dice = { "3d6" }, dmgtype = "necrotic, hsteal" } } },
		{ type = "effect", sName = "Vampiric Touch; (C)", sTargeting = "self", nDuration = 1, sUnits = "minute" },
	};
end