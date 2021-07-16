-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

local containsOriginal;
local nCount = 0;

function onInit()
	containsOriginal = StringManager.contains;
	StringManager.contains = contains;
end

function beginContainsPattern()
	nCount = nCount + 1;
end

function endContainsPattern()
	nCount = nCount - 1;
end

function contains(set, item)
	local result = containsOriginal(set, item);
	if not result and nCount > 0 then
		for _,pattern in ipairs(set) do
			if item:match('^' .. pattern .. '$') then
				return true;
			end
		end
	end
	return result;
end