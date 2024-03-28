--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--


local resetHealthOriginal;

function onInit()
	resetHealthOriginal = CharManager.resetHealth;
	CharManager.resetHealth = resetHealth;
end

function resetHealth(nodeChar, bLong)
    if bLong then
        local rSource = ActorManager.resolveActor(nodeChar);
        local tEffects = EffectManager5E.getEffectsByType(rSource, 'HDRECOVERY');
        if next(tEffects) then
            local nMod = 0;
            local aClassHDInfo = {};
            for _,tEffect in pairs(tEffects) do
                if tEffect.mod > nMod then
                    nMod = tEffect.mod;
                    for _,vClass in ipairs(DB.getChildList(nodeChar, "classes")) do
                        local aClassDice = DB.getValue(vClass, "hddie", {});
                        if #aClassDice > 0 then
                            aClassHDInfo[vClass] = tonumber(aClassDice[1]:sub(2)) or 0;
                        end
                    end
                end
            end
            resetHealthOriginal(nodeChar, bLong);
            while nMod > 0 do
                local vClass = recoverHealthHelper(aClassHDInfo);
                if vClass then
                    local nHDUsed = DB.getValue(vClass, "hdused", 0);
                    if nMod <= nHDUsed then
                        DB.setValue(vClass, "hdused","number", nHDUsed - nMod);
                        nMod = 0;
                    else
                        nMod = nMod - nHDUsed;
                        DB.setValue(vClass, "hdused","number", 0);
                    end
                else
                    nMod = 0;
                end
            end
        else
            resetHealthOriginal(nodeChar, bLong);
        end
    end
end

function recoverHealthHelper(aClassHDInfo)
    local nLargestHD = 0;
    local vClassLargest;
    for vClass,nHDSides in pairs(aClassHDInfo) do
        if DB.getValue(vClass, "hdused", 0) == 0 then
            aClassHDInfo[vClass] = nil;
        elseif nHDSides > nLargestHD then
            nLargestHD = nHDSides;
            vClassLargest = vClass;
        end
    end
    return vClassLargest;
end