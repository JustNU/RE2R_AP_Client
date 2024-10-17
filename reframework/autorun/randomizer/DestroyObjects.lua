local DestroyObjects = {}
DestroyObjects.isInit = false
DestroyObjects.lastRemoval = os.time()

function DestroyObjects.Init()
    if Archipelago.IsConnected() and not DestroyObjects.isInit then
        DestroyObjects.isInit = true
        DestroyObjects.DestroyAll()
    end

    -- if the last check for objects to remove was X time ago or more, trigger another removal
    if os.time() - DestroyObjects.lastRemoval > 15 then -- 15 seconds
        DestroyObjects.isInit = false
    end
end

function DestroyObjects.DestroyAll()
    local destroyables = {
        DestroyObjects.GetPurposeGUI(),
        DestroyObjects.GetAdasSecretWeaponLadder(),
        DestroyObjects.GetSherrysKey()
    }

    for k, obj in pairs(destroyables) do
        if obj ~= nil then
            obj:call("destroy", obj)
        end        
    end
end

function DestroyObjects.GetPurposeGUI()
    return Scene.getSceneObject():findGameObject("GUI_Purpose")
end

function DestroyObjects.GetAdasSecretWeaponLadder()
    return Scene.getSceneObject():findGameObject("ADA_PlayCF535_00_HoldHackingGun")
end

function DestroyObjects.GetSherrysKey()
    return Scene.getSceneObject():findGameObject("OrphanAsylum_PlayEvent_CF360")
end

return DestroyObjects