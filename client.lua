local isOnJob = false
local currentMarker = 1
local mower = nil
local textUIStart = false
local textUIEnd = false
local blip = nil
local canEndJob = false

-- Framework Setup
local ESX, QBCore

if Config.Framework == "ESX" then
    ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == "QBCore" then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Blip für Startpunkt
local blips = {
    {title="Rasenmähen", colour=43, id=738, x = -1332.39, y = 33.99, z = 53.57},
}

Citizen.CreateThread(function()
    for _, info in pairs(blips) do
        info.blip = AddBlipForCoord(info.x, info.y, info.z)
        SetBlipSprite(info.blip, info.id)
        SetBlipDisplay(info.blip, 4)
        SetBlipScale(info.blip, 0.7)
        SetBlipColour(info.blip, info.colour)
        SetBlipAsShortRange(info.blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(info.title)
        EndTextCommandSetBlipName(info.blip)
    end
end)

-- Job starten
RegisterNetEvent('gardening:startJob')
AddEventHandler('gardening:startJob', function()
    if not isOnJob then
        isOnJob = true
        canEndJob = false
        currentMarker = 1
        spawnMowerAtLocation()
        
        if Config.Fuelsystem == "legacy" then
            exports['LegacyFuel']:SetFuel(mower, 99.9)
        elseif Config.Fuelsystem == "lcfuel" then
            exports['lc_fuel']:SetFuel(mower, 99.9)
        end

        setNextMarker()
        updateBlipForMarker(Config.Markers[currentMarker])

        Citizen.SetTimeout(3000, function()
            canEndJob = true
        end)
    end
end)

-- Start / End Zone Check
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local playerCoords = GetEntityCoords(PlayerPedId())
        local startDistance = #(playerCoords - Config.StartJobCoords)
        local endDistance = #(playerCoords - Config.JobEndCoords)

        -- Start
        if not isOnJob and startDistance < 2.0 then
            if not textUIStart then
                if Config.Framework == "ESX" then
                    exports['hpngd-textui']:ShowTextUI({ key = 'G', label = 'INTERAGIEREN', description = "Gartenarbeit anfangen" })
                else
                    exports['hpngd-textui']:ShowTextUI({ key = 'E', label = 'INTERAGIEREN', description = "Gartenarbeit anfangen" })
                end
                textUIStart = true
            end
            if IsControlJustPressed(0, 38) then
                TriggerEvent('gardening:startJob')
            end
        elseif textUIStart then
            if Config.Framework == "ESX" then
                exports['hpngd-textui']:HideTextUI()
            else
                exports['hpngd-textui']:HideTextUI()
            end
            textUIStart = false
        end

        -- End
        if isOnJob and canEndJob and endDistance < 2.0 then
            if not textUIEnd then
                if Config.Framework == "ESX" then
                    exports['hpngd-textui']:ShowTextUI({ key = 'E', label = 'INTERAGIEREN', description = "Gartenarbeit beenden" })
                else
                    exports['hpngd-textuiv2']:ShowTextUI({ key = 'E', label = 'INTERAGIEREN', description = "Gartenarbeit beenden" })
                end
                textUIEnd = true
            end
            if IsControlJustPressed(0, 38) then
                finishJob()
            end
        elseif textUIEnd then
            if Config.Framework == "ESX" then
                exports['hpngd-textui']:HideTextUI()
            else
                exports['hpngd-textuiv2']:HideTextUI()
            end
            textUIEnd = false
        end
    end
end)

-- Mäher spawnen
function spawnMowerAtLocation()
    if mower == nil then
        local vehicleModel = GetHashKey(Config.MowerModel)
        RequestModel(vehicleModel)
        while not HasModelLoaded(vehicleModel) do Citizen.Wait(100) end

        local spawnLocation = Config.MowerSpawnLocations[math.random(#Config.MowerSpawnLocations)]
        local x, y, z, heading = table.unpack(spawnLocation)
        mower = CreateVehicle(vehicleModel, x, y, z, heading, true, false)

        TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(mower))
    end
end

-- Marker Blip
function updateBlipForMarker(marker)
    if blip then RemoveBlip(blip) end
    blip = AddBlipForCoord(marker.x, marker.y, marker.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 43)
    SetBlipScale(blip, 0.7)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Rasenmähen")
    EndTextCommandSetBlipName(blip)
end

-- Nächster Marker
function setNextMarker()
    if currentMarker <= #Config.Markers then
        local marker = Config.Markers[currentMarker]
        updateBlipForMarker(marker)
        createMarker(marker)
    else
        currentMarker = 1
        setNextMarker()
    end
end

-- Marker Handling
function createMarker(position)
    local notified = false
    Citizen.CreateThread(function()
        while isOnJob and currentMarker <= #Config.Markers do
            Citizen.Wait(0)
            DrawMarker(1, position.x, position.y, position.z - 0.5,
                0, 0, 0, 0, 0, 0, 3.0, 3.0, 1.0,
                0, 255, 0, 100, false, true, 2)

            local playerCoords = GetEntityCoords(PlayerPedId())
            local playerVehicle = GetVehiclePedIsIn(PlayerPedId(), false)

            if #(playerCoords - position) < 3.0 then
                if playerVehicle == mower then
                    currentMarker = currentMarker + 1
                    setNextMarker()
                    TriggerServerEvent('gardening:payForMarker')
                    break
                elseif not notified then
                    if Config.Framework == "ESX" then
                        ESX.ShowNotification("~y~Du musst das richtige Fahrzeug benutzen!")
                    else
                        QBCore.Functions.Notify("INFORMATION", "Du musst das richtige Fahrzeug benutzen!", 5000)
                    end
                    notified = true
                end
            else
                notified = false
            end
        end
    end)
end

-- Job beenden
function finishJob()
    isOnJob = false
    currentMarker = 1

    if mower then
        DeleteEntity(mower)
        mower = nil
    end

    if textUIEnd then
        if Config.Framework == "ESX" then
            exports['hpngd-textui']:HideTextUI()
        else
            exports['hpngd-textuiv2']:HideTextUI()
        end
        textUIEnd = false
    end

    if blip then
        RemoveBlip(blip)
        blip = nil
    end

    if Config.Framework == "ESX" then
        ESX.ShowNotification("~g~Arbeit erfolgreich beendet")
    else
        QBCore.Functions.Notify("INFORMATION", "Arbeit erfolgreich beendet", 5000)
    end
end
