--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local getRollOriginal;

function onInit()
	getRollOriginal = ActionHeal.getRoll;
	ActionHeal.getRoll = getRoll;
end

function getRoll(rActor, rAction)
	local rRoll = getRollOriginal(rActor, rAction);
	if rAction.subtype == "maxhp" then
		rRoll.sSubtype = rAction.subtype
	end
	return rRoll;
end