local Items = {}
Items.isInit = false -- keeps track of whether init things like hook need to run
Items.lastInteractable = nil
Items.cancelNextUI = false
Items.cancelNextSafeUI = false
Items.cancelNextStatueUI = false

function Items.Init()
    if not Items.isInit then
        Items.isInit = true

        Items.SetupInteractHook()
        Items.SetupDisconnectWaitHook()
        Items.SetupSafeUIHook()
        Items.SetupStatueUIHook()
        
        local EquipmentManager = sdk.get_managed_singleton(sdk.game_namespace("EquipmentManager"))
        local WeaponBulletUserdata = EquipmentManager:get_field("_WeaponBulletUserdata")
        local LoadingPartsCombos = WeaponBulletUserdata:get_field("_LoadingPartsCombos")
        local Le5Element = LoadingPartsCombos:get_element(11)
        local gotLoadingPartsCombos = Le5Element:call("get_LoadingPartsCombos()")
        local LoadingPartsCombination = gotLoadingPartsCombos:get_element(0)
        LoadingPartsCombination:call("set_AlwaysReloadableForm", false)
        LoadingPartsCombination:call("set_AlwaysReloadableVariableForm", "00000000-0000-0000-0000-000000000000")
    end
end

function Items.SetupInteractHook()
    local interactType = sdk.find_type_definition(sdk.game_namespace("gimmick.action.FeedbackFSM"))
    local interact_method = interactType:get_method("execute")
    -- main item hook, does all the AP stuff
    sdk.hook(interact_method, function(args)
        feedbackFSM = sdk.to_managed_object(args[2])
        feedbackParent = sdk.to_managed_object(feedbackFSM:get_field('_Owner'))
        
        item_name = feedbackParent:call("get_Name()")
        item_folder = feedbackParent:call("get_Folder()")
        item_folder_path = nil
        item_parent_name = nil

        if item_folder then
            item_folder_path = item_folder:call("get_Path()")
        end

        if item_name and item_folder and feedbackParent then
            item_transform = sdk.to_managed_object(feedbackParent:call('get_Transform()'))
            item_transform_parent = sdk.to_managed_object(item_transform:call('get_Parent()'))

            if item_transform_parent then
                item_parent = sdk.to_managed_object(item_transform_parent:call('get_GameObject()'))
                item_parent_name = item_parent:call("get_Name()")
                item_positions = item_parent:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("item.ItemPositions")))

                if not item_name or not item_folder_path or not item_positions then
                    item_parent_name = "" -- unset so we know it's a non-standard item location
                end
            else 
                -- non-item things like typewriters here, so do typewriter interaction tracking
                if string.match(item_name, "Typewriter") then
                    if not Typewriters.unlocked_typewriters[item_name] then
                        Typewriters.AddUnlockedText("", item_name)
                    end

                    Typewriters.Unlock("", item_name)
                    Storage.UpdateLastSavedItems()
                end
            end
        end
        
        log.debug("----------------------------------------")
        log.debug("item name is " ..tostring(item_name))
        log.debug("item folder is " ..tostring(item_folder))
        log.debug("item folder path is " ..tostring(item_folder_path))
        log.debug("item parent name is " ..tostring(item_parent_name))
        log.debug("item position is " ..tostring(item_positions))
        log.debug("----------------------------------------")

        -- nothing to do with AP if not connected
        if not Archipelago.IsConnected() then
            log.debug("Archipelago is not connected.")

            if Archipelago.hasConnectedPrior then
                GUI.AddText("Archipelago is not connected.")
                Items.cancelNextUI = true
            end

            return
        end
        
        -- force exit leon's desk reward UI
        if item_name == "sm44_006_LeonDesk01A_control" then
            Items.cancelNextUI = true
        end

        -- if item_name and item_folder_path are not nil (even empty strings), do a location lookup to see if we should get an item
        if item_name ~= nil and item_folder_path ~= nil then
            local location_to_check = {}
            location_to_check['item_object'] = item_name
            location_to_check['parent_object'] = item_parent_name or ""
            location_to_check['folder_path'] = item_folder_path

            -- If we're interacting with the victory location, send victory and bail
            if Archipelago.CheckForVictoryLocation(location_to_check) then
                Archipelago.SendLocationCheck(location_to_check)
                GUI.AddText("Goal Completed!")

                return
            end

            -- If we run through a trigger named "AutoSaveArea", the game just auto-saved. So update last saved to last received.
            if string.find(item_name, "AutoSaveArea") then
                Storage.UpdateLastSavedItems()

                return
            end

            if item_name == "ScenarioNoAdovance_s05_0000" and item_folder_path == "RopewayContents/World/Location_WasteWater/LocationLevel_WasteWater/LocationFsm_WasteWater/common" then
                GUI.AddText("Warning: Once you leave for Labs, returning to Sewers can cause a softlock.")
                GUI.AddText("It is recommended that you complete all of the checks in Sewers prior to leaving.")
            end

            -- If we're starting Ada's part, get the trigger to end the Ada event, send Ada to it, and trigger it
            if location_to_check['item_object'] == 'CheckPoint_StartAdaPart' then
                local leonStart = Scene.getSceneObject():findGameObject("WW_AdaEndEvent_EV580")
                local leonStartInteract = leonStart:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.action.InteractBehavior")))
                local leonStartTrigger = leonStartInteract:call("getTrigger", 0)

                Player.WarpToPosition(Vector3f.new(-20.61, -42.25, -26.85)) -- right beside the trigger
                leonStartTrigger:call("activate", Scene.getSceneObject():findGameObject("pl2000")) -- activate takes the player object
                return
            end

            -- If we're starting Sherry's part, intercept the stuffed animal interact, send her right beside another trigger to load Orphanage fully,
            --   then use that trigger (the next if below) to send her to the final cutscene
            if item_name == 'sm73_727' then -- very beginning of Sherry section, interacting with stuffed animal  
                item_positions:call('vanishItemAndSave()') -- skip the item stuff entirely

                Player.WarpToPosition(Vector3f.new(54.11, 4.67, -210.19)) -- warp beside the crawl spot in the playroom

                return
            end

            if item_name == 'OrphanAsylum_SetFlag_Tutorial_PL' then -- next convenient trigger for Sherry to hit after Orphanage loads
                Player.WarpToPosition(Vector3f.new(47.86, 0.95, -205.94)) -- warp beside the final sherry cutscene

                -- now, activate the final sherry cutscene
                local sherryEnd = Scene.getSceneObject():findGameObject("OrphanAsylum_PlayEvent_EV400")
                local sherryEndInteract = sherryEnd:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.action.InteractBehavior")))
                local sherryEndFSM = sherryEndInteract:call("getTrigger", 0).Feedbacks[0]
                sherryEndFSM:call("execute")
                
                return
            end
            -- END Sherry Skip
        
            local isLocationRandomized = Archipelago.IsLocationRandomized(location_to_check)
            local isSentChessPanel = Archipelago.IsSentChessPanel(location_to_check)

            if Archipelago.IsItemLocation(location_to_check) and (Archipelago.SendLocationCheck(location_to_check) or Archipelago.IsConnected()) then
                -- if it's an item, call vanish and save to get rid of it
                if item_positions and isLocationRandomized then
                    -- we were originally unsetting the invincibility flag here, but there's occasionally a bug where
                    --    the game forgets that the player exists, making setting the flag not possible
                    -- so we just set our own flag to relentlessly attempt to turn off invinc until it works
                    Archipelago.waitingForInvincibiltyOff = true
                    
                    -- if it's a chess panel that's already been sent, ignore whatever item is there and let the game take over
                    if isSentChessPanel then
                        return
                    end

                    item_positions:call('vanishItemAndSave()')
                end
                
                if string.find(item_name, "SafeBoxDial") then -- if it's a safe, cancel the next safe ui
                    Items.cancelNextSafeUI = true
                    Items.lastInteractable = feedbackParent
                elseif string.find(item_name, "HieroglyphicDialLock") then -- if it's a statue, cancel the next statue ui
                    Items.cancelNextStatueUI = true
                    Items.lastInteractable = feedbackParent
                end
            end
        end
    end)
end

function Items.SetupDisconnectWaitHook()
    local guiNewInventoryTypeDef = sdk.find_type_definition(sdk.game_namespace("gui.NewInventoryBehavior"))
    local guiNewInventoryMethod = guiNewInventoryTypeDef:get_method("setCaptionState")

    -- small hook that handles cancelling inventory UIs when having connected before and being not reconnected
    sdk.hook(guiNewInventoryMethod, function (args)
        if Items.cancelNextUI then
            local uiMaster = Scene.getSceneObject():findGameObject("UIMaster")
            local compGuiMaster = uiMaster:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gui.GUIMaster")))

            Items.cancelNextUI = false
            compGuiMaster:closeInventoryForce()
        end
    end)
end

function Items.SetupStatueUIHook()
    local gimmickStatueBehavior = sdk.find_type_definition(sdk.game_namespace("gimmick.action.GimmickDialLockBehavior"))
    local safeLateUpdateMethod = gimmickStatueBehavior:get_method("lateUpdate")

    -- checks to see if a safe gui close was requested and, if so, close it
    sdk.hook(safeLateUpdateMethod, function (args)
        if Items.cancelNextStatueUI then
            local compFromHook = sdk.to_managed_object(args[2])
            local statueObject = compFromHook:call('get_GameObject()') -- the dial gimmick
            local compGimmickGUI = statueObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gui.RopewayGimmickAttachmentGUI")))
            local compGimmickAttach = statueObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.action.GimmickAttachment")))
            local dialControlObject = compGimmickAttach:get_field("_GimmickControl"):get_GameObject()

            if not dialControlObject then
                return
            end

            -- for some reason, *some* of the statues will throw an error despite properly marking off as they should
            --   i think it's related to the game having two statue controls on some of them (why?!), but don't care enough to dig into more.
            --   so just pcall that f**ker and ignore the error, since it works anyways
            pcall(function () 
                local compAddItems = dialControlObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.option.AddItemsToInventorySettings")))
                local compDialSettings = dialControlObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.option.AttachmentAlphabetLockSettings")))
                local settingList = compAddItems:get_field("SettingList")
                local itemPosObject = settingList[0]:get_field("ItemPositions")
                local itemPositions = itemPosObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("item.ItemPositions")))
                local statueName = statueObject:call("get_Name()")
                local lastInteractableName = ""
                
                if Items.lastInteractable then 
                    lastInteractableName = Items.lastInteractable:call("get_Name()")
                end

                if string.gsub(tostring(lastInteractableName), '_control', '_gimmick') ~= statueName then
                    return
                end

                compFromHook:call("setFinished()")

                if compFromHook:get_field("_CurState") > 1 then
                    Items.cancelNextStatueUI = false
                    Items.lastInteractable = nil
                    itemPositions:vanishItemAndSave()
                    itemPosObject:call("set_Enabled", false)
                    
                    compAddItems:set_field("SettingList", nil)
                    compAddItems:call("set_Enabled", false)
                    compDialSettings:call("TransmitCorrectAnswer", compGimmickGUI)
                    compGimmickGUI:call("SetSatisfy()")
                    compFromHook:call("set_Enabled", false)
                end            
            end)
        end
    end)
end

function Items.SetupSafeUIHook()
    local gimmickSafeBoxBehavior = sdk.find_type_definition(sdk.game_namespace("gui.GimmickSafeBoxDialBehavior"))
    local safeLateUpdateMethod = gimmickSafeBoxBehavior:get_method("CheckInput")

    -- checks to see if a safe gui close was requested and, if so, close it
    sdk.hook(safeLateUpdateMethod, function (args)
        if Items.cancelNextSafeUI then
            local compFromHook = sdk.to_managed_object(args[2])
            local safeBoxObject = compFromHook:call('get_GameObject()') -- the dial gimmick
            local compGimmickGUI = safeBoxObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gui.RopewayGimmickAttachmentGUI")))
            local compGimmickBody = safeBoxObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.action.GimmickBody")))
            local compFsmState = safeBoxObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("FsmStateController")))
            local safeBoxControlObject = compGimmickBody:get_field("_GimmickControl"):call("get_GameObject()")
            local safeBoxControlParent = safeBoxControlObject:get_Transform():get_Parent():get_GameObject()
            local compInteractBehavior = safeBoxControlObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.action.InteractBehavior")))
            local compDialSettings = safeBoxControlObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.option.AttachmentSafeBoxDialSettings")))
            local compAddItem = safeBoxControlParent:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gimmick.option.AddItemToInventorySettings")))
            local itemPosObject = compAddItem:get_field("ItemPositions")
            local itemPositions = itemPosObject:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("item.ItemPositions")))

            Items.cancelNextSafeUI = false
            itemPositions:vanishItemAndSave()
            compGimmickGUI:call("SetSatisfy()")
            compAddItem:set_field("Enable", false) -- I guess set_Enabled is only for gameobjects and not components? smh
            compDialSettings:call("TransmitCorrectAnswer", compGimmickGUI)
        end
    end)
end

-- this was a test to swap items to a different visual item. might not work anymore.
function Items.SwapAllItemsTo(item_name)
    scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
    item_objects = scene:call("findGameObjectsWithTag(System.String)", "Item")

    for k, item in pairs(item_objects:get_elements()) do
        item_name = item:call("get_Name()")
        item_folder = item:call("get_Folder()")
        item_folder_path = item_folder:call("get_Path()")
        item_component = item:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("item.ItemPositions")))

        if item_component then
            item_id = item_component:get_field("InitializeItemId")

            if item_id then -- all item_numbers are hex to decimal, use decimal here
                if new_item_name == "spray" then
                    item_number = 1
                    item_count = 1
                elseif new_item_name == "handgun ammo" then
                    item_number = 15
                    item_count = 30
                elseif new_item_name == "wood crate" then
                    item_number = 294
                    item_count = 1
                elseif new_item_name == "picture block" then
                    item_number = 98
                    item_count = 1
                end

                item_component:set_field("InitializeItemId", item_number)
                item_component:set_field("InitializeCount", item_count)
                item_component:call("createInitializeItem()")
            end
        end
    end
end

return Items
