Circuitos = {}

-- Exemplo de Circuito
-- Você pode adicionar quantos quiser seguindo o modelo.

Circuitos['sample_race'] = {
    name = "Corrida do Porto",
    reward = 5000, -- Valor do pagamento para esta corrida
    maxTime = 120, -- Tempo máximo em segundos para completar
    startCoords = vector4(189.68, -3031.91, 5.81, 64.71), -- Onde o player deve estar para iniciar (x,y,z,h)
    spawnCoords = vector4(189.68, -3031.91, 5.81, 64.71), -- Onde o carro será teleportado/posicionado ao iniciar
    cooldown = Config.CircuitCooldown,
    gridPositions = {
        -- Largada em dupla baseada em P1: sideSpacing total ~8m, rowSpacing ~10m, todos com h=0.82
        vector4(188.29, -3035.39, 5.58, 0.82), -- P1
        vector4(196.29, -3035.28, 5.58, 0.82), -- P2
        vector4(188.43, -3045.39, 5.58, 0.82), -- P3
        vector4(196.43, -3045.27, 5.58, 0.82), -- P4
        vector4(188.58, -3055.39, 5.58, 0.82), -- P5
        vector4(196.58, -3055.27, 5.58, 0.82), -- P6
        vector4(188.72, -3065.39, 5.58, 0.82), -- P7
        vector4(196.72, -3065.27, 5.58, 0.82), -- P8
        vector4(188.86, -3075.39, 5.58, 0.82), -- P9
        vector4(196.86, -3075.27, 5.58, 0.82)  -- P10
    },
    checkpoints = {
        { coords = vector3(182.15, -2983.26, 5.9), type = 1 }, -- Checkpoint normal
        { coords = vector3(165.84, -2789.97, 6.0), type = 1 },
        { coords = vector3(341.52, -2664.83, 20.32), type = 1 },
        { coords = vector3(1261.88, -2564.51, 42.71), type = 1 },
        -- Adicione mais coordenadas...
        { coords = vector3(1607.27, -2389.56, 91.34), type = 1 }, -- Último checkpoint
    }
}
