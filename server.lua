local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG OVERRIDE (BRIDGE)
-----------------------------------------------------------------------------------------------------------------------------------------

-- Lado do Servidor: Verificar Dinheiro (Apenas para referência, já que a compra é pela loja agora)
Config.ServerCheckMoney = function(source, type, amount)
    local Passport = vRP.Passport(source)
    if not Passport then return false end
    
    if type == "dirty_money" then
        return vRP.PaymentFull(Passport, amount) -- PaymentFull checa tudo, mas para dirty específico seria ItemAmount
    else
        return vRP.PaymentFull(Passport, amount)
    end
end

-- Lado do Servidor: Verificar Item
Config.ServerHasItem = function(source, item)
    local Passport = vRP.Passport(source)
    if not Passport then return false end
    
    return vRP.ItemAmount(Passport, item) >= 1
end

-- Lado do Servidor: Remover Item
Config.ServerRemoveItem = function(source, item, amount)
    local Passport = vRP.Passport(source)
    if not Passport then return false end
    
    return vRP.TakeItem(Passport, item, amount, true)
end

-- Lado do Servidor: Dar Dinheiro (Recompensa)
Config.ServerGiveMoney = function(source, type, amount)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    if type == "dirty_money" then
        vRP.GenerateItem(Passport, "dollars2", amount, true)
    else
        vRP.GenerateItem(Passport, "dollars", amount, true)
    end
end

-- Lado do Servidor: Contar Policiais
Config.GetPoliceCount = function()
    local Total = 0
    local Groups = vRP.Groups()
    for key,Value in pairs(Groups) do
        if Value["Type"] == "Policia" then
            local Service,Amount = vRP.NumPermission(key)
            Total = Total + Amount
        end
    end
    return Total
end

local activeRace = nil
local raceCooldown = 0

-- Loop de Cooldown
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if raceCooldown > 0 then
            raceCooldown = raceCooldown - 1
        end
    end
end)

-- Comprar Ticket (LEGADO: Agora via Loja, mas mantido para referência)
RegisterNetEvent('rossracing:buyTicket')
AddEventHandler('rossracing:buyTicket', function()
    local src = source
    if Config.ServerCheckMoney(src, Config.TicketPaymentType, Config.TicketPrice) then
        Config.ServerRemoveMoney(src, Config.TicketPaymentType, Config.TicketPrice)
        Config.ServerAddItem(src, Config.TicketItem, 1)
        TriggerClientEvent('rossracing:notify', src, string.format(Config.Lang['bought_ticket'], Config.TicketPrice))
        SendDiscordLog("Ticket Comprado", "Player ID " .. src .. " comprou um ticket por $" .. Config.TicketPrice)
    else
        TriggerClientEvent('rossracing:notify', src, Config.Lang['no_money'])
    end
end)

-- Solicitar Início de Corrida
RegisterNetEvent('rossracing:requestStart')
AddEventHandler('rossracing:requestStart', function(circuitName)
    local src = source
    
    if raceCooldown > 0 then
        TriggerClientEvent('rossracing:notify', src, string.format(Config.Lang['race_cooldown'], raceCooldown))
        return
    end

    if not Config.ServerHasItem(src, Config.TicketItem) then
        TriggerClientEvent('rossracing:notify', src, Config.Lang['need_ticket'])
        return
    end

    -- Se já existe corrida ativa
    if activeRace then
        if activeRace.status == "waiting" then
            -- Tentar Entrar no Lobby
            if activeRace.circuit ~= circuitName then
                TriggerClientEvent('rossracing:notify', src, "Já existe um lobby para outra corrida (" .. Circuitos[activeRace.circuit].name .. ").")
                return
            end

            local count = 0
            for _ in pairs(activeRace.players) do count = count + 1 end

            if count >= Config.MaxPlayers then
                TriggerClientEvent('rossracing:notify', src, Config.Lang['race_full'])
                return
            end

            if activeRace.players[src] then
                TriggerClientEvent('rossracing:notify', src, "Você já está no lobby.")
                return
            end

            -- Consumir Ticket e Entrar
            if Config.ServerRemoveItem(src, Config.TicketItem, 1) then
                activeRace.players[src] = { startTime = 0, finishTime = 0 }
                TriggerClientEvent('rossracing:notify', src, Config.Lang['joined_lobby'])
                
                -- Notificar outros
                for pid, _ in pairs(activeRace.players) do
                    if pid ~= src then
                        TriggerClientEvent('rossracing:notify', pid, string.format(Config.Lang['player_joined'], count + 1, Config.MaxPlayers))
                    end
                end
            else
                TriggerClientEvent('rossracing:notify', src, Config.Lang['need_ticket'])
            end
        else
            TriggerClientEvent('rossracing:notify', src, Config.Lang['race_active'])
        end
        return
    end

    -- Criar Novo Lobby
    if Config.ServerRemoveItem(src, Config.TicketItem, 1) then
        local raceId = "RACE-" .. os.time() .. "-" .. math.random(100, 999)
        
        activeRace = {
            id = raceId,
            circuit = circuitName,
            status = "waiting",
            players = { [src] = { startTime = 0, finishTime = 0 } },
            startTime = 0 -- Será definido ao iniciar
        }

        TriggerClientEvent('rossracing:notify', src, string.format(Config.Lang['lobby_created'], Config.LobbyDuration))
        
        -- Iniciar Timer do Lobby
        Citizen.CreateThread(function()
            local timeLeft = Config.LobbyDuration
            while timeLeft > 0 and activeRace and activeRace.id == raceId do
                Citizen.Wait(1000)
                timeLeft = timeLeft - 1
            end

            if activeRace and activeRace.id == raceId and activeRace.status == "waiting" then
                -- Iniciar Corrida
                activeRace.status = "starting"
                activeRace.startTime = os.time() + Config.StartCountdown
                
                local policeCount = Config.GetPoliceCount()

                for pid, _ in pairs(activeRace.players) do
                    TriggerClientEvent('rossracing:startCountdown', pid, Config.StartCountdown, Circuitos[circuitName], raceId)
                end

                SendDiscordLog("Corrida Iniciada", 
                    "**RaceID:** " .. raceId .. "\n" ..
                    "**Circuito:** " .. Circuitos[circuitName].name .. "\n" ..
                    "**Policiais:** " .. policeCount
                )
            end
        end)
    else
        TriggerClientEvent('rossracing:notify', src, Config.Lang['need_ticket'])
    end
end)

-- Finalizar Corrida (Sucesso)
RegisterNetEvent('rossracing:finishRace')
AddEventHandler('rossracing:finishRace', function(raceId, timeElapsed)
    local src = source
    
    if not activeRace or activeRace.id ~= raceId then return end

    local policeCount = Config.GetPoliceCount()
    local circuit = Circuitos[activeRace.circuit]
    local reward = circuit and circuit.reward or Config.BaseReward
    
    -- Cálculo Bônus Policial
    if policeCount >= 2 then
        local bonusMultiplier = math.floor(policeCount / Config.PoliceBonusStep)
        reward = reward + (bonusMultiplier * Config.PoliceBonusAmount)
    end

    -- Registrar Tempo de Chegada
    if activeRace.players[src] then
        activeRace.players[src].finishTime = timeElapsed
    end

    -- Contar Jogadores e Verificar Vencedor
    local playerCount = 0
    local othersFinished = 0
    for pid, pdata in pairs(activeRace.players) do
        playerCount = playerCount + 1
        if pid ~= src and pdata.finishTime and pdata.finishTime > 0 then
            othersFinished = othersFinished + 1
        end
    end

    -- Bônus de Vencedor (Se for o primeiro a chegar e houver mais de 1 jogador)
    local isWinner = false
    if playerCount > 1 and othersFinished == 0 then
        reward = reward + Config.WinnerBonus
        isWinner = true
    end
    
    Config.ServerGiveMoney(src, "dirty_money", reward)

    -- Enviar Resultado Visual (HUD)
    TriggerClientEvent('rossracing:showResult', src, {
        isWinner = isWinner,
        reward = reward,
        time = timeElapsed,
        playerName = GetPlayerName(src)
    })
    
    SendDiscordLog("Corrida Finalizada",  
        "**RaceID:** " .. raceId .. "\n" ..
        "**Vencedor:** ID " .. src .. "\n" ..
        "**Tempo:** " .. timeElapsed .. "s\n" ..
        "**Prêmio:** $" .. reward .. "\n" ..
        "**Policiais:** " .. policeCount
    )

    -- Reset Race
    activeRace = nil
    raceCooldown = Config.GlobalCooldown
end)

-- Falha ou Cancelamento
RegisterNetEvent('rossracing:failRace')
AddEventHandler('rossracing:failRace', function(raceId, reason)
    local src = source
    if not activeRace or activeRace.id ~= raceId then return end

    SendDiscordLog("Corrida Falhou", 
        "**RaceID:** " .. raceId .. "\n" ..
        "**Player:** ID " .. src .. "\n" ..
        "**Motivo:** " .. reason
    )

    activeRace = nil
    raceCooldown = Config.GlobalCooldown
end)

-- Webhook
function SendDiscordLog(title, message)
    if Config.Webhook == "" then return end
    
    local embed = {
        {
            ["color"] = 16711680,
            ["title"] = title,
            ["description"] = message,
            ["footer"] = {
                ["text"] = "RossRacing System • " .. os.date("%d/%m/%Y %H:%M:%S"),
            },
        }
    }

    PerformHttpRequest(Config.Webhook, function(err, text, headers) end, 'POST', json.encode({username = "RossRacing Bot", embeds = embed}), { ['Content-Type'] = 'application/json' })
end
