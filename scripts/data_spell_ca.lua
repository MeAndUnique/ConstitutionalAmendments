-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	-- 5E ruleset code doesn't support custom heal subtypes.
	-- DataSpell.parsedata["aid"] = {
	-- 	{ type = "heal", subtype = "max", clauses = { { bonus = 5 } } },
	-- };
	-- DataSpell.parsedata["heroes' feat"] = {
	-- 	{ type = "effect", sName = "Heroes' Feast; IMMUNE: poison,poisoned,frightened; ADVSAV: wisdom", nDuration = 24, sUnits = "hour" },
	-- 	{ type = "heal", subtype = "max", clauses = { { dice = { "2d10" } } } },
	-- };
	DataSpell.parsedata["life transference"] = {
		{ type = "damage", clauses = { { dice = { "4d6" }, dmgtype = "necrotic, transfer, [2]" } } },
	};
	DataSpell.parsedata["vampiric touch"] = {
		{ type = "attack", range = "M", spell = true, base = "group" },
		{ type = "damage", clauses = { { dice = { "3d6" }, dmgtype = "necrotic, hsteal" } } },
		{ type = "effect", sName = "Vampiric Touch; (C)", sTargeting = "self", nDuration = 1, sUnits = "minute" },
	};
	DataSpell.parsedata["warding bond"] = {
		{ type = "effect", sName = "Warding Bond; AC: 1; SAVE: 1; RESIST: all; SHAREDMG: 1", nDuration = 1, sUnits = "hour" },
	};
end