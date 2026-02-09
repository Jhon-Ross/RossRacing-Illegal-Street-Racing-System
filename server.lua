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

-- Comprar Ticket
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
    
    if activeRace then
        TriggerClientEvent('rossracing:notify', src, Config.Lang['race_active'])
        return
    end

    if raceCooldown > 0 then
        TriggerClientEvent('rossracing:notify', src, string.format(Config.Lang['race_cooldown'], raceCooldown))
        return
    end

    if not Config.ServerHasItem(src, Config.TicketItem) then
        TriggerClientEvent('rossracing:notify', src, Config.Lang['need_ticket'])
        return
    end

    -- Consumir Ticket
    if Config.ServerRemoveItem(src, Config.TicketItem, 1) then
        local raceId = "RACE-" .. os.time() .. "-" .. math.random(100, 999)
        
        activeRace = {
            id = raceId,
            circuit = circuitName,
            status = "starting",
            players = { [src] = { startTime = 0, finishTime = 0 } },
            startTime = os.time() + Config.StartCountdown
        }

        TriggerClientEvent('rossracing:startCountdown', src, Config.StartCountdown, Circuitos[circuitName], raceId)
        
        -- Alerta Policial
        local policeCount = Config.GetPoliceCount()
        if policeCount > 0 then
            -- Lógica de alerta policial pode ser expandida aqui
            -- TriggerClientEvent('rossracing:policeAlert', -1, Circuitos[circuitName].startCoords)
        end

        SendDiscordLog("Corrida Iniciada", 
            "**RaceID:** " .. raceId .. "\n" ..
            "**Circuito:** " .. Circuitos[circuitName].name .. "\n" ..
            "**Player:** ID " .. src .. "\n" ..
            "**Policiais:** " .. policeCount
        )
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
    local reward = Config.BaseReward
    
    -- Cálculo Bônus Policial
    if policeCount >= 2 then
        local bonusMultiplier = math.floor(policeCount / Config.PoliceBonusStep)
        reward = reward + (bonusMultiplier * Config.PoliceBonusAmount)
    end

    -- Bônus de Vencedor (Simplificado para Single Player por enquanto, mas preparado para multi)
    -- Se fosse multiplayer, checaria se é o menor tempo
    
    Config.ServerGiveMoney(src, "dirty_money", reward)
    
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
