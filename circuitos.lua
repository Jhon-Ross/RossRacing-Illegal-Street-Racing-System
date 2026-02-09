Circuitos = {}

-- Exemplo de Circuito
-- Você pode adicionar quantos quiser seguindo o modelo.

Circuitos['sample_race'] = {
    name = "Corrida do Porto",
    maxTime = 120, -- Tempo máximo em segundos para completar
    startCoords = vector4(189.95, -3024.16, 5.67, 268.0), -- Onde o player deve estar para iniciar (x,y,z,h)
    spawnCoords = vector4(189.95, -3024.16, 5.67, 268.0), -- Onde o carro será teleportado/posicionado ao iniciar
    checkpoints = {
        { coords = vector3(143.23, -3059.97, 5.9), type = 1 }, -- Checkpoint normal
        { coords = vector3(28.53, -2975.38, 5.82), type = 1 },
        { coords = vector3(-154.67, -2930.64, 5.95), type = 1 },
        { coords = vector3(-342.14, -2837.76, 5.76), type = 1 },
        -- Adicione mais coordenadas...
        { coords = vector3(-181.99, -2534.82, 6.0), type = 1 }, -- Último checkpoint
    }
}
