Circuitos = {}

-- Exemplo de Circuito
-- Você pode adicionar quantos quiser seguindo o modelo.

Circuitos['sample_race'] = {
    name = "Corrida do Porto",
    maxTime = 120, -- Tempo máximo em segundos para completar
    startCoords = vector4(189.95, -3024.16, 5.67, 268.0), -- Onde o player deve estar para iniciar (x,y,z,h)
    spawnCoords = vector4(189.95, -3024.16, 5.67, 268.0), -- Onde o carro será teleportado/posicionado ao iniciar
    checkpoints = {
        { coords = vector3(182.15, -2983.26, 5.9), type = 1 }, -- Checkpoint normal
        { coords = vector3(165.84, -2789.97, 6.0), type = 1 },
        { coords = vector3(341.52, -2664.83, 20.32), type = 1 },
        { coords = vector3(1261.88, -2564.51, 42.71), type = 1 },
        -- Adicione mais coordenadas...
        { coords = vector3(1607.27, -2389.56, 91.34), type = 1 }, -- Último checkpoint
    }
}
