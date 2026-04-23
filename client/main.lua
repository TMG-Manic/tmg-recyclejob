local TMGCore = exports['tmg-core']:GetCoreObject()
local carryPackage = nil
local packageCoords = nil
local onDuty = false
local isBusy = false
local inZone = {
    ['pickupTarget'] = false,
    ['enterLocation'] = false,
    ['exitLocation'] = false,
    ['dutyLocation'] = false,
    ['targetCrate'] = false,
    ['turnIn'] = false,
    ['sellPed'] = false,
}
local props = {}

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for k, v in pairs(props) do
        if DoesEntityExist(v) then
            DeleteObject(v)
        end
    end
    if carryPackage and DoesEntityExist(carryPackage) then
        DetachEntity(carryPackage, true, true)
        DeleteObject(carryPackage)
    end

    if packageCoords and props[packageCoords] and DoesEntityExist(props[packageCoords]) then
        SetEntityDrawOutline(props[packageCoords], false)
    end

    props = {}
    carryPackage = nil
    packageCoords = nil
end)

RegisterNetEvent('TMGCore:Client:OnPlayerLoaded', function()
    if not Config.UseTarget then
        InitializeInteractionZones()
    end
end)

local function DrawPackageLocationBlip()
    if not Config.DrawPackageLocationBlip then return end

    local targetObj = props[packageCoords]

    if targetObj and DoesEntityExist(targetObj) then
        SetEntityDrawOutline(targetObj, true)
        
        SetEntityDrawOutlineColor(0, 255, 255, 255) 
        
        SetEntityDrawOutlineShader(1) 
    else
        packageCoords = nil
    end
end


local function GetRandomPackage()
    if not Config.PickupLocations or #Config.PickupLocations == 0 then
        return print("^1Mainframe Error: Config.PickupLocations is empty!^7")
    end

    if packageCoords and props[packageCoords] and DoesEntityExist(props[packageCoords]) then
        SetEntityDrawOutline(props[packageCoords], false)
    end

    local newLocation = math.random(1, #Config.PickupLocations)
    
    if newLocation == packageCoords and #Config.PickupLocations > 1 then
        repeat
            newLocation = math.random(1, #Config.PickupLocations)
        until newLocation ~= packageCoords
    end

    packageCoords = newLocation

    DrawPackageLocationBlip()
end

local function PickupPackage()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local animDict = 'anim@heists@box_carry@'
    local model = Config.PickupBoxModel

    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    if not HasAnimDictLoaded(animDict) then return end

    RequestModel(model)
    timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    if not HasModelLoaded(model) then return end

    TaskPlayAnim(ped, animDict, 'idle', 5.0, -1, -1, 50, 0, false, false, false)

    local object = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
    
    if object ~= 0 and DoesEntityExist(object) then
        local boneIndex = GetPedBoneIndex(ped, 57005)
        AttachEntityToEntity(object, ped, boneIndex, 0.05, 0.1, -0.3, 300.0, 250.0, 20.0, true, true, false, true, 1, true)
        
        carryPackage = object
        
        Entity(object).state:set('isPackage', true, true)
    end
end


local function DropPackage()
    local ped = PlayerPedId()
    
    if carryPackage and DoesEntityExist(carryPackage) then
        
        if not NetworkHasControlOfEntity(carryPackage) then
            NetworkRequestControlOfEntity(carryPackage)
        end

        DetachEntity(carryPackage, true, true)
        
        DeleteObject(carryPackage)
    end

    ClearPedTasks(ped)
    
    carryPackage = nil
end

local jobBlip = nil

local function SetLocationBlip()
    if jobBlip and DoesBlipExist(jobBlip) then
        RemoveBlip(jobBlip)
    end

    local loc = Config.OutsideLocation
    
    jobBlip = AddBlipForCoord(loc.x, loc.y, loc.z)
    
    SetBlipSprite(jobBlip, 365)     
    SetBlipColour(jobBlip, 2)       
    SetBlipScale(jobBlip, 0.8)
    SetBlipAsShortRange(jobBlip, true)
    
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Lang:t('text.recycle_center_blip') or 'Recycle Center')
    EndTextCommandSetBlipName(jobBlip)
end

SetLocationBlip()

local function EnterLocation()
    local ped = PlayerPedId()
    local dest = Config.InsideLocation

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(10)
    end

    FreezeEntityPosition(ped, true)
    
    SetEntityCoords(ped, dest.x, dest.y, dest.z + 1.0, 0, 0, 0, false)
    SetEntityHeading(ped, dest.w or 0.0)

    RequestCollisionAtCoord(dest.x, dest.y, dest.z)
    
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(ped) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(500)
end

local function ExitLocation()
    local ped = PlayerPedId()
    local dest = Config.OutsideLocation
    if carryPackage then
        DropPackage()
    end

    onDuty = false
    if packageCoords then
        if props[packageCoords] and DoesEntityExist(props[packageCoords]) then
            SetEntityDrawOutline(props[packageCoords], false)
        end
        packageCoords = nil
    end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(10)
    end

    RequestCollisionAtCoord(dest.x, dest.y, dest.z)
    
    SetEntityCoords(ped, dest.x, dest.y, dest.z, 0, 0, 0, false)
    SetEntityHeading(ped, dest.w or 0.0)
    
    Wait(50)
    PlaceObjectOnGroundProperly(ped)

    DoScreenFadeIn(500)
    
    exports['tmg-core']:HideText()
end


local function toggleDuty()
    if isBusy then return end 

    if onDuty then
        onDuty = false
        TMGCore.Functions.Notify(Lang:t('text.clock_out'), 'success')

        if carryPackage then
            DropPackage()
        end

        if packageCoords and props[packageCoords] then
            if DoesEntityExist(props[packageCoords]) then
                SetEntityDrawOutline(props[packageCoords], false)
            end
        end
        packageCoords = nil
        
        exports['tmg-core']:HideText()
    else
        onDuty = true
        TMGCore.Functions.Notify(Lang:t('text.clock_in'), 'success')
        
        GetRandomPackage()
    end
end

local function pickUp()
    if isBusy or not packageCoords or not props[packageCoords] then return end
    
    local targetObj = props[packageCoords]
    if not DoesEntityExist(targetObj) then return end

    local animDict = 'mp_car_bomb'
    RequestAnimDict(animDict)
    
    isBusy = true

    TMGCore.Functions.Progressbar('pickup_reycle_package', Lang:t('text.picking_up_the_package'), Config.PickupActionDuration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = animDict,
        anim = 'car_bomb_mechanic',
        flags = 16
    }, {}, {}, function() 
        if DoesEntityExist(targetObj) then
            SetEntityDrawOutline(targetObj, false)
        end
        
        PickupPackage()
        
        isBusy = false
        packageCoords = nil
        exports['tmg-core']:HideText()
    end, function() 
        isBusy = false
        TMGCore.Functions.Notify(Lang:t('error.canceled'), 'error')
    end)
end

local function handInPackage()
    if not carryPackage or not DoesEntityExist(carryPackage) then 
        return TMGCore.Functions.Notify("You aren't carrying a package!", "error") 
    end
    
    if isBusy then return end
    isBusy = true

    TMGCore.Functions.Progressbar('deliver_reycle_package', Lang:t('text.unpacking_the_package'), Config.DeliveryActionDuration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'mp_car_bomb',
        anim = 'car_bomb_mechanic',
        flags = 16
    }, {}, {}, function() 
        isBusy = false
        DropPackage() 
        
        TriggerServerEvent('tmg-recyclejob:server:getItem')
        
        Wait(500)
        GetRandomPackage()
    end, function() 
        isBusy = false
        TMGCore.Functions.Notify(Lang:t('error.canceled'), 'error')
    end)
end

local function sellMaterials()
    TMGCore.Functions.TriggerCallback('tmg-recyclejob:server:getPriceList', function(data)
        if data == false then 
            return TMGCore.Functions.Notify(Lang:t('error.too_far_to_sell'), 'error') 
        end

        local menu = {
            {
                header = Lang:t('text.sell_materials_header') or "Recycling Center Sales",
                isMenuHeader = true
            }
        }

        for k, v in pairs(data) do
            if TMGCore.Functions.HasItem(k) then
                local itemLabel = TMGCore.Shared.Items[k].label
                menu[#menu+1] = {
                    header = itemLabel,
                    txt = Lang:t('text.price', {price = v}),
                    icon = "nui://tmg-inventory/html/images/" .. TMGCore.Shared.Items[k].name .. ".png",
                    params = {
                        event = "tmg-recyclejob:client:requestSellAmount",
                        args = {
                            item = k,
                            label = itemLabel
                        }
                    }
                }
            end
        end

        if #menu <= 1 then
            return TMGCore.Functions.Notify(Lang:t('error.nothing_to_sell'), 'error')
        end

        exports['tmg-menu']:openMenu(menu)
    end)
end


local function InitializeInteractionZones()
    if InteractionZonesInitialized then return end
    
    CreateThread(function()
        while not Config.UseTarget do
            local wait = 1000
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            
            if TMGConfig and TMGConfig.Weed and TMGConfig.Weed.Locations then
                for k, zone in pairs(TMGConfig.Weed.Locations) do
                    local dist = #(pCoords - vector3(zone.coords.x, zone.coords.y, zone.coords.z))
                    
                    if dist < 10.0 then
                        wait = 0
                        drawText3Ds(zone.coords.x, zone.coords.y, zone.coords.z, zone.label)
                        
                        if dist < 1.5 and IsControlJustPressed(0, 38) then
                            TriggerEvent('tmg-weed:client:handleZoneInteraction', k)
                        end
                    end
                end
            end
            Wait(wait)
        end
    end)

    InteractionZonesInitialized = true
    print("^5[TMG]^7 Interaction Node: Proximity-based zones energized (Legacy Fallback).")
end

local function Start()
    if sellPed and DoesEntityExist(sellPed) then DeleteEntity(sellPed) end
    
    if Config.SellMaterials then 
        local model = `s_m_m_dockwork_01`
        CreateThread(function()
            RequestModel(model)
            local timeout = 0
            while not HasModelLoaded(model) and timeout < 100 do Wait(10) timeout = timeout + 1 end
            
            local loc = Config.SellPed
            sellPed = CreatePed(4, model, loc.x, loc.y, loc.z, loc.w, false, false)
            FreezeEntityPosition(sellPed, true)
            SetEntityInvincible(sellPed, true)
            SetBlockingOfNonTemporaryEvents(sellPed, true)

            if Config.UseTarget then 
                exports['tmg-target']:AddTargetEntity(sellPed, {
                    options = {{
                        icon = 'fas fa-dollar-sign',
                        label = Lang:t('text.sell_materials'),
                        action = function() sellMaterials() end
                    }},
                    distance = 1.5
                })
            end
        end)
    end

    for k, v in pairs(Config.PickupLocations) do
        local objModel = Config.WarehouseObjects[v.model]
        RequestModel(objModel)
        
        CreateThread(function()
            local timeout = 0
            while not HasModelLoaded(objModel) and timeout < 100 do Wait(10) timeout = timeout + 1 end
            
            if HasModelLoaded(objModel) then
                props[k] = CreateObject(objModel, v.loc.x, v.loc.y, v.loc.z, false, false, false)
                PlaceObjectOnGroundProperly(props[k])
                FreezeEntityPosition(props[k], true)
                SetEntityCollision(props[k], true, true)

                
                if Config.UseTarget then
                    exports['tmg-target']:AddTargetEntity(props[k], {
                        options = {{
                            type = 'client',
                            label = Lang:t('text.get_package'),
                            icon = 'fas fa-box',
                            action = function() if not isBusy then pickUp() end end,
                            canInteract = function() return packageCoords == k and not isBusy end,
                        }},
                        distance = 1.5
                    })
                end
            end
        end)
    end

    if not Config.UseTarget then
        InitializeInteractionZones() 
    end
end

Wait(100)
Start()
