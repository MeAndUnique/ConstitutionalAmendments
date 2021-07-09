-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

bPatternContains = false;
local containsOriginal;

function onInit()
	containsOriginal = StringManager.contains;
	PowerManager.contains = contains;
	Debug.chat("match check", string.gmatch("[2]", "%[(%d+.?%d*)%]"))
end

function contains(set, item)
	local result = containsOriginal(set, item);
	if not result and bPatternContains then
		for i = 1, #set do
			if item:gmatch(set[i]) then
				return true;
			end
		end
	end
	return result;
end