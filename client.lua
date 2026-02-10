local currentRace = nil
local raceBlips = {}
local explosionTimer = 0
local isExplosionActive = false

-- Thread para Criar Blips no Mapa (Circuitos)
Citizen.CreateThread(function()
    if Config.Blip.Enabled then
        for name, circuit in pairs(Circuitos) do
            local blip = AddBlipForCoord(circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z)
            SetBlipSprite(blip, Config.Blip.Sprite)
            SetBlipColour(blip, Config.Blip.Color)
            SetBlipScale(blip, Config.Blip.Scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Blip.Name .. " - " .. circuit.name)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Thread NPC Manager
Citizen.CreateThread(function()
    local npcConfig = Config.NPC
    local ped = nil

    while true do
        local sleep = 1000
        local plyPed = PlayerPedId()
        local plyCoords = GetEntityCoords(plyPed)
        local dist = #(plyCoords - vector3(npcConfig.Coords.x, npcConfig.Coords.y, npcConfig.Coords.z))

        if dist < 50.0 then
            if not DoesEntityExist(ped) then
                RequestModel(GetHashKey(npcConfig.Model))
                while not HasModelLoaded(GetHashKey(npcConfig.Model)) do
                    Wait(1)
                end

                ped = CreatePed(4, GetHashKey(npcConfig.Model), npcConfig.Coords.x, npcConfig.Coords.y, npcConfig.Coords.z, npcConfig.Coords.w, false, true)
                SetEntityHeading(ped, npcConfig.Coords.w)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedDefaultComponentVariation(ped)
                
                RequestAnimDict(npcConfig.AnimDict)
                while not HasAnimDictLoaded(npcConfig.AnimDict) do Wait(1) end
                TaskPlayAnim(ped, npcConfig.AnimDict, npcConfig.AnimName, 8.0, 0.0, -1, 1, 0, 0, 0, 0)
            end

            if dist < 3.0 then
                sleep = 0
                DrawText3D(npcConfig.Coords.x, npcConfig.Coords.y, npcConfig.Coords.z + 2.0, string.format(Config.Lang['buy_ticket_help'], Config.TicketPrice))
                if IsControlJustPressed(0, 38) then -- E
                    TriggerServerEvent('rossracing:buyTicket')
                end
            end
        else
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
                ped = nil
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- Thread Start Marker
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local plyPed = PlayerPedId()
        local plyCoords = GetEntityCoords(plyPed)

        if not currentRace then
            for name, circuit in pairs(Circuitos) do
                local dist = #(plyCoords - vector3(circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z))
                if dist < 10.0 then
                    sleep = 0
                    DrawMarker(1, circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 1.0, 255, 0, 0, 100, false, true, 2, false, false, false, false)
                    
                    if dist < 3.0 then
                        if IsPedInAnyVehicle(plyPed, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(plyPed, false), -1) == plyPed then
                            DrawText3D(circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z + 1.0, Config.Lang['start_race_help'])
                            if IsControlJustPressed(0, 38) then
                                TriggerServerEvent('rossracing:requestStart', name)
                            end
                        else
                            DrawText3D(circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z + 1.0, Config.Lang['wrong_vehicle'])
                        end
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- Evento Start Race Countdown
RegisterNetEvent('rossracing:startCountdown')
AddEventHandler('rossracing:startCountdown', function(seconds, circuitData, raceId)
    local plyPed = PlayerPedId()
    local veh = GetVehiclePedIsIn(plyPed, false)
    
    if not veh then return end

    -- Posicionar carro
    SetEntityCoords(veh, circuitData.spawnCoords.x, circuitData.spawnCoords.y, circuitData.spawnCoords.z)
    SetEntityHeading(veh, circuitData.spawnCoords.w)
    FreezeEntityPosition(veh, true)

    currentRace = {
        id = raceId,
        data = circuitData,
        checkpointIndex = 1,
        startTime = GetGameTimer(),
        maxTime = circuitData.maxTime * 1000,
        vehicle = veh
    }

    -- Contagem
    for i = seconds, 1, -1 do
        Config.ShowNotification(string.format(Config.Lang['race_starting'], i))
        PlaySoundFrontend(-1, "3_2_1", "HUD_MINI_GAME_SOUNDSET", true)
        Citizen.Wait(1000)
    end

    Config.ShowNotification(Config.Lang['race_started'])
    PlaySoundFrontend(-1, "GO", "HUD_MINI_GAME_SOUNDSET", true)
    FreezeEntityPosition(veh, false)
    
    StartRaceLogic()
end)

function StartRaceLogic()
    Citizen.CreateThread(function()
        local nextCheckpoint = 1
        local raceData = currentRace.data
        local checkpoints = raceData.checkpoints
        
        CreateRaceBlips(checkpoints)
        SetBlipRoute(raceBlips[1], true)

        while currentRace do
            Citizen.Wait(0)
            local plyPed = PlayerPedId()
            local plyCoords = GetEntityCoords(plyPed)
            local veh = GetVehiclePedIsIn(plyPed, false)

            -- Verificar Explosão (Sair do veículo)
            if not IsPedInVehicle(plyPed, currentRace.vehicle, false) then
                if not isExplosionActive then
                    isExplosionActive = true
                    explosionTimer = Config.ExplosionTimer
                    Citizen.CreateThread(function()
                        while isExplosionActive and explosionTimer > 0 do
                            Config.ShowNotification(string.format(Config.Lang['leave_vehicle_warning'], explosionTimer))
                            Citizen.Wait(1000)
                            explosionTimer = explosionTimer - 1
                        end
                        if isExplosionActive and explosionTimer <= 0 then
                            AddExplosion(GetEntityCoords(currentRace.vehicle), 2, 1.0, true, false, 1.0)
                            if not IsPedInVehicle(PlayerPedId(), currentRace.vehicle, false) then
                                -- Se player não está dentro, carro explode e ele perde
                                TriggerServerEvent('rossracing:failRace', currentRace.id, "Abandonou veículo")
                            else
                                -- Se voltou a tempo, nada acontece (mas aqui a logica é se timer zerar EXPLODE)
                                -- Se timer zerou e ele esta dentro, ele morre com a explosão
                                SetEntityHealth(plyPed, 0)
                            end
                            EndRace()
                        end
                    end)
                end
            else
                if isExplosionActive then
                    isExplosionActive = false
                    -- Cancelou explosão voltando pro carro
                end
            end

            -- Verificar Checkpoints
            local dist = #(plyCoords - checkpoints[nextCheckpoint].coords)
            
            -- Desenhar Marker do checkpoint atual
            DrawMarker(1, checkpoints[nextCheckpoint].coords.x, checkpoints[nextCheckpoint].coords.y, checkpoints[nextCheckpoint].coords.z - 1.0, 0, 0, 0, 0, 0, 0, 5.0, 5.0, 2.0, 255, 255, 0, 100, false, false, 2, false, false, false, false)

            if dist < 5.0 then
                PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)
                RemoveBlip(raceBlips[nextCheckpoint])
                nextCheckpoint = nextCheckpoint + 1

                if nextCheckpoint > #checkpoints then
                    -- Venceu
                    local timeElapsed = (GetGameTimer() - currentRace.startTime) / 1000
                    Config.ShowNotification(string.format(Config.Lang['race_finished'], timeElapsed))
                    TriggerServerEvent('rossracing:finishRace', currentRace.id, timeElapsed)
                    EndRace()
                    break
                else
                    SetBlipRoute(raceBlips[nextCheckpoint], true)
                end
            end

            -- Verificar Tempo Limite
            local timeElapsed = GetGameTimer() - currentRace.startTime
            local timeRemaining = math.ceil((currentRace.maxTime - timeElapsed) / 1000)
            if timeRemaining < 0 then timeRemaining = 0 end
            
            -- Desenhar Timer na Tela
            Draw2DText(0.5, 0.9, "~y~TEMPO RESTANTE:~w~ " .. timeRemaining .. "s", 0.6)

            if (GetGameTimer() - currentRace.startTime) > currentRace.maxTime then
                Config.ShowNotification(Config.Lang['race_failed'])
                -- Tempo acabou: Explodir
                AddExplosion(GetEntityCoords(veh), 2, 1.0, true, false, 1.0)
                SetEntityHealth(plyPed, 0)
                TriggerServerEvent('rossracing:failRace', currentRace.id, "Tempo esgotado")
                EndRace()
            end
        end
    end)
end

function CreateRaceBlips(checkpoints)
    for i, cp in ipairs(checkpoints) do
        local blip = AddBlipForCoord(cp.coords.x, cp.coords.y, cp.coords.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Checkpoint " .. i)
        EndTextCommandSetBlipName(blip)
        table.insert(raceBlips, blip)
    end
end

function EndRace()
    currentRace = nil
    isExplosionActive = false
    for _, blip in pairs(raceBlips) do
        RemoveBlip(blip)
    end
    raceBlips = {}
end

-- Notificação
RegisterNetEvent('rossracing:notify')
AddEventHandler('rossracing:notify', function(msg)
    Config.ShowNotification(msg)
end)

-- Helper Text 3D
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Helper Text 2D (Novo)
function Draw2DText(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(x, y)
end
