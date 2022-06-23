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
	if rAction.subtype == "max" then
		rRoll.sDesc = rRoll.sDesc .. " [MAX]";
	end
	return rRoll;
end