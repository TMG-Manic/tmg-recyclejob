local TMGCore = exports['tmg-core']:GetCoreObject()

local Recieve = {
    {item = 'metalscrap', min = 1, max = 5},
    {item = 'plastic',    min = 1, max = 5},
    {item = 'copper',     min = 1, max = 5},
    {item = 'rubber',     min = 1, max = 5},
    {item = 'iron',       min = 1, max = 5},
    {item = 'aluminum',   min = 1, max = 5},
    {item = 'steel',      min = 1, max = 5},
    {item = 'glass',      min = 1, max = 5},
}

local luckyItem = 'cryptostick'
local maxRecieved = 5 
local LuckyItemChance = 20 

local uhohs = {} 
local Sales = {} 
local Stock = {} 

if Config.SellMaterials then 
    for item, _ in pairs(Config.Prices or {}) do
        Sales[item] = Config.Prices[item] or 2 
    end
end



local Stock = {}

local function InitializeGlobalStock()
    if not Config.LimitedMaterials then return end

    local defaultStock = {
        metalscrap = 3000,
        plastic = 3000,
        copper = 3000,
        rubber = 3000,
        iron = 3000,
        aluminum = 3000,
        steel = 3000,
        glass = 3000,
    }

    Stock = defaultStock 
    
    print("^5[TMG]^7 Economy: Global Material Stock synchronized.")
end

InitializeGlobalStock()



local function exploitBan(id, reason)
    local src = id
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerName = GetPlayerName(src)
    local citizenid = Player.PlayerData.citizenid
    local logReason = "Mainframe Protection [Recycle]: " .. reason

    TMGCore.Functions.Ban(src, logReason, 2147483647, "tmg-recyclejob")

    TriggerEvent('tmg-log:server:CreateLog', 'recyclejob', 'Identity Locked', 'red', 
        string.format('**CID:** %s | **Name:** %s\n**Reason:** %s', citizenid, playerName, logReason), 
        true
    )

    DropPlayer(src, "Mainframe: Your identity has been locked due to behavioral anomalies (Recycle).")
    
    print(string.format("^1[TMG]^7 Security: Identity %s locked for %s.", citizenid, reason))
end


local function isClose(source, loc)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return false end

    local cid = Player.PlayerData.citizenid
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local targetCoords
    if loc == 'turnIn' then
        targetCoords = vector3(dropLocation.x, dropLocation.y, dropLocation.z)
    elseif loc == 'sell' then
        targetCoords = vector3(salesLoc.x, salesLoc.y, salesLoc.z)
    else
        return false
    end

    local distance = #(playerCoords - targetCoords)

    if distance < 10.0 then
        if uhohs[cid] and uhohs[cid] > 0 then uhohs[cid] = uhohs[cid] - 1 end
        return true
    end

    uhohs[cid] = (uhohs[cid] or 0) + 1

    if uhohs[cid] >= 5 then
        exploitBan(src, string.format("Mainframe: Verified Distance Exploit at %s (Dist: %sm)", loc, math.floor(distance)))
    else
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Movement desync detected. Please stay near the workstation.", "error")
    end

    return false
end


TMGCore.Functions.CreateCallback('tmg-recyclejob:server:getPriceList', function(source, cb)
    if Sales and next(Sales) then
        cb(Sales)
    else
        cb({})
    end

    print(string.format("^5[TMG]^7 Market: Terminal %s is viewing the price list.", source))
end)


local function adjustStock(item, change, amount)
    if not Config.LimitedMaterials or not item then return end

    Stock[item] = Stock[item] or 0
    local currentAmount = tonumber(amount) or 0

    if change == 'add' then
        Stock[item] = Stock[item] + currentAmount
        
    elseif change == 'remove' then
        Stock[item] = math.max(0, Stock[item] - currentAmount)
    end

    print(string.format("^5[TMG]^7 Economy: %s Stock updated to %s", item, Stock[item]))
end


local function checkStock(source, item, amount)
    if not Config.LimitedMaterials then return true end

    local currentStock = Stock[item] or 0
    local requestedAmount = tonumber(amount) or 0

    if currentStock >= requestedAmount then
        return true
    else
        local itemLabel = TMGCore.Shared.Items[item] and TMGCore.Shared.Items[item].label or item
        TriggerClientEvent('TMGCore:Notify', source, Lang:t('error.out_of_stock', {item = itemLabel}), 'error')
        
        print(string.format("^5[TMG]^7 Economy: Stock shortage for [%s]. Requested: %s | Available: %s", item, requestedAmount, currentStock))
        return false
    end
end


local function sellMaterials(src, item, amount)
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not item or not Sales[item] then return end

    local requestedAmount = math.floor(math.abs(tonumber(amount) or 0))
    if requestedAmount <= 0 then return end

    local itemData = Player.Functions.GetItemByName(item)
    if not itemData or itemData.amount <= 0 then
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.nothing_to_sell'), 'error')
        return
    end

    local actualAmount = (requestedAmount > itemData.amount) and itemData.amount or requestedAmount
    local totalPrice = Sales[item] * actualAmount

    if Player.Functions.RemoveItem(item, actualAmount) then
        Player.Functions.AddMoney('cash', totalPrice, "recycling-sell")
        
        adjustStock(item, 'add', actualAmount)

        local itemLabel = TMGCore.Shared.Items[item] and TMGCore.Shared.Items[item].label or item
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.sold', {
            amount = actualAmount, 
            item = itemLabel, 
            price = totalPrice
        }), 'success')

        print(string.format("^5[TMG]^7 Economy: %s sold %sx %s for $%s", Player.PlayerData.citizenid, actualAmount, item, totalPrice))
    else
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Transaction failed. Asset desync.", "error")
    end
end


local function getItem(source, item, amount)
    local Player = TMGCore.Functions.GetPlayer(source)
    if not Player or not item then return end

    local requestedAmount = tonumber(amount) or 1
    local itemData = TMGCore.Shared.Items[item]

    if Config.LimitedMaterials and not checkStock(source, item, requestedAmount) then 
        return 
    end

    if Player.Functions.AddItem(item, requestedAmount) then
        TriggerClientEvent('tmg-inventory:client:ItemBox', source, itemData, 'add', requestedAmount)

        if Config.LimitedMaterials then
            adjustStock(item, 'remove', requestedAmount)
        end
        
        print(string.format("^5[TMG]^7 Logistics: %s received %sx %s", Player.PlayerData.citizenid, requestedAmount, item))
    else
        TriggerClientEvent('TMGCore:Notify', source, "TMG: Inventory full. Cannot materialize materials.", "error")
    end
end


RegisterNetEvent('tmg-recyclejob:server:getItem', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or not isClose(src, 'turnIn') then return end

    local rollCount = math.random(1, maxRecieved)
    
    for i = 1, rollCount do
        local lootEntry = Recieve[math.random(1, #Recieve)]
        local amount = math.random(lootEntry.min, lootEntry.max)
        
        getItem(src, lootEntry.item, amount)
    end

    if math.random(1, 100) <= LuckyItemChance then 
        if Player.Functions.AddItem(luckyItem, 1) then
            TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items[luckyItem], 'add', 1)
            print(string.format("^5[TMG]^7 Economy: Lucky Drop [%s] granted to CID %s", luckyItem, Player.PlayerData.citizenid))
        end
    end

    print(string.format("^5[TMG]^7 Logistics: Batch recycle completed for Terminal %s", src))
end)


RegisterNetEvent('tmg-recyclejob:server:sellItem', function(item, amount)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or not Config.SellMaterials then return end

    if not isClose(src, 'sell') then return end

    local sanitizedAmount = math.floor(math.abs(tonumber(amount) or 0))
    if sanitizedAmount <= 0 then return end

    if not Sales[item] then 
        print(string.format("^1[SECURITY ALERT]^7 Terminal %s attempted to sell unlisted item: %s", src, item))
        return 
    end

    sellMaterials(src, item, sanitizedAmount)
    
    print(string.format("^5[TMG]^7 Fiscal: Terminal %s initiated sale of %sx %s", src, sanitizedAmount, item))
end)
