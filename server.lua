local ESX, QBCore

if Config.Framework == "ESX" then
    ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == "QBCore" then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Server-side logic for handling payments
RegisterServerEvent('gardening:payForMarker')
AddEventHandler('gardening:payForMarker', function()
    local src = source
    local paymentAmount = Config.Rewards.rewardPerMarker

    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.addMoney(paymentAmount)
        end

    elseif Config.Framework == "QBCore" then
        local xPlayer = QBCore.Functions.GetPlayer(src)
        if xPlayer then
            xPlayer.Functions.AddMoney("cash", paymentAmount)
        end
    end
end)
