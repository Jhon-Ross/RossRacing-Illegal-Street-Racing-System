Config = {}

-- Integração com Framework (Adapte conforme sua base: ESX, QBCore, VRP, Creative, etc)
Config.Framework = "custom" -- "esx", "qbcore", "vrp", "custom"

-- Configurações Gerais
Config.Debug = false -- Ativar prints de debug
Config.GlobalCooldown = 5 * 60 -- Tempo em segundos (5 minutos) de espera após o fim de uma corrida
Config.ExplosionTimer = 5 -- Tempo em segundos para explodir o carro se sair dele
Config.StartCountdown = 10 -- Contagem regressiva para iniciar a corrida

-- Item Ticket
Config.TicketItem = "race_ticket" -- Nome do item no inventário
Config.TicketPrice = 1000 -- Preço do ticket
Config.TicketPaymentType = "dirty_money" -- Tipo de dinheiro: "cash", "bank", "dirty_money"

-- NPC Vendedor de Ticket
Config.NPC = {
    Model = "a_m_y_business_02", -- Modelo do NPC
    Coords = vector4(190.58, -3052.75, 5.0, 270.0), -- Coordenadas (x, y, z, h)
    AnimDict = "amb@world_human_smoking@male@male_a@base",
    AnimName = "base"
}

-- Recompensas
Config.BaseReward = 2500 -- Recompensa base (sem policiais)
Config.PoliceBonusStep = 2 -- A cada X policiais...
Config.PoliceBonusAmount = 5000 -- ...adiciona Y valor
-- Exemplo: 2 policiais = +5000, 4 policiais = +10000

Config.WinnerBonus = 1000 -- Bônus para o vencedor (menor tempo) se houver mais de 1 corredor

-- Webhook Discord
Config.Webhook = "" -- Coloque sua URL do Webhook aqui
Config.LogEvents = {
    RaceStart = true,
    RaceFinish = true,
    RaceFail = true,
    RaceCancel = true,
    RaceError = true
}

-- Textos / Traduções
Config.Lang = {
    ['need_ticket'] = "Você precisa de um Ticket de Corrida.",
    ['bought_ticket'] = "Você comprou um Ticket de Corrida por $%s.",
    ['no_money'] = "Você não tem dinheiro sujo suficiente.",
    ['race_active'] = "Já existe uma corrida em andamento.",
    ['race_cooldown'] = "As corridas estão em cooldown. Aguarde %s segundos.",
    ['start_race_help'] = "Pressione ~INPUT_CONTEXT~ para iniciar a corrida.",
    ['buy_ticket_help'] = "Pressione ~INPUT_CONTEXT~ para comprar Ticket ($%s).",
    ['race_starting'] = "Corrida iniciando em %s segundos...",
    ['race_started'] = "VALENDO! Siga os checkpoints!",
    ['wrong_vehicle'] = "Você precisa estar em um veículo como motorista.",
    ['leave_vehicle_warning'] = "VOLTE PARA O VEÍCULO! EXPLOSÃO EM %s SEGUNDOS!",
    ['vehicle_exploded'] = "Você abandonou a corrida.",
    ['race_finished'] = "Corrida finalizada! Tempo: %s",
    ['race_failed'] = "Tempo esgotado! Você falhou.",
    ['waiting_players'] = "Aguardando outros jogadores...",
    ['police_alert'] = "Corridas Ilegais reportadas na região!"
}

-- Funções de Bridge (Personalize aqui para sua base)

-- Lado do Servidor: Verificar Dinheiro
Config.ServerCheckMoney = function(source, type, amount)
    -- Exemplo fictício. Substitua pela lógica da sua base.
    -- if type == 'dirty_money' then return user.getDirtyMoney() >= amount end
    return true -- Retornando true para testes
end

-- Lado do Servidor: Remover Dinheiro
Config.ServerRemoveMoney = function(source, type, amount)
    -- user.removeDirtyMoney(amount)
    print("Removeu " .. amount .. " de " .. type .. " do ID " .. source)
end

-- Lado do Servidor: Adicionar Item
Config.ServerAddItem = function(source, item, amount)
    -- user.giveItem(item, amount)
    print("Deu item " .. item .. " x" .. amount .. " para ID " .. source)
end

-- Lado do Servidor: Remover Item
Config.ServerRemoveItem = function(source, item, amount)
    -- user.tryGetItem(item, amount)
    print("Removeu item " .. item .. " x" .. amount .. " de ID " .. source)
    return true
end

-- Lado do Servidor: Verificar Item
Config.ServerHasItem = function(source, item)
    -- return user.getItemCount(item) >= 1
    return true -- Retornando true para testes
end

-- Lado do Servidor: Dar Dinheiro (Recompensa)
Config.ServerGiveMoney = function(source, type, amount)
    -- user.addDirtyMoney(amount)
    print("Pagou recompensa " .. amount .. " (" .. type .. ") para ID " .. source)
end

-- Lado do Servidor: Contar Policiais
Config.GetPoliceCount = function()
    -- Retorne a quantidade de policiais online/em serviço
    -- local players = GetPlayers()
    -- local policeCount = 0
    -- for _, p in pairs(players) do if isPolice(p) then policeCount = policeCount + 1 end end
    -- return policeCount
    return 0
end

-- Lado do Cliente: Notificações
Config.ShowNotification = function(msg)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

-- Lado do Cliente: Alerta Policial
Config.ClientPoliceAlert = function(coords)
    -- Adicione aqui seu sistema de dispatch/alerta policial
    -- Ex: TriggerServerEvent('police:alert', coords)
end
