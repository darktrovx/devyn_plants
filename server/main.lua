config = require 'config.server'
ox_inventory = exports.ox_inventory

local plants = {}
local planters = {}

-- functions
local function generateUUID()
    return ('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function createPlant(plantData)

    local uuid = generateUUID()
    local plantId = #plants + 1

    plants[plantId] = {
        uuid = uuid,
        type = plantData.type,
        data = plantData.data,
        stage = 1,
        plantDate = os.time(),
        lastCheck = os.time(),
    }

    local id = MySQL.insert.await('INSERT INTO plants (uuid, type, data, stage, plantdate) VALUES (?, ?, ?, ?, ?)', { uuid, plantData.type, json.encode(plantData.data), 1, os.time() })

    if id then
        local invId = ('plant:%s'):format(uuid)
        lib.logger(0, 'plant_create', ('Created plant uuid: %s'):format(uuid))
        ox_inventory:RegisterStash(invId, ('%s plant'):format(plantData.type), 2, 100000)
        TriggerClientEvent("plants:addPlant", -1, plantId, plants[plantId])
        return uuid
    else
        lib.logger(0, 'plant_create', ('Failed to create plant uuid: %s'):format(uuid))
        return false
    end
end

local function removePlant(plantId)
    local uuid = plants[plantId].uuid
    local affectedRows = MySQL.update.await('UPDATE plants SET stage = ? WHERE uuid = ?', { 0, uuid })
    if affectedRows == 0 then
        lib.logger(0, 'plant_remove', ('Failed to remove plant uuid: %s'):format(uuid))
        return false
    else
        lib.logger(0, 'plant_remove', ('Removed plant uuid: %s'):format(uuid))
        TriggerClientEvent("plants:removePlant", -1, plantId)
        plants[plantId] = nil
        return true
    end
end

local function updatePlant(plantId, plantData)
    local uuid = plants[plantId].uuid
    if not uuid then return end

    if plantData.data.save then
        plantData.data.save = false

        local affectedRows = MySQL.update.await('UPDATE plants SET stage = ?, data = ? WHERE uuid = ?', { plantData.stage, json.encode(plantData.data), uuid })
        if affectedRows == 0 then
            lib.logger(0, 'plant_update', ('Failed to update plant uuid: %s'):format(uuid))
        end

    end

    local prevStage = plants[plantId].stage
    plants[plantId] = plantData

    if prevStage ~= plantData.stage then
        TriggerClientEvent("plants:updatePlant", -1, plantId, plantData)
    end

end

local function getPlantsByType(plantType)
    local plantsByType = {}
    for id, plant in pairs(plants) do
        if plant.type == plantType then
            plantsByType[id] = plant
        end
    end
    return plantsByType
end

-- events

RegisterNetEvent('plant:harvestPlant', function(data)
    local src = source
    local plantId = data.plantId
    local plant = plants[plantId]

    if plant then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local plantCoords = plant.data.coords

        if #(playerCoords - vec3(plantCoords.x, plantCoords.y, plantCoords.z)) > 10.0 then
            exports.qbx_core:ExploitBan(src, 'Too far away from plant')
            return
        end

        local success = lib.callback.await('plant:harvest', src)

        if success then

            local player = exports.qbx_core:GetPlayer(src)

            local invId = ('plant:%s'):format(plant.uuid)
            if removePlant(plantId) then
                local item = config.plantTypes[plant.type].harvest.item
                local amount = math.random(config.plantTypes[plant.type].harvest.min, config.plantTypes[plant.type].harvest.max)

                amount += plant.data.bonus

                ox_inventory:AddItem(src, item, amount)
                lib.logger(src, 'plant_harvest', ('Citizen ID: %s harvested %s uuid: %s at coords: %s'):format(player.PlayerData.citizenid, plant.type, plant.uuid, plantCoords))
            else
                exports.qbx_core:ExploitBan(src, ('Invalid Plant ID'):format(plantId))
            end
        end
    else
        exports.qbx_core:ExploitBan(src, 'Invalid Plant')
    end
end)

RegisterNetEvent('plant:destroyPlant', function(data)
    local src = source
    local plantId = data.plantId
    local plant = plants[plantId]

    if plant then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local plantCoords = plant.data.coords

        if #(playerCoords - vec3(plantCoords.x, plantCoords.y, plantCoords.z)) > 10.0 then
            exports.qbx_core:ExploitBan(src, 'Too far away from plant')
            return
        end

        local success = lib.callback.await('plant:destroy', src)

        if success then

            local player = exports.qbx_core:GetPlayer(src)

            if removePlant(plantId) then            
                lib.logger(src, 'plant_destroy', ('Citizen ID: %s destroyed %s uuid: %s at coords: %s'):format(player.PlayerData.citizenid, plant.type, plant.uuid, plantCoords))
            else
                exports.qbx_core:ExploitBan(src, ('Invalid Plant ID'):format(plantId))
            end

        end

    else
        exports.qbx_core:ExploitBan(src, 'Invalid Plant')
    end
end)

-- callbacks

lib.callback.register('plants:requestPlants', function(source, cb)
    return plants
end)

-- items

for seed, seedData in pairs(config.seedItems) do
    exports.qbx_core:CreateUseableItem(seed, function(source, item)
        local player = exports.qbx_core:GetPlayer(source)
        if player.Functions.GetItemByName(item.name) == nil then return end

        if not config.plantTypes[seedData.plantType] then
            TriggerClientEvent('ox_lib:notify', source, {type = 'error', title = 'Plant', description = 'Invalid plant type' })
            return
        end
    
        local slot = item.slot
        local strain = item.metadata.strain or 'none'
    
        local coords = lib.callback.await('plant:plant', source, seedData.plantType)
    
        if coords then
    
            local removed, resp = ox_inventory:RemoveItem(source, seed, 1, false, item.slot)
    
            if removed then
    
                local planted = createPlant({
                    type = seedData.plantType,
                    data = {
                        coords = coords,
                        strain = strain,
                        food = config.plantTypes[seedData.plantType].defaults.food,
                        water = config.plantTypes[seedData.plantType].defaults.water,
                        decayTick = 0,
                        bonus = 0,
                    }
                })
    
                if planted then
                    lib.logger(source, 'plant_seed', ('Citizen ID: %s planted % at coords: %s'):format(player.PlayerData.citizenid, seedData.plantType, coords))
                    TriggerClientEvent('ox_lib:notify', source, {type = 'success', title = 'Plant', description = 'You have planted a seed' })
                else
                    TriggerClientEvent('ox_lib:notify', source, {type = 'error', title = 'Plant', description = 'Failed to plant seed' })
                end
            else
                TriggerClientEvent('ox_lib:notify', source, {type = 'error', title = 'Plant', description = 'You do not have this item' })
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {type = 'error', title = 'Plant', description = 'Planting cancelled' })
        end
    end)
end

-- threads

CreateThread(function()
    local rows = MySQL.query.await('SELECT * FROM plants WHERE stage != 0')
    for _,plant in pairs(rows) do
        local id = #plants + 1
        plants[id] = {
            uuid = plant.uuid,
            type = plant.type,
            stage = plant.stage,
            data = json.decode(plant.data),
            plantDate = plant.plantDate,
        }
        local invId = ('plant:%s'):format(plant.uuid)
        ox_inventory:RegisterStash(invId, ('%s plant'):format(plant.type), 2, 100000)
    end
end)

CreateThread(function()
    while true do
        Wait(config.plantCheck * 1000)
        for plantId, plantData in pairs(plants) do
            local plant = lib.table.deepclone(plantData)
            --print(('Checking plant ID: %s uuid: %s'):format(plantId, plant.uuid))
            local invId = ('plant:%s'):format(plant.uuid)
            local plantItems = ox_inventory:GetInventoryItems(invId)
            local plantType = config.plantTypes[plant.type]
            
            -- ================ PLANT FOOD LOGIC ================
            if plant.stage < #plantType.stages then
                
                local growthItems = plantType.growthItems
                local foods = growthItems.food
                local waters = growthItems.water

                local hasFood = 0
                local hasWater = 0

                if plantItems then
                    for item, _ in pairs(foods) do
                        if plantItems[item] then
                            hasFood = plantItems[item].count
                            --print('Removing 1 food item')
                            ox_inventory:RemoveItem(invId, item, 1, false, plantItems[item].slot)
                            break
                        end
                    end

                    if not hasFood then
                        --print('Removing 1 food')
                        plant.data.food -= 1
                    end

                    for item, _ in pairs(waters) do
                        if plantItems[item] then
                            hasWater = plantItems[item].count
                            --print('Removing 1 water item')
                            ox_inventory:RemoveItem(invId, item, 1, false, plantItems[item].slot)
                            break
                        end
                    end
                end

                if not hasWater then
                    --print('Removing 1 water')
                    plant.data.water -= 1
                end

                if plant.data.food <= 0 and plant.data.water <= 0 then
                    --print('Removing plant because no food or water')
                    removePlant(plantId)
                    return
                elseif plant.data.decayTick >= 5 then
                    --print('Removing plant because decayed')
                    removePlant(plantId)
                    return
                elseif plant.data.food <= 0 or plant.data.water <= 0 then
                    --print('Decaying plant')
                    plant.data.decayTick += 1
                end

                -- ================ PLANT STAGE LOGIC ================
                local stage = config.plantTypes[plant.type].stages[plant.stage]
                local time = stage.time
                if not plant.data.lastCheck then plant.data.lastCheck = os.time() end
                local timeDiff = os.time() - plant.data.lastCheck

                if timeDiff >= time then

                    plant.stage += 1
                    plant.data.lastCheck = os.time()
                    plant.data.save = true
                    --print('Advancing plant stage to: '..plant.stage)

                    -- ================ PLANT BONUS LOGIC ================
                    if stage.bonus then
                        if hasWater >= stage.bonus.water and hasFood >= stage.bonus.food then
                            --print('Adding bonus')
                            plant.data.bonus += stage.bonus.extra
                        end
                    end
                end

                updatePlant(plantId, plant)
            end
        end
    end
end)