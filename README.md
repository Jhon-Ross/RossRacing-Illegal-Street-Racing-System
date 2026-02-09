# RossRacing – Illegal Street Racing System

## 📌 Apresentação
**RossRacing – Illegal Street Racing System** é um script completo e exclusivo de corridas ilegais desenvolvido para servidores de GTA RP (FiveM). Com foco em realismo e imersão, o sistema integra economia (dinheiro sujo), risco (explosões e polícia) e competição.

### Destaques do Sistema
*   **Sistema de Tickets:** Acesso restrito via compra de tickets com NPC usando dinheiro sujo.
*   **Corrida Hardcore:** Se o tempo acabar ou você abandonar o veículo, o carro explode.
*   **Integração Policial:** A presença de policiais aumenta a recompensa (Risco x Recompensa).
*   **Cooldown Global:** Evita spam de corridas e valoriza o evento.
*   **Totalmente Configurável:** Coordenadas, preços, tempos, mensagens e integração com qualquer base (ESX, QBCore, vRP, Creative).
*   **Logs no Discord:** Monitoramento completo de todas as corridas, tickets e resultados.

---

## ⚙️ Funcionamento Geral

### 1. Iniciando uma Corrida
Para iniciar uma corrida, o jogador precisa de um **Ticket de Corrida**.
1.  Vá até o NPC (marcado ou escondido, configurável).
2.  Compre o ticket usando **Dinheiro Sujo**.
3.  Vá até o ponto de início da corrida com um veículo.
4.  Pressione **E** para iniciar.

### 2. A Corrida
*   Ao iniciar, uma contagem regressiva começa.
*   Siga os checkpoints amarelos no mapa.
*   **CUIDADO:** Você tem um tempo limite. Se o tempo esgotar, **o carro explode**.
*   **NÃO SAIA DO CARRO:** Se sair do veículo durante a corrida, você tem 5 segundos para voltar, ou **o carro explode**.

### 3. Recompensas e Polícia
*   A recompensa é paga em dinheiro sujo.
*   **Bônus Policial:** Quanto mais policiais em serviço, maior o prêmio.
    *   Ex: Base $2500. Com 2 policiais: +$5000. Com 4 policiais: +$10000.

---

## 🛠️ Documentação Técnica

### Estrutura de Arquivos
*   `client.lua`: Lógica do cliente (NPC, markers, corrida, explosão).
*   `server.lua`: Lógica do servidor (controle de estado, pagamentos, logs).
*   `config.lua`: Todas as configurações e **funções de integração (Bridge)**.
*   `circuitos.lua`: Definição das pistas e coordenadas.

### Configuração (config.lua)
O arquivo `config.lua` é o coração do script. Nele você define:
*   **Framework:** Funções `ServerCheckMoney`, `ServerRemoveMoney`, etc., devem ser adaptadas para sua base (Creative, vRP, ESX, etc).
*   **NPC:** Modelo e coordenadas do vendedor de tickets.
*   **Preços e Tempos:** Valor do ticket, cooldown, tempo de explosão.
*   **Webhook:** Link do webhook do Discord para logs.

### Criando Novos Circuitos (circuitos.lua)
Para adicionar uma nova corrida, edite `circuitos.lua`:
```lua
Circuitos['nome_unico'] = {
    name = "Nome da Pista",
    maxTime = 120, -- Tempo em segundos
    startCoords = vector4(x, y, z, h), -- Onde aperta E
    spawnCoords = vector4(x, y, z, h), -- Onde o carro spawna
    checkpoints = {
        { coords = vector3(x, y, z), type = 1 },
        { coords = vector3(x, y, z), type = 1 },
        -- ...
    }
}
```

### Eventos e Logs
O sistema gera logs detalhados para:
*   Compra de Ticket.
*   Início de Corrida (com ID único).
*   Finalização (com tempo e prêmio).
*   Falha (motivo da explosão/perda).

---

## 🚀 Escalabilidade
O script foi desenhado para ser modular.
*   **Ranking:** O `RaceID` e os tempos salvos permitem fácil implementação de um ranking SQL futuro.
*   **Temporadas:** A estrutura de `Circuitos` permite rotação de pistas.

---

**RossRacing – Illegal Street Racing System**
*Sistema proprietário, modular e escalável para GTA RP.*
