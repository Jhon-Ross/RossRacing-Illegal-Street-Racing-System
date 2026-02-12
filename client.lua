local currentRace = nil
local raceBlips = {}
local explosionTimer = 0
local isExplosionActive = false
local isWaitingLobby = false
local lobbyTimeLeft = 0

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
            AddTextComponentString(circuit.name)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Register Target
Citizen.CreateThread(function()
    if Config.UseTarget then
        Citizen.Wait(1000)
        if GetResourceState(Config.TargetResource) == "started" then
            exports[Config.TargetResource]:AddTargetModel({ GetHashKey(Config.NPC.Model) }, {
                options = {
                    {
                        event = "shops:Corridas",
                        label = "CORRIDAS",
                        tunnel = "client"
                    }
                },
                Distance = 2.5
            })
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
                SetEntityAsMissionEntity(ped, true, true)
                SetEntityHeading(ped, npcConfig.Coords.w)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedDefaultComponentVariation(ped)
                
                RequestAnimDict(npcConfig.AnimDict)
                while not HasAnimDictLoaded(npcConfig.AnimDict) do Wait(1) end
                TaskPlayAnim(ped, npcConfig.AnimDict, npcConfig.AnimName, 8.0, 0.0, -1, 1, 0, 0, 0, 0)
            end

            if dist < 3.0 and not Config.UseTarget then
                sleep = 0
                DrawText3D(npcConfig.Coords.x, npcConfig.Coords.y, npcConfig.Coords.z + 2.0, string.format(Config.Lang['buy_ticket_help'], Config.TicketPrice))
                if IsControlJustPressed(0, 38) then -- E
                    TriggerEvent('shops:Corridas')
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

        if not currentRace and not isWaitingLobby then
            for name, circuit in pairs(Circuitos) do
                local dist = #(plyCoords - vector3(circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z))
                if dist < 10.0 then
                    sleep = 0
                    DrawMarker(4, circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z + 1.5, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 2.0, 255, 255, 255, 255, true, true, 2, false, false, false, false)
                    
                    if dist < 3.0 then
                        if IsPedInAnyVehicle(plyPed, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(plyPed, false), -1) == plyPed then
                            DrawText3D(circuit.startCoords.x, circuit.startCoords.y, circuit.startCoords.z + 1.0, Config.Lang['start_race_help'] .. "\n~b~[G] Ranking")
                            if IsControlJustPressed(0, 38) then -- E
                                TriggerServerEvent('rossracing:requestStart', name)
                            end
                            if IsControlJustPressed(0, 47) then -- G
                                TriggerServerEvent('rossracing:getRankingData', name)
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
        -- Config.ShowNotification(string.format(Config.Lang['race_starting'], i))
        PlaySoundFrontend(-1, "3_2_1", "HUD_MINI_GAME_SOUNDSET", true)
        
        -- Cores dinâmicas
        local color = {r = 255, g = 0, b = 0} -- 3 Vermelho
        if i == 2 then color = {r = 255, g = 165, 0} end -- 2 Laranja
        if i == 1 then color = {r = 255, g = 255, 0} end -- 1 Amarelo

        local timer = GetGameTimer()
        while GetGameTimer() - timer < 1000 do
            Citizen.Wait(0)
            DrawCenterText(tostring(i), color, 3.5) -- Texto Gigante
        end
    end

    -- GO!
    local timer = GetGameTimer()
    PlaySoundFrontend(-1, "GO", "HUD_MINI_GAME_SOUNDSET", true)
    while GetGameTimer() - timer < 1500 do
        Citizen.Wait(0)
        DrawCenterText("GO!", {r = 0, g = 255, b = 0}, 4.0) -- Verde Gigante
        Draw2DText(0.5, 0.8, "~g~SIGA OS CHECKPOINTS!", 0.7)
    end
    
    -- Config.ShowNotification(Config.TriggerClientEvent('rossracing:notify', src, string.format(Config.Lang['lobby_created'], Config.LobbyDuration))ang['race_started'])
    FreezeEntityPosition(veh, false)
    
    StartRaceLogic()
end)

RegisterNetEvent('rossracing:openRanking')
AddEventHandler('rossracing:openRanking', function(rankingData, circuitName)
    local msg = "~y~🏆 RANKING: " .. circuitName .. "\n"
    if not rankingData or #rankingData == 0 then
        msg = msg .. "~w~Nenhum registro encontrado."
    else
        for i, row in ipairs(rankingData) do
            msg = msg .. "~w~" .. i .. ". ~b~" .. row.name .. " ~w~- ~g~" .. row.time .. "s\n"
        end
    end
    
    -- Exibir por 10 segundos
    Citizen.CreateThread(function()
        local timer = GetGameTimer()
        while GetGameTimer() - timer < 10000 do
            Citizen.Wait(0)
            Draw2DText(0.5, 0.3, msg, 0.5)
        end
    end)
end)

RegisterNetEvent('rossracing:updateLobby')
AddEventHandler('rossracing:updateLobby', function(timeLeft)
    isWaitingLobby = true
    lobbyTimeLeft = timeLeft
    
    -- Iniciar thread de exibição se for a primeira vez
    if timeLeft > 0 then
        Citizen.CreateThread(function()
            while isWaitingLobby and lobbyTimeLeft > 0 do
                Citizen.Wait(0)
                -- Contador simples no topo (0.5, 0.15), amarelo, escala 0.8
                Draw2DText(0.5, 0.15, "~y~" .. lobbyTimeLeft, 0.8)
            end
        end)
    else
        isWaitingLobby = false
    end
end)

function StartRaceLogic()
    isWaitingLobby = false -- Garante que saia do modo espera
    Citizen.CreateThread(function()
        local nextCheckpoint = 1
        local raceData = currentRace.data
        local checkpoints = raceData.checkpoints
        
        CreateRaceBlips(checkpoints)
        SetBlipRoute(raceBlips[1], true)

        while currentRace do
            Citizen.Wait(0)
            if not currentRace then break end -- Segurança extra
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
                            -- Config.ShowNotification(string.format(Config.Lang['leave_vehicle_warning'], explosionTimer))
                            
                            local timer = GetGameTimer()
                            while GetGameTimer() - timer < 1000 and isExplosionActive do
                                Citizen.Wait(0)
                                -- Efeito de Piscar
                                if GetGameTimer() % 500 < 250 then
                                    DrawCenterText("VOLTE PARA O VEÍCULO: " .. explosionTimer, {r = 255, g = 0, b = 0}, 2.0)
                                end
                            end

                            explosionTimer = explosionTimer - 1
                        end
                        if isExplosionActive and explosionTimer <= 0 then
                            if currentRace and currentRace.vehicle then
                                AddExplosion(GetEntityCoords(currentRace.vehicle), 2, 1.0, true, false, 1.0)
                                if not IsPedInVehicle(PlayerPedId(), currentRace.vehicle, false) then
                                    -- Se player não está dentro, carro explode e ele perde
                                    TriggerServerEvent('rossracing:failRace', currentRace.id, "Abandonou veículo")
                                else
                                    -- Se voltou a tempo, nada acontece (mas aqui a logica é se timer zerar EXPLODE)
                                    -- Se timer zerou e ele esta dentro, ele morre com a explosão
                                    SetEntityHealth(plyPed, 0)
                                end
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
                    -- Config.ShowNotification(string.format(Config.Lang['race_finished'], timeElapsed))
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
                Config.ShowNotification("SAIA DO VEÍCULO! EXPLOSÃO EM 5 SEGUNDOS!")
                
                -- Tempo extra para fugir
                local failTimer = 5
                local blink = true
                while failTimer > 0 do
                    local timer = GetGameTimer()
                    while GetGameTimer() - timer < 1000 do
                        Citizen.Wait(0)
                        
                        -- Efeito de Piscar
                        if GetGameTimer() % 500 < 250 then
                            DrawCenterText("PERIGO: " .. failTimer, {r = 255, g = 0, b = 0}, 3.0)
                        end
                    end
                    failTimer = failTimer - 1
                end

                -- Tempo acabou: Explodir
                if currentRace and currentRace.vehicle then
                    AddExplosion(GetEntityCoords(currentRace.vehicle), 2, 1.0, true, false, 1.0)
                    
                    -- Se player ainda estiver dentro, morre
                    if IsPedInVehicle(plyPed, currentRace.vehicle, false) then
                        SetEntityHealth(plyPed, 0)
                    end
                end

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

-- Notificação Visual (Substitui antiga notificação)
RegisterNetEvent('rossracing:notify')
AddEventHandler('rossracing:notify', function(msg)
    -- Config.ShowNotification(msg) -- Antigo removido
    
    Citizen.CreateThread(function()
        local timer = GetGameTimer()
        local displayTime = 4000 -- 4 segundos
        
        -- Som de notificação suave
        PlaySoundFrontend(-1, "INFO", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

        while GetGameTimer() - timer < displayTime do
            Citizen.Wait(0)
            DrawCenterText(msg, {r = 255, g = 255, b = 255}, 1.5)
        end
    end)
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
function Draw2DText(x, y, text, scale, color)
    local r, g, b = 255, 255, 255
    if color then r, g, b = color.r, color.g, color.b end

    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Função para desenhar texto centralizado gigante (Estilo HUD)
function DrawCenterText(text, color, scale)
    SetTextFont(7) -- Fonte estilo Digital/Racing
    SetTextScale(scale, scale)
    SetTextColour(color.r, color.g, color.b, 255)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.5, 0.4)
end

-- Evento Visual de Resultado (Vitória)
RegisterNetEvent('rossracing:showResult')
AddEventHandler('rossracing:showResult', function(data)
    Citizen.CreateThread(function()
        local timer = GetGameTimer()
        local displayTime = 8000 -- 8 segundos
        
        PlaySoundFrontend(-1, "Winner", "DLC_Fairground_Hub_Sounds", true)
        
        while GetGameTimer() - timer < displayTime do
            Citizen.Wait(0)
            
            -- Título Principal
            if data.isWinner then
                -- Pisca Dourado/Amarelo
                if GetGameTimer() % 500 < 250 then
                    DrawCenterText("VENCEDOR!", {r = 255, g = 215, 0}, 3.0)
                else
                    DrawCenterText("VENCEDOR!", {r = 255, g = 255, 0}, 3.0)
                end
                
                -- Nome do Player
                Draw2DText(0.5, 0.55, "~w~Parabéns ~b~" .. data.playerName, 0.6)
            else
                DrawCenterText("CORRIDA FINALIZADA", {r = 0, g = 255, 0}, 2.5)
            end

            -- Detalhes (Tempo e Prêmio)
            Draw2DText(0.5, 0.65, "~y~TEMPO:~w~ " .. data.time .. "s", 0.7)
            Draw2DText(0.5, 0.70, "~g~PRÊMIO:~w~ $" .. data.reward, 0.7)
        end

        -- Mostrar Novo Recorde APÓS a tela de resultado
        if data.isNewRecord then
            local recordTimer = GetGameTimer()
            local recordDisplayTime = 5000 -- 5 segundos
            
            PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)

            while GetGameTimer() - recordTimer < recordDisplayTime do
                Citizen.Wait(0)
                -- Pisca Verde/Branco
                if GetGameTimer() % 500 < 250 then
                    DrawCenterText("NOVO RECORDE!", {r = 0, g = 255, 0}, 2.5)
                else
                    DrawCenterText("NOVO RECORDE!", {r = 255, g = 255, 255}, 2.5)
                end
                
                Draw2DText(0.5, 0.60, "~w~Você superou seu tempo anterior!", 0.6)
                Draw2DText(0.5, 0.65, "~y~NOVO TEMPO:~w~ " .. data.time .. "s", 0.7)
            end
        end
    end)
end)
