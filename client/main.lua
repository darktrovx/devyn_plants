config = require 'config.client'
ox_inventory = exports.ox_inventory

local plants = {}
local IN_PROGRESS = false
local PLACING = false
local PLANT = nil

-- functions

local function managePlant(plantId)
    local invId = ('plant:%s'):format(plants[plantId].uuid)
    ox_inventory:openInventory('stash', invId)
end

local function onEnter(self)
    local model = config[self.plantType][self.plantStage].model
    lib.requestModel(model)
    local entity = CreateObject(model, self.plant.coords.x, self.plant.coords.y, self.plant.coords.z, false, false, false)
    SetEntityInvincible(entity, true)
    FreezeEntityPosition(entity, true)
    SetEntityHeading(entity, self.plant.coords.w)
    plants[self.plantId].entity = entity

    exports.interact:AddLocalEntityInteraction({
        entity = entity,
        options = {
            {
                label = 'Manage',
                action = function()
                    managePlant(self.plantId) 
                end,
            },
            {
                label = 'Harvest',
                serverEvent = 'plant:harvestPlant',
                args = {
                    plantId = self.plantId
                },
                canInteract = function()
                    return plants[self.plantId].stage == #config[self.plantType]
                end
            },
            {
                label = 'Destroy',
                serverEvent = 'plant:destroyPlant',
                args = {
                    plantId = self.plantId
                }
            },
        },
        distance = 6.0,
        interactDst = 3.0,
        offset = config[self.plantType][self.plantStage].offset,
    })

end

local function onExit(self)
    DeleteEntity(plants[self.plantId].entity)
    plants[self.plantId].entity = nil
end

local function clearPlacement()
    DeleteEntity(PLANT)
    PLACING = false
    PLANT = nil
end

local function placePlant(model)
    if PLACING then return end
    ox_inventory:closeInventory()
    lib.requestModel(model)

    PLANT = CreateObject(model, 0, 0, 0, false, false, false)
    SetEntityHeading(PLANT, GetEntityHeading(cache.ped))
    SetEntityAlpha(PLANT, 150)
    SetEntityCollision(PLANT, false, false)
    SetEntityInvincible(PLANT, true)
    FreezeEntityPosition(PLANT, true)

    local heading = 0.0
    SetEntityHeading(PLANT, heading)

    PLACING = true

    while PLACING do
        local hit, _, coords, _, _ = lib.raycast.cam(511, 3, 7.0)

        if hit then

            if IsControlPressed(0, 174) then
                heading = heading + 5
                if heading > 360 then heading = 0.0 end
            end
    
            if IsControlPressed(0, 175) then
                heading = heading - 5
                if heading < 0 then heading = 360.0 end
            end

            SetEntityCoords(PLANT, coords.x, coords.y, coords.z)
            PlaceObjectOnGroundProperly(PLANT)
            SetEntityHeading(PLANT, heading)

            if IsControlJustReleased(0, 38) then
                clearPlacement()
                return vec4(coords.x, coords.y, coords.z, heading)
            end
            
            if IsControlJustReleased(0, 47) then
                clearPlacement()
                return false
            end

        end
        Wait(0)
    end
end

local function addPlant(plantId, plantData)
    plants[plantId] = {
        entity = nil,
        zone = nil,
        data = plantData.data,
        uuid = plantData.uuid,
        stage = plantData.stage,
        type = plantData.type,
    }

    plants[plantId].zone = lib.zones.sphere({
        coords = plantData.data.coords,
        radius = 20.0,
        debug = false,
        onEnter = onEnter,
        onExit = onExit,

        -- plant data
        plantId = plantId,
        uuid = plantData.uuid,
        plantStage = plantData.stage,
        plantType = plantData.type,
        plant = plantData.data,
    })
end

local function removePlant(plantId, stage)
    if not plants[plantId] then return end
    if DoesEntityExist(plants[plantId].entity) then
        DeleteEntity(plants[plantId].entity)
    end
    plants[plantId].zone:remove()
    plants[plantId] = nil
end

local function requestPlants()
    local newPlants = lib.callback.await('plants:requestPlants')

    for plantId, plantData in pairs(newPlants) do
        addPlant(plantId, plantData)
    end
end

-- events

RegisterNetEvent('plants:addPlant', function(plantId, plantData)
    addPlant(plantId, plantData)
end)

RegisterNetEvent('plants:removePlant', function(plantId)
    removePlant(plantId)
end)

RegisterNetEvent('plants:updatePlant', function(plantId, plantData)
    if not plants[plantId] then return end
    removePlant(plantId)
    addPlant(plantId, plantData)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    requestPlants()
end)

RegisterNetEvent('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    Wait(1000)
    requestPlants()
end)

RegisterNetEvent('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for plantId, plantData in pairs(plants) do
        if DoesEntityExist(plants[plantId].entity) then
            DeleteEntity(plants[plantId].entity)
        end
    end
end)

-- callbacks

lib.callback.register('plant:plant', function(plantType)
    if IN_PROGRESS or PLACING then return false end

    local model = config[plantType][1].model
    local coords = placePlant(model)

    if coords then
        IN_PROGRESS = true
        if lib.progressBar({
            label = "Planting",
            duration = 5000,
            useWhileDead = false,
            canCancel = true,
            disable = { 
                move = true,
                car = true,
                combat = true,
                sprint = true,
            },
            anim = {
                scenario = 'WORLD_HUMAN_GARDENER_PLANT',
            },
        }) then
            IN_PROGRESS = false
            return coords
        else
            IN_PROGRESS = false
            return false
        end
    else
        IN_PROGRESS = false
        return false
    end
end)

lib.callback.register('plant:harvest', function()
    if IN_PROGRESS or PLACING then return false end

    IN_PROGRESS = true
    if lib.progressBar({
        label = "Harvesting",
        duration = 5000,
        useWhileDead = false,
        canCancel = true,
        disable = { 
            move = true,
            car = true,
            combat = true,
            sprint = true,
        },
        anim = {
            scenario = 'WORLD_HUMAN_GARDENER_PLANT',
        },
    }) then
        IN_PROGRESS = false
        return true
    else
        IN_PROGRESS = false
        return false
    end
end)

lib.callback.register('plant:destroy', function()
    if IN_PROGRESS or PLACING then return false end

    IN_PROGRESS = true
    if lib.progressBar({
        label = "Destroying",
        duration = 15000,
        useWhileDead = false,
        canCancel = true,
        disable = { 
            move = true,
            car = true,
            combat = true,
            sprint = true,
        },
        anim = {
            scenario = 'PROP_HUMAN_BUM_BIN',
        },
    }) then
        IN_PROGRESS = false
        return true
    else
        IN_PROGRESS = false
        return false
    end
end)


-- threads