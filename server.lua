local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- PREPARE QUERIES
-----------------------------------------------------------------------------------------------------------------------------------------
vRP.Prepare("rossracing/insert_ranking","INSERT INTO rossracing_ranking (circuit, user_id, name, vehicle, time) VALUES (@circuit, @user_id, @name, @vehicle, @time) ON DUPLICATE KEY UPDATE time = CASE WHEN @time < time THEN @time ELSE time END, vehicle = CASE WHEN @time < time THEN @vehicle ELSE vehicle END, date = CASE WHEN @time < time THEN CURRENT_TIMESTAMP ELSE date END")
vRP.Prepare("rossracing/get_ranking","SELECT COALESCE(n.nickname, r.name) as name, r.time, r.vehicle FROM rossracing_ranking r LEFT JOIN rossracing_nicknames n ON r.user_id = n.user_id WHERE r.circuit = @circuit ORDER BY r.time ASC LIMIT 10")
vRP.Prepare("rossracing/get_player_best","SELECT time FROM rossracing_ranking WHERE circuit = @circuit AND user_id = @user_id")
vRP.Prepare("rossracing/set_nickname","INSERT INTO rossracing_nicknames (user_id, nickname) VALUES (@user_id, @nickname) ON DUPLICATE KEY UPDATE nickname = @nickname")
vRP.Prepare("rossracing/get_nickname","SELECT nickname FROM rossracing_nicknames WHERE user_id = @user_id")

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
local raceCooldowns = {}

-- Loop de Cooldown por Pista
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for circuit, time in pairs(raceCooldowns) do
            if time > 0 then
                raceCooldowns[circuit] = time - 1
            else
                raceCooldowns[circuit] = nil
            end
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
AddEventHandler('rossracing:requestStart', function(circuitName, nickname)
    local src = source
    local Passport = vRP.Passport(src)
    
    -- Atualizar apelido se fornecido
    if Passport and nickname and nickname ~= "" then
        -- Validação simples (embora o client limite, é bom checar)
        if string.len(nickname) >= 3 and string.len(nickname) <= 20 then
            vRP.Query("rossracing/set_nickname", { user_id = Passport, nickname = nickname })
        end
    end

    if raceCooldowns[circuitName] and raceCooldowns[circuitName] > 0 then
        TriggerClientEvent('rossracing:notify', src, string.format(Config.Lang['race_cooldown'], raceCooldowns[circuitName]))
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
                local timeLeft = 0 -- TODO: Pegar tempo real
                -- Mas como o loop do timer já roda em outra thread, vamos apenas mandar o evento de updateLobby no proximo tick do loop principal
                -- Ou podemos forçar um update imediato se tivermos acesso ao timeLeft (variavel local da outra thread)
                -- Como não temos acesso direto, o cliente receberá o update no próximo segundo.
                
                -- Gambiarra segura: O cliente vai receber o tempo no próximo segundo pelo loop principal.
                -- Mas para garantir feedback imediato, vamos mandar um tempo estimado ou esperar o loop.
                -- Melhor: O loop principal do lobby envia update a cada segundo. O player novo vai receber em <1s.
                
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
        TriggerClientEvent('rossracing:updateLobby', src, Config.LobbyDuration)
        
        -- Iniciar Timer do Lobby
        Citizen.CreateThread(function()
            local timeLeft = Config.LobbyDuration
            while timeLeft > 0 and activeRace and activeRace.id == raceId do
                Citizen.Wait(1000)
                timeLeft = timeLeft - 1
                
                -- Atualizar tempo para todos os jogadores no lobby
                for pid, _ in pairs(activeRace.players) do
                    TriggerClientEvent('rossracing:updateLobby', pid, timeLeft)
                end
            end

            if activeRace and activeRace.id == raceId and activeRace.status == "waiting" then
                -- Iniciar Corrida
                activeRace.status = "starting"
                activeRace.startTime = os.time() + Config.StartCountdown
                
                local policeCount = Config.GetPoliceCount()

                local gridIndex = 1
                for pid, _ in pairs(activeRace.players) do
                    TriggerClientEvent('rossracing:startCountdown', pid, Config.StartCountdown, Circuitos[circuitName], raceId, gridIndex)
                    gridIndex = gridIndex + 1
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

    -- SALVAR RANKING
    local Passport = vRP.Passport(src)
    if Passport then
        local Identity = vRP.Identity(Passport)
        local fullName = Identity["name"] .. " " .. Identity["name2"]
        local vehName = "Veículo" -- TODO: Pegar nome do veículo se possível via client
        
        -- Verificar se tem apelido
        local nicknameData = vRP.Query("rossracing/get_nickname", { user_id = Passport })
        if nicknameData and nicknameData[1] and nicknameData[1].nickname and nicknameData[1].nickname ~= "" then
            fullName = nicknameData[1].nickname
        end

        -- Inserir ou Atualizar Recorde (Query já trata se é melhor tempo)
        vRP.Query("rossracing/insert_ranking", {
            circuit = activeRace.circuit,
            user_id = Passport,
            name = fullName,
            vehicle = vehName,
            time = timeElapsed
        })

        -- Verificar se bateu o recorde pessoal para notificar
        local best = vRP.Query("rossracing/get_player_best", { circuit = activeRace.circuit, user_id = Passport })
        local isNewRecord = false
        if best and best[1] and best[1].time == timeElapsed then
            isNewRecord = true
        end

        -- Enviar Resultado Visual (HUD)
        TriggerClientEvent('rossracing:showResult', src, {
            isWinner = isWinner,
            reward = reward,
            time = timeElapsed,
            playerName = GetPlayerName(src),
            isNewRecord = isNewRecord
        })
    else
        -- Fallback se Passport não encontrado (raro)
        TriggerClientEvent('rossracing:showResult', src, {
            isWinner = isWinner,
            reward = reward,
            time = timeElapsed,
            playerName = GetPlayerName(src),
            isNewRecord = false
        })
    end
    
    SendDiscordLog("Corrida Finalizada",  
        "**RaceID:** " .. raceId .. "\n" ..
        "**Vencedor:** ID " .. src .. "\n" ..
        "**Tempo:** " .. timeElapsed .. "s\n" ..
        "**Prêmio:** $" .. reward .. "\n" ..
        "**Policiais:** " .. policeCount
    )

    -- Reset Race (CORREÇÃO: Só reseta se todos terminaram ou força maior. 
    -- Mantendo original por enquanto mas alertando: isso reseta a corrida pro PRIMEIRO que chegar.
    -- Idealmente, deveria esperar todos. Mas vou manter o comportamento original por ora.)
    local circuitName = activeRace.circuit
    activeRace = nil
    
    local cd = Circuitos[circuitName].cooldown or Config.CircuitCooldown
    raceCooldowns[circuitName] = cd
end)

-- Evento para buscar Ranking
RegisterNetEvent('rossracing:getRankingData')
AddEventHandler('rossracing:getRankingData', function(circuitName)
    local src = source
    local rows = vRP.Query("rossracing/get_ranking", { circuit = circuitName })
    TriggerClientEvent('rossracing:openRanking', src, rows, Circuitos[circuitName].name)
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

    local circuitName = activeRace.circuit
    activeRace = nil
    
    local cd = Circuitos[circuitName].cooldown or Config.CircuitCooldown
    raceCooldowns[circuitName] = cd
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
