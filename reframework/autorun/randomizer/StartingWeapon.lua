local StartingWeapon = {}

function StartingWeapon.Init()
    if not Storage or Storage.swappedStartingWeapon == true then
        return false
    end

    if Archipelago.starting_weapon ~= nil then
        StartingWeapon.SwapTo(Archipelago.starting_weapon)
    end
end

function StartingWeapon.SwapTo(item_name)
    local item_ref = nil
    local item_number = nil
    local item_ammo = nil

    local currentItems = Inventory.GetCurrentItems()

    -- if we can't access the player's inventory, then don't attempt to swap their starting weapon yet
    if not currentItems or #currentItems == 0 then
        return false
    end

    for k, item in pairs(Lookups.items) do
        if item.name == item_name and item.type == "Weapon" and item.ammo ~= nil then
            item_ref = item
            item_number = item.decimal
			item_ammo_count = item.count
            
            for k2, item2 in pairs(Lookups.items) do
                if item2.name == item.ammo then
                    item_ammo = item2.decimal

                    break
                end
            end
        
            break
        end
    end

    if item_ref and item_number then
        local itemId, weaponId, weaponParts, bulletId, count = nil

        itemId = -1
        weaponId = item_number
        
		itemId2 = item_ammo
		weaponId2 = -1
		weaponParts2 = -1
		bulletId2 = -1
		count2 = item_ammo_count

        if item_ref.type == "Weapon" then
            bulletId = item_ammo
        end

        count = item_ref.count

        if count == nil then
            count = 1
        end

        -- item ids 1 and 9 are the Matilda and SLS 60, or Leon's starting weapon and Claire's starting weapon, for both scenarios
        Inventory.SwapItem(nil, { 1, 9 }, tonumber(itemId), tonumber(weaponId), weaponParts, bulletId, tonumber(count))
		-- also replace ammo (hopefully)
		Inventory.SwapItem({ 15 }, nil, tonumber(itemId2), tonumber(weaponId2), weaponParts2, bulletId2, tonumber(count2))

        Storage.swappedStartingWeapon = true
        GUI.AddTexts({
            { message="Swapped starting weapon to " },
            { message=item_name, color="green" },
            { message="!"}
        })
    end
end

return StartingWeapon