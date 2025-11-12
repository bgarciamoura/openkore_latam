# autoRenewBuffs Plugin

## Descrição

Plugin para OpenKore que rastreia automaticamente a posição do líder da party e move o personagem até o líder quando necessário. O plugin oferece dois modos de movimento: baseado em **distância** (vai quando está longe) ou baseado em **buffs** (vai quando buffs expirarem), permitindo automação inteligente para buff bots e suportes.

## Funcionalidades

### ✅ Rastreamento de Party
- Detecta se o personagem está em uma party
- Identifica se o personagem é ou não o líder
- Rastreia a posição do líder da party em tempo real
- Armazena coordenadas (x, y), mapa e distância do líder
- Calcula distância até o líder quando no mesmo mapa
- Suporta líder visível (tela) ou invisível (fora da tela)

### ✅ Movimento Inteligente
- **Vai até o líder quando necessário** (não é follow contínuo)
- Para a uma distância configurável do líder
- Sistema de cooldown entre movimentos (evita ir/voltar repetidamente)
- Respeita ações críticas em andamento (ataque, skill, etc)
- Cancela rotas ao desativar

### ✅ Rastreamento de Buffs
- Monitora buffs ativos: Blessing, Inc Agi, Richmankim, Assassin Cross
- Detecta automaticamente se a party tem Bard/Dancer
- Lógica adaptativa:
  - **Sem Bard/Dancer**: Move quando Blessing OU Inc Agi expirar
  - **Com Bard/Dancer**: Move quando Richmankim/Assassin Cross expirar
- Histórico de buffs para detecção de composição da party
- Três modos de movimento: distância, buff, ou ambos

### ✅ Sistema de Controle
- Intervalo de verificação configurável
- Sistema de comandos completo para controle
- Modo debug para troubleshooting
- Todas as configurações ajustáveis em tempo real

## Instalação

1. O plugin já está na pasta `plugins/autoRenewBuffs/`
2. Adicione as configurações no seu `config.txt` (veja abaixo)
3. Inicie o OpenKore - o plugin será carregado automaticamente

## Configuração

### Configuração Básica (config.txt)

Adicione estas linhas ao seu `config.txt`:

```txt
# ============================================
# Auto Renew Buffs - Configurações
# ============================================

# Configurações Básicas
autoRenewBuffs_enabled 1              # 1 = ativado, 0 = desativado
autoRenewBuffs_checkInterval 2        # Intervalo de verificação (segundos)
autoRenewBuffs_debug 0                # Modo debug: 0 = off, 1 = on

# Configurações de Movimento
autoRenewBuffs_moveTimeout 5          # Timeout máximo para rotas (segundos)
autoRenewBuffs_followEnabled 0        # Ir até o líder: 0 = off, 1 = on
autoRenewBuffs_followDistance 3       # Distância de parada próximo ao líder
autoRenewBuffs_followTriggerDistance 7  # Distância para disparar movimento
autoRenewBuffs_moveCooldown 30        # Cooldown entre movimentos (segundos)

# Configurações de Buffs
autoRenewBuffs_movementMode distance  # Modo: distance, buff, both
autoRenewBuffs_buffCheckInterval 1    # Intervalo de verificação de buffs (segundos)
```

### Tabela de Configurações

| Configuração | Padrão | Range | Descrição |
|--------------|--------|-------|-----------|
| `autoRenewBuffs_enabled` | 1 | 0-1 | Ativa/desativa o plugin |
| `autoRenewBuffs_checkInterval` | 2 | 1-10 | Frequência de verificação da posição do líder |
| `autoRenewBuffs_moveTimeout` | 5 | 3-30 | Tempo máximo para completar uma rota |
| `autoRenewBuffs_followEnabled` | 0 | 0-1 | Ativar movimento automático até o líder |
| `autoRenewBuffs_followDistance` | 3 | 1-10 | Distância onde o bot para próximo ao líder |
| `autoRenewBuffs_followTriggerDistance` | 7 | 3-17 | Distância que dispara o movimento |
| `autoRenewBuffs_moveCooldown` | 30 | 5-120 | Tempo de espera entre movimentos |
| `autoRenewBuffs_movementMode` | distance | distance, buff, both | Modo de movimento (distância, buffs, ou ambos) |
| `autoRenewBuffs_buffCheckInterval` | 1 | 1-5 | Frequência de verificação de buffs |
| `autoRenewBuffs_debug` | 0 | 0-1 | Modo debug (mensagens detalhadas) |

### Exemplos de Configuração por Uso

**Buff Bot (fica bem perto do líder):**
```txt
autoRenewBuffs_followEnabled 1
autoRenewBuffs_followDistance 2
autoRenewBuffs_followTriggerDistance 5
autoRenewBuffs_moveCooldown 20
```

**Support Normal (distância média):**
```txt
autoRenewBuffs_followEnabled 1
autoRenewBuffs_followDistance 3
autoRenewBuffs_followTriggerDistance 7
autoRenewBuffs_moveCooldown 30
```

**Follow Casual (mais espaço):**
```txt
autoRenewBuffs_followEnabled 1
autoRenewBuffs_followDistance 5
autoRenewBuffs_followTriggerDistance 12
autoRenewBuffs_moveCooldown 45
```

**Apenas Rastreamento (sem movimento):**
```txt
autoRenewBuffs_followEnabled 0
autoRenewBuffs_checkInterval 2
```

**Buff Bot - Movimento por Buffs:**
```txt
autoRenewBuffs_followEnabled 1
autoRenewBuffs_movementMode buff
autoRenewBuffs_followDistance 2
autoRenewBuffs_moveCooldown 20
autoRenewBuffs_buffCheckInterval 1
```

**Support Híbrido - Distância + Buffs:**
```txt
autoRenewBuffs_followEnabled 1
autoRenewBuffs_movementMode both
autoRenewBuffs_followDistance 3
autoRenewBuffs_followTriggerDistance 10
autoRenewBuffs_moveCooldown 30
autoRenewBuffs_buffCheckInterval 1
```

## Comandos de Console

### Comando Principal: `arb`

Todos os comandos podem ser executados no console do OpenKore usando o prefixo `arb` (Auto Renew Buffs).

| Comando | Descrição |
|---------|-----------|
| `arb` ou `arb help` | Mostra ajuda com todos os comandos disponíveis |
| `arb on` | Ativa o plugin |
| `arb off` | Desativa o plugin |
| `arb status` | Exibe status completo do plugin e posição do líder |
| `arb debug` | Liga/desliga modo debug |
| `arb follow [on\|off]` | Ativa/desativa movimento até o líder |
| `arb mode <type>` | Define modo de movimento (distance, buff, both) |
| `arb buffstatus` | Mostra status atual dos buffs rastreados |
| `arb resetbuffs` | Reseta histórico de buffs (útil para redetectar party) |
| `arb setmove <segundos>` | Configura timeout de movimento |
| `arb setdist <stop> <trigger>` | Configura distâncias (parada/trigger) |
| `arb setcooldown <segundos>` | Configura cooldown entre movimentos |

**Alias:** Você também pode usar `renewbuffs` no lugar de `arb`

### Exemplos de Uso

```bash
# Básico
arb status              # Ver status atual
arb on                  # Ativar plugin
arb off                 # Desativar plugin
arb debug               # Ativar modo debug

# Follow
arb follow on           # Ativar movimento até líder
arb follow off          # Desativar movimento
arb follow              # Toggle (liga/desliga)

# Modos de Movimento
arb mode distance       # Apenas distância (padrão)
arb mode buff           # Apenas buffs
arb mode both           # Distância E buffs

# Buffs
arb buffstatus          # Ver status dos buffs
arb resetbuffs          # Resetar histórico de buffs

# Configurações em tempo real
arb setdist 3 10        # Para a 3 células, dispara se >10
arb setcooldown 45      # Cooldown de 45 segundos
arb setmove 8           # Timeout de rota de 8 segundos
```

## Output do Comando Status

Quando você executa `arb status`, o plugin mostra:

```
=============== Auto Renew Buffs Status ===============
Plugin: ATIVADO
Intervalo de verificação: 2s
Timeout de movimento: 5s
Modo debug: DESATIVADO
Follow líder: ATIVADO
  Distância de parada: 3 células
  Distância trigger: 7 células
  Cooldown: 30s
  Próximo movimento em: 15s
======================================================
Party: MinhaParty
Membros: 4
Líder: LeaderName
Mapa: prontera
Posição: (150, 200)
Distância: 10 células
Online: SIM
Última atualização: há 2s
======================================================
```

## Como Funciona

### Sistema de Rastreamento

1. **Verificação de Party**
   - A cada X segundos (configurável), verifica se está em uma party
   - Se não estiver em party, aguarda até entrar em uma

2. **Identificação do Líder**
   - Verifica se você é o líder da party
   - Se for o líder, não rastreia (você é o ponto de referência)
   - Se não for o líder, identifica quem é

3. **Rastreamento de Posição**
   - **Método 1**: Se o líder está visível na tela → Coordenadas em tempo real
   - **Método 2**: Se o líder está fora da tela → Aguarda pacote do servidor (5-15s)
   - Calcula a distância até o líder continuamente

### Sistema de Movimento ("Ir e Ficar")

**NÃO é follow contínuo!** O bot vai até o líder e fica lá.

```
Exemplo: followDistance=3, followTriggerDistance=10, cooldown=30s

1. Líder está a 5 células  → Não faz nada (5 < 10)
2. Líder está a 12 células → Vai até líder, para a 3 células
3. Fica parado por 30 segundos (cooldown)
4. Só vai novamente se: líder >10 células E cooldown acabou
```

**Validações de Segurança:**
- ❌ Não move se você é o líder
- ❌ Não move se líder em mapa diferente
- ❌ Não move se coordenadas não disponíveis
- ❌ Não move se líder offline
- ❌ Não move se há ações críticas (ataque, skill, etc)
- ❌ Não move se em cooldown

### Sistema de Movimento Baseado em Buffs

O plugin pode mover até o líder quando buffs específicos expiram, ideal para buff bots.

**Buffs Monitorados:**
- `EFST_BLESSING` - Blessing (Acolyte/Priest)
- `EFST_INC_AGI` - Increase Agility (Acolyte/Priest)
- `EFST_RICHMANKIM` - Richmankim (Bard)
- `EFST_ASSASSINCROSS` - Assassin Cross (Dancer)

**Lógica Adaptativa:**

O plugin detecta automaticamente a composição da party:

**1. Party SEM Bard/Dancer:**
```
- Histórico: Nunca recebeu Richmankim ou Assassin Cross
- Lógica: Move quando Blessing OU Inc Agi expirar
- Exemplo: Se apenas Blessing expirou → Vai ao líder
         Se apenas Inc Agi expirou → Vai ao líder
         Se ambos ativos → Não move
```

**2. Party COM Bard/Dancer:**
```
- Histórico: Já recebeu Richmankim ou Assassin Cross pelo menos uma vez
- Lógica: Move quando buffs de Bard/Dancer expirarem
- Exemplo: Se Richmankim expirou → Vai ao líder
         Se Richmankim ativo → Não move (ignora Blessing/Inc Agi)
```

**Modos de Movimento:**
- `distance`: Apenas por distância (padrão)
- `buff`: Apenas quando buffs expiram
- `both`: Movimento por distância OU por buffs (o que acontecer primeiro)

### Dados Rastreados

O plugin mantém as seguintes informações sobre o líder:

```perl
{
    id => Account ID do líder
    name => Nome do personagem líder
    x, y => Coordenadas exatas
    map => Nome do mapa atual
    distance => Células de distância (se no mesmo mapa)
    online => Status online (1/0)
    lastUpdate => Timestamp da última atualização
    isLeader => Se você é o líder (1/0)
}
```

## Casos de Uso

### Cenário 1: Você é Membro da Party
- Plugin rastreia continuamente a posição do líder
- Calcula distância em tempo real
- Move até o líder quando distância > trigger
- Para na distância configurada e fica lá
- Respeita cooldown entre movimentos

### Cenário 2: Você é o Líder
- Plugin detecta que você é o líder
- Não rastreia posição (você é o ponto de referência)
- Permanece pronto caso você deixe de ser líder

### Cenário 3: Não Está em Party
- Plugin aguarda até entrar em uma party
- Quando entrar, automaticamente começa o rastreamento

## Debug e Troubleshooting

### Ativando Debug Mode

```bash
arb debug          # Via comando (toggle)
```

Ou no `config.txt`:
```txt
autoRenewBuffs_debug 1
```

### Mensagens de Debug

Com debug ativado, você verá mensagens como:

```
[autoRenewBuffs DEBUG] Líder visível na tela: LiderName em (150, 200)
[autoRenewBuffs DEBUG] Posição do líder atualizada:
[autoRenewBuffs DEBUG]   Nome: LiderName
[autoRenewBuffs DEBUG]   Mapa: prontera
[autoRenewBuffs DEBUG]   Posição: (150, 200)
[autoRenewBuffs DEBUG]   Distância: 15 células
[autoRenewBuffs DEBUG] Verificando distância do líder: 12 células
[autoRenewBuffs DEBUG] Distância (12) > trigger (10), indo até o líder
[autoRenewBuffs DEBUG] Rota iniciada - ficará a ~3 células do líder
```

## Estrutura Técnica

### Variáveis Globais Utilizadas

```perl
$char           # Dados do personagem
@partyUsersID   # Lista de IDs dos membros da party
$accountID      # Seu account ID
$field          # Mapa atual
$net            # Estado da rede
%config         # Configurações
$playersList    # Lista de jogadores visíveis
```

### Hooks Monitorados

O plugin responde aos seguintes eventos do OpenKore:

- `start3` - Inicialização do plugin
- `AI_pre` - Loop principal de verificação e movimento
- `configModify` - Mudanças de configuração
- `packet_partyJoin` - Entrada em party
- `party_users_info_ready` - Atualização de info da party
- `Actor::setStatus::change` - Mudanças de status/buffs do personagem

## Limitações Conhecidas

1. **Coordenadas só disponíveis se:**
   - O líder está online
   - O líder está no mesmo servidor
   - O servidor envia pacotes de atualização de posição

2. **Distância:**
   - Só é calculada se estiver no mesmo mapa
   - Mostra -1 se em mapas diferentes

3. **Atualização:**
   - Coordenadas de líder fora da tela: 5-15 segundos de atraso
   - Coordenadas de líder na tela: tempo real
   - Frequência limitada pelo `checkInterval`

4. **Movimento:**
   - Usa pathfinding do OpenKore (respeita obstáculos)
   - Distância trigger > 17 pode ter problemas (limite de visão)

## Desenvolvimento Futuro

### Roadmap

**Fase 1 - Rastreamento e Movimento** ✅
- ✅ Detectar party
- ✅ Identificar líder
- ✅ Rastrear posição
- ✅ Armazenar dados
- ✅ Mover até o líder
- ✅ Sistema de cooldown

**Fase 2 (Atual) - Sistema de Buffs** ✅
- ✅ Detectar buffs ativos no personagem
- ✅ Rastrear expiração de buffs
- ✅ Movimento automático baseado em buffs
- ✅ Lógica adaptativa (com/sem Bard/Dancer)
- ✅ Três modos de movimento (distance/buff/both)
- ✅ Comandos para visualizar status de buffs

**Fase 3 (Próxima) - Auto Cast de Buffs**
- [ ] Sistema de auto-cast de skills
- [ ] Buffar membros específicos da party
- [ ] Sistema de prioridade de skills
- [ ] Auto-buff baseado em situação (combate, idle)

**Fase 4 (Futura) - Avançado**
- [ ] Sistema de macro para sequências de buff
- [ ] Notificações quando líder está longe
- [ ] Integração com eventMacro
- [ ] Suporte para buffs customizados

## Compatibilidade

- **OpenKore**: Versão recente (testado em 2024/2025)
- **Ragnarok Online**: Compatível com servidores RO
- **Perl**: Incluído no OpenKore
- **Plugins**: Compatível com outros plugins

## Changelog

### Versão 2.0 (Atual)
- ✅ Sistema de rastreamento de buffs
- ✅ Movimento baseado em expiração de buffs
- ✅ Detecção automática de Bard/Dancer na party
- ✅ Lógica adaptativa de movimento por buffs
- ✅ Três modos de movimento (distance/buff/both)
- ✅ Comandos para controle e visualização de buffs
- ✅ Hook Actor::setStatus::change
- ✅ Histórico de buffs para detecção de composição

### Versão 1.0
- ✅ Implementação inicial
- ✅ Rastreamento de posição do líder
- ✅ Movimento inteligente "ir e ficar"
- ✅ Sistema de comandos completo
- ✅ Configurações via config.txt
- ✅ Modo debug
- ✅ Cálculo de distância
- ✅ Detecção de mudança de mapa
- ✅ Sistema de cooldown
- ✅ Dupla verificação de coordenadas (visível/invisível)

## Suporte

Para reportar bugs ou sugerir melhorias:
1. Verifique se está usando a versão mais recente
2. Ative o modo debug e capture os logs
3. Descreva o problema detalhadamente

## Créditos

**Desenvolvedor**: Desenvolvido seguindo guidelines do OpenKore
**Baseado em**: Análise dos plugins busFollow, busParty, wait4party
**Documentação OpenKore**: http://openkore.com/wiki

---

**Versão**: 2.0
**Data**: 2025-01-09
**Status**: Funcional - Rastreamento, Movimento e Sistema de Buffs Implementados

---

## Exemplos Rápidos de Uso

### Modo Distância (Padrão)
```bash
# 1. Adicione ao config.txt
autoRenewBuffs_enabled 1
autoRenewBuffs_followEnabled 1
autoRenewBuffs_movementMode distance
autoRenewBuffs_followDistance 3
autoRenewBuffs_followTriggerDistance 7
autoRenewBuffs_moveCooldown 30

# 2. Inicie o OpenKore e entre em uma party (não como líder)

# 3. Use comandos
arb status              # Ver status
arb follow on           # Ativar movimento
arb debug               # Ver logs detalhados

# 4. Pronto! O bot irá até o líder quando necessário
```

### Modo Buff (Buff Bot)
```bash
# 1. Adicione ao config.txt
autoRenewBuffs_enabled 1
autoRenewBuffs_followEnabled 1
autoRenewBuffs_movementMode buff
autoRenewBuffs_followDistance 2
autoRenewBuffs_moveCooldown 20

# 2. Inicie o OpenKore e entre em uma party (não como líder)

# 3. Use comandos
arb follow on           # Ativar movimento
arb mode buff           # Modo buff
arb buffstatus          # Ver status dos buffs

# 4. O bot irá até o líder quando buffs expirarem!
```

### Modo Híbrido (Distância + Buff)
```bash
# 1. Adicione ao config.txt
autoRenewBuffs_enabled 1
autoRenewBuffs_followEnabled 1
autoRenewBuffs_movementMode both
autoRenewBuffs_followDistance 3
autoRenewBuffs_followTriggerDistance 10
autoRenewBuffs_moveCooldown 30

# 2. Use: arb mode both

# 3. O bot irá ao líder quando:
#    - Estiver a mais de 10 células OU
#    - Quando buffs expirarem
#    (o que acontecer primeiro)
```
