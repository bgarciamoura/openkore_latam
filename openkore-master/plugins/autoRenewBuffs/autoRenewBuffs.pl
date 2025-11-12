package autoRenewBuffs;

use strict;
use Plugins;
use Settings;
use Globals qw($char @partyUsersID $accountID $field $net %config %timeout $playersList %statusName);
use Network;
use Log qw(message debug error warning);
use Utils qw(timeOut distance blockDistance);
use Commands;
use AI;

# ============================================
# Plugin Information
# ============================================
Plugins::register(
    'autoRenewBuffs',
    'Automatically renew buffs by tracking party leader position',
    \&Unload,
    \&Reload
);

# ============================================
# Plugin Variables
# ============================================
my $hooks;
my $commands;
my $enabled = 1;
my $debugMode = 0;

# Follow settings
my $followEnabled = 0;
my $followDistance = 3;      # Distância de parada próximo ao líder
my $followTriggerDistance = 7;  # Distância para disparar movimento

# Timeouts
my $checkTimeout = { time => 0, timeout => 2 };  # Default 2 seconds
my $moveTimeout = 5;  # Default 5 seconds for moving to leader
my $followCheckTimeout = { time => 0, timeout => 1 };  # Check follow every 1 second
my $lastMoveTime = 0;  # Última vez que foi até o líder
my $moveCooldown = 30;  # Cooldown entre movimentos (30 segundos)

# Leader data storage
my %leaderData = (
    id => undef,
    name => '',
    x => undef,
    y => undef,
    map => '',
    distance => 0,
    online => 0,
    lastUpdate => 0,
    isLeader => 0
);

# Movement mode
my $movementMode = 'distance';  # 'distance', 'buff', 'both'

# Buff tracking
my %buffHistory = (
    EFST_BLESSING => 0,
    EFST_INC_AGI => 0,
    EFST_RICHMANKIM => 0,
    EFST_ASSASSINCROSS => 0
);

my %buffStatus = (
    EFST_BLESSING => 0,
    EFST_INC_AGI => 0,
    EFST_RICHMANKIM => 0,
    EFST_ASSASSINCROSS => 0
);

my $lastBuffCheckTime = 0;
my $buffCheckInterval = 1;  # Check buffs every 1 second
my $buffMovementTriggered = 0;

# ============================================
# Hook Registration
# ============================================
$hooks = Plugins::addHooks(
    ['start3', \&onStart, undef],
    ['AI_pre', \&onAI, undef],
    ['configModify', \&onConfigChange, undef],
    ['packet_partyJoin', \&onPartyJoin, undef],
    ['party_users_info_ready', \&onPartyInfo, undef],
    ['Actor::setStatus::change', \&onStatusChange, undef]
);

# ============================================
# Initialization
# ============================================
sub onStart {
    message "[autoRenewBuffs] Plugin inicializado\n", "success";
    loadConfig();
    registerCommands();
}

sub loadConfig {
    # Load enabled state
    if (exists $config{autoRenewBuffs_enabled}) {
        $enabled = $config{autoRenewBuffs_enabled};
    } else {
        $config{autoRenewBuffs_enabled} = 1;
        $enabled = 1;
    }

    # Load check interval
    if (exists $config{autoRenewBuffs_checkInterval}) {
        $checkTimeout->{timeout} = $config{autoRenewBuffs_checkInterval};
    } else {
        $config{autoRenewBuffs_checkInterval} = 2;
        $checkTimeout->{timeout} = 2;
    }

    # Load move timeout
    if (exists $config{autoRenewBuffs_moveTimeout}) {
        $moveTimeout = $config{autoRenewBuffs_moveTimeout};
    } else {
        $config{autoRenewBuffs_moveTimeout} = 5;
        $moveTimeout = 5;
    }

    # Load debug mode
    if (exists $config{autoRenewBuffs_debug}) {
        $debugMode = $config{autoRenewBuffs_debug};
    } else {
        $config{autoRenewBuffs_debug} = 0;
        $debugMode = 0;
    }

    # Load follow enabled
    if (exists $config{autoRenewBuffs_followEnabled}) {
        $followEnabled = $config{autoRenewBuffs_followEnabled};
    } else {
        $config{autoRenewBuffs_followEnabled} = 0;
        $followEnabled = 0;
    }

    # Load follow distance (distância de parada)
    if (exists $config{autoRenewBuffs_followDistance}) {
        $followDistance = $config{autoRenewBuffs_followDistance};
    } else {
        $config{autoRenewBuffs_followDistance} = 3;
        $followDistance = 3;
    }

    # Load follow trigger distance (distância para disparar movimento)
    if (exists $config{autoRenewBuffs_followTriggerDistance}) {
        $followTriggerDistance = $config{autoRenewBuffs_followTriggerDistance};
    } else {
        $config{autoRenewBuffs_followTriggerDistance} = 7;
        $followTriggerDistance = 7;
    }

    # Load move cooldown
    if (exists $config{autoRenewBuffs_moveCooldown}) {
        $moveCooldown = $config{autoRenewBuffs_moveCooldown};
    } else {
        $config{autoRenewBuffs_moveCooldown} = 30;
        $moveCooldown = 30;
    }

    # Load movement mode
    if (exists $config{autoRenewBuffs_movementMode}) {
        my $mode = $config{autoRenewBuffs_movementMode};
        if ($mode eq 'distance' || $mode eq 'buff' || $mode eq 'both') {
            $movementMode = $mode;
        } else {
            warning "[autoRenewBuffs] Modo inválido: $mode. Usando 'distance'\n";
            $config{autoRenewBuffs_movementMode} = 'distance';
            $movementMode = 'distance';
        }
    } else {
        $config{autoRenewBuffs_movementMode} = 'distance';
        $movementMode = 'distance';
    }

    # Load buff check interval
    if (exists $config{autoRenewBuffs_buffCheckInterval}) {
        $buffCheckInterval = $config{autoRenewBuffs_buffCheckInterval};
    } else {
        $config{autoRenewBuffs_buffCheckInterval} = 1;
        $buffCheckInterval = 1;
    }

    debugLog("Configurações carregadas:", 1);
    debugLog("  Enabled: $enabled", 1);
    debugLog("  Check Interval: $checkTimeout->{timeout}s", 1);
    debugLog("  Move Timeout: ${moveTimeout}s", 1);
    debugLog("  Debug Mode: $debugMode", 1);
    debugLog("  Follow Enabled: $followEnabled", 1);
    debugLog("  Follow Distance: $followDistance", 1);
    debugLog("  Follow Trigger Distance: $followTriggerDistance", 1);
    debugLog("  Move Cooldown: ${moveCooldown}s", 1);
    debugLog("  Movement Mode: $movementMode", 1);
    debugLog("  Buff Check Interval: ${buffCheckInterval}s", 1);
}

sub onConfigChange {
    my (undef, $args) = @_;

    # Reload config if any autoRenewBuffs setting changes
    if ($args->{key} =~ /^autoRenewBuffs_/) {
        debugLog("Configuração alterada: $args->{key} = $args->{val}", 2);
        loadConfig();
    }
}

# ============================================
# Main AI Loop
# ============================================
sub onAI {
    # Check if plugin is enabled
    return unless $enabled;

    # Validate game state
    return unless $char;
    return unless $net->getState() == Network::IN_GAME;
    return if $char->{dead};

    # Check timeout for party tracking
    if (timeOut($checkTimeout)) {
        $checkTimeout->{time} = time;
        checkPartyLeader();
    }

    # Check follow logic (separate timeout)
    if ($followEnabled && timeOut($followCheckTimeout)) {
        $followCheckTimeout->{time} = time;
        checkFollowLeader();
    }

    # Check buffs for movement (if enabled)
    if (($movementMode eq 'buff' || $movementMode eq 'both') && (time - $lastBuffCheckTime >= $buffCheckInterval)) {
        $lastBuffCheckTime = time;
        updateCurrentBuffs();
        checkBuffMovement();
    }
}

# ============================================
# Buff Tracking and Status
# ============================================
sub updateCurrentBuffs {
    return unless $char;

    # Update current buff status
    for my $buffHandle (keys %buffStatus) {
        my $active = $char->statusActive($buffHandle);

        # Track if buff changed state
        my $wasActive = $buffStatus{$buffHandle};
        $buffStatus{$buffHandle} = $active ? 1 : 0;

        # If buff became active, record in history
        if ($active && !$wasActive) {
            $buffHistory{$buffHandle} = 1;
            debugLog("Buff ativado: $buffHandle", 2);
        } elsif (!$active && $wasActive) {
            debugLog("Buff expirou: $buffHandle", 2);
        }
    }
}

sub checkBuffMovement {
    # Don't move if we're the leader
    return if $leaderData{isLeader};

    # Don't move if no leader data
    return unless $leaderData{id};

    # Don't move if coordinates not available
    return unless defined($leaderData{x}) && defined($leaderData{y});

    # Don't move if different map
    return unless $field && $leaderData{map} eq $field->baseName();

    # Don't move if leader offline
    return unless $leaderData{online};

    # Check cooldown
    my $timeSinceLastMove = time - $lastMoveTime;
    if ($timeSinceLastMove < $moveCooldown) {
        return;
    }

    # Check if should move based on buffs
    if (shouldMoveBasedOnBuffs()) {
        debugLog("Buffs expiraram, indo até o líder para renovação", 1);
        $buffMovementTriggered = 1;
        moveToLeader();
    }
}

sub shouldMoveBasedOnBuffs {
    # Check if ever received BD_RICHMANKIM (indicates Bard/Dancer in party)
    my $hasBardDancer = $buffHistory{EFST_RICHMANKIM} || $buffHistory{EFST_ASSASSINCROSS};

    if ($hasBardDancer) {
        # Party has Bard/Dancer - check only Bard/Dancer buffs
        my $richmankim = $buffStatus{EFST_RICHMANKIM};
        my $assassincross = $buffStatus{EFST_ASSASSINCROSS};

        # Move if Bard/Dancer buffs are not active
        if (!$richmankim && !$assassincross) {
            debugLog("Party tem Bard/Dancer - Buffs BD expirados, necessário renovar", 1);
            return 1;
        }
    } else {
        # No Bard/Dancer - check Priest buffs
        my $blessing = $buffStatus{EFST_BLESSING};
        my $incAgi = $buffStatus{EFST_INC_AGI};

        # Move if EITHER Blessing OR Inc Agi expired
        if (!$blessing || !$incAgi) {
            debugLog("Sem Bard/Dancer - Buffs básicos expirados (Blessing: $blessing, Inc Agi: $incAgi)", 1);
            return 1;
        }
    }

    return 0;
}

sub onStatusChange {
    my (undef, $args) = @_;

    # Only track changes on our character
    return unless $args->{actor} && $args->{actor}{ID} eq $char->{ID};

    my $handle = $args->{handle};

    # Check if this is one of our tracked buffs
    return unless exists $buffStatus{$handle};

    # Update will be done in updateCurrentBuffs()
    debugLog("Status change detectado: $handle (ativo: " . ($args->{flag} ? "sim" : "não") . ")", 2);
}

# ============================================
# Party Leader Tracking
# ============================================
sub checkPartyLeader {
    # Verify if in party
    unless ($char->{party}{joined} && @partyUsersID) {
        if ($leaderData{id}) {
            debugLog("Não está mais em party, limpando dados do líder", 1);
            clearLeaderData();
        }
        return;
    }

    # Check if I'm the leader
    if ($char->{party}{users}{$accountID}{admin}) {
        if (!$leaderData{isLeader}) {
            debugLog("Você é o líder da party", 1);
            $leaderData{isLeader} = 1;
            clearLeaderData();
        }
        return;
    }

    # I'm not the leader, find and track the leader
    $leaderData{isLeader} = 0;
    my $leaderId = getLeaderID();

    if ($leaderId) {
        updateLeaderData($leaderId);
    } else {
        debugLog("Líder da party não encontrado", 2);
    }
}

sub getLeaderID {
    for my $id (@partyUsersID) {
        next unless $id;
        next if $id eq '';

        if ($char->{party}{users}{$id}{admin}) {
            return $id;
        }
    }
    return undef;
}

sub updateLeaderData {
    my $leaderId = shift;

    my $leader = $char->{party}{users}{$leaderId};

    unless ($leader) {
        debugLog("Dados do líder não disponíveis", 2);
        return;
    }

    # Store previous data for comparison
    my $prevX = $leaderData{x};
    my $prevY = $leaderData{y};
    my $prevMap = $leaderData{map};

    my ($x, $y, $map);

    # MÉTODO 1: Tentar obter do playersList (se visível na tela)
    # O playersList contém coordenadas mais precisas e em tempo real
    my $actor = $playersList->getByID($leaderId);
    if ($actor) {
        # Líder está visível - coordenadas precisas e atualizadas
        $x = $actor->{pos_to}{x};
        $y = $actor->{pos_to}{y};
        $map = $field->baseName();
        debugLog("Líder visível na tela: $actor->{name} em ($x, $y)", 2);
    }
    # MÉTODO 2: Obter do hash da party (se não visível)
    # O servidor envia coordenadas periodicamente via pacote party_location
    else {
        $x = $leader->{pos}{x};
        $y = $leader->{pos}{y};
        my $mapName = $leader->{map} || '';
        ($map) = $mapName =~ /([\s\S]*)\.gat/;
        $map = $mapName unless $map;  # Fallback se não tem .gat

        # VALIDAÇÃO CRÍTICA: coordenadas só são válidas se:
        # 1. Estão definidas (não são undef)
        # 2. São diferentes de 0 (coordenadas 0,0 são inválidas)
        # 3. Estão no mesmo mapa
        if (!$map || $map ne $field->baseName() || !defined($x) || !defined($y) || $x == 0 || $y == 0) {
            $x = undef;
            $y = undef;
            debugLog("Líder fora da tela - coordenadas não disponíveis ainda", 1);
        } else {
            debugLog("Líder fora da tela, usando coordenadas da party: ($x, $y)", 2);
        }
    }

    # Update leader data
    $leaderData{id} = $leaderId;
    $leaderData{name} = $leader->{name} || 'Unknown';
    $leaderData{x} = $x;
    $leaderData{y} = $y;
    $leaderData{map} = $map;
    $leaderData{online} = $leader->{online} || 0;
    $leaderData{lastUpdate} = time;

    # Calculate distance apenas se coordenadas válidas
    if (defined($x) && defined($y)) {
        my $myPos = {
            x => $char->{pos_to}{x},
            y => $char->{pos_to}{y}
        };
        my $leaderPos = {
            x => $x,
            y => $y
        };
        $leaderData{distance} = int(distance($myPos, $leaderPos));

        # Debug logging for position changes
        if ($debugMode >= 2) {
            if (!defined($prevX) || !defined($prevY) || $prevX != $x || $prevY != $y || $prevMap ne $map) {
                debugLog("Posição do líder atualizada:", 2);
                debugLog("  Nome: $leaderData{name}", 2);
                debugLog("  Mapa: $leaderData{map}", 2);
                debugLog("  Posição: ($x, $y)", 2);
                debugLog("  Distância: $leaderData{distance} células", 2);
                debugLog("  Online: $leaderData{online}", 2);
            }
        }
    } else {
        $leaderData{distance} = -1;  # Coordenadas não disponíveis

        if ($debugMode >= 1) {
            debugLog("Aguardando servidor enviar coordenadas do líder...", 1);
        }
    }
}

sub clearLeaderData {
    %leaderData = (
        id => undef,
        name => '',
        x => undef,
        y => undef,
        map => '',
        distance => 0,
        online => 0,
        lastUpdate => 0,
        isLeader => 0
    );
}

# ============================================
# Follow Leader Logic (Go and Stay)
# ============================================
sub checkFollowLeader {
    # Only check distance-based movement in 'distance' or 'both' mode
    return unless ($movementMode eq 'distance' || $movementMode eq 'both');

    # Verificar se há dados do líder
    return unless $leaderData{id};
    return if $leaderData{isLeader};  # Não seguir se você é o líder

    # Verificar se temos coordenadas válidas
    return unless defined($leaderData{x}) && defined($leaderData{y});

    # Verificar se está no mesmo mapa
    return unless $field && $leaderData{map} eq $field->baseName();

    # Verificar se o líder está online
    return unless $leaderData{online};

    my $distance = $leaderData{distance};

    debugLog("Verificando distância do líder: $distance células", 2);

    # Verificar cooldown - só mover novamente após o cooldown
    my $timeSinceLastMove = time - $lastMoveTime;
    if ($timeSinceLastMove < $moveCooldown) {
        my $remainingTime = $moveCooldown - $timeSinceLastMove;
        debugLog("Cooldown ativo: ${remainingTime}s restantes", 2);
        return;
    }

    # Se a distância é maior que trigger distance, ir até o líder
    if ($distance > $followTriggerDistance) {
        debugLog("Distância ($distance) > trigger ($followTriggerDistance), indo até o líder", 1);
        moveToLeader();
    } else {
        debugLog("Distância OK ($distance <= $followTriggerDistance)", 2);
    }
}

sub moveToLeader {
    # Verificar se já está em rota
    if (AI::action eq "route") {
        debugLog("Já está em rota, aguardando", 2);
        return;
    }

    # Verificar se há outras ações críticas em andamento
    if (AI::inQueue("attack", "skill", "buyAuto", "sellAuto", "storageAuto")) {
        debugLog("Ações críticas em andamento, adiando movimento", 2);
        return;
    }

    debugLog("Iniciando movimento para líder: ($leaderData{x}, $leaderData{y})", 1);
    message "[autoRenewBuffs] Indo até o líder $leaderData{name} (distância: $leaderData{distance})\n", "info";

    # Atualizar tempo do último movimento
    $lastMoveTime = time;

    # Limpar rotas anteriores para evitar conflitos
    AI::clear("move", "route", "mapRoute");

    # Usar AI::ai_route para mover até o líder (função correta do OpenKore)
    # distFromGoal define a distância de parada
    AI::ai_route(
        $field->baseName(),
        $leaderData{x},
        $leaderData{y},
        distFromGoal => $followDistance,
        maxRouteTime => $moveTimeout
    );

    debugLog("Rota iniciada - ficará a ~${followDistance} células do líder", 1);
}

# ============================================
# Party Event Handlers
# ============================================
sub onPartyJoin {
    my (undef, $args) = @_;

    my $partyName = $args->{partyName} || 'Unknown';
    message "[autoRenewBuffs] Entrou na party: $partyName\n", "success";
    debugLog("Party join event recebido", 2);
}

sub onPartyInfo {
    debugLog("Informações da party atualizadas", 2);
}

# ============================================
# Console Commands
# ============================================
sub registerCommands {
    $commands = Commands::register(
        ['arb', 'Auto Renew Buffs - Controle do plugin', \&handleCommand],
        ['renewbuffs', 'Auto Renew Buffs - Controle do plugin (alias)', \&handleCommand]
    );

    debugLog("Comandos registrados: arb, renewbuffs", 2);
}

sub handleCommand {
    my (undef, $args) = @_;

    my @params = split(' ', $args);
    my $action = $params[0] || '';

    if ($action eq '' || $action eq 'help') {
        showHelp();
    } elsif ($action eq 'on') {
        enablePlugin();
    } elsif ($action eq 'off') {
        disablePlugin();
    } elsif ($action eq 'status') {
        showStatus();
    } elsif ($action eq 'debug') {
        toggleDebug();
    } elsif ($action eq 'follow') {
        if (defined $params[1]) {
            if ($params[1] eq 'on') {
                enableFollow();
            } elsif ($params[1] eq 'off') {
                disableFollow();
            } else {
                error "[autoRenewBuffs] Uso: arb follow <on|off>\n";
            }
        } else {
            # Toggle follow
            if ($followEnabled) {
                disableFollow();
            } else {
                enableFollow();
            }
        }
    } elsif ($action eq 'setmove') {
        if (defined $params[1] && $params[1] =~ /^\d+$/) {
            setMoveTimeout($params[1]);
        } else {
            error "[autoRenewBuffs] Uso: arb setmove <segundos>\n";
        }
    } elsif ($action eq 'setdist') {
        if (defined $params[1] && defined $params[2] && $params[1] =~ /^\d+$/ && $params[2] =~ /^\d+$/) {
            setFollowDistance($params[1], $params[2]);
        } else {
            error "[autoRenewBuffs] Uso: arb setdist <stop> <trigger>\n";
            message "  stop   = distância de parada próximo ao líder\n";
            message "  trigger = distância para disparar movimento\n";
        }
    } elsif ($action eq 'setcooldown') {
        if (defined $params[1] && $params[1] =~ /^\d+$/) {
            setMoveCooldown($params[1]);
        } else {
            error "[autoRenewBuffs] Uso: arb setcooldown <segundos>\n";
        }
    } elsif ($action eq 'mode') {
        if (defined $params[1]) {
            setMovementMode($params[1]);
        } else {
            error "[autoRenewBuffs] Uso: arb mode <distance|buff|both>\n";
        }
    } elsif ($action eq 'buffstatus') {
        showBuffStatus();
    } elsif ($action eq 'resetbuffs') {
        resetBuffHistory();
    } else {
        error "[autoRenewBuffs] Comando desconhecido: $action\n";
        message "Use 'arb help' para ver comandos disponíveis\n";
    }
}

sub showHelp {
    message "=============== Auto Renew Buffs ===============\n", "list";
    message "Comandos disponíveis:\n", "list";
    message "  arb on                  - Ativar plugin\n", "list";
    message "  arb off                 - Desativar plugin\n", "list";
    message "  arb status              - Ver status e posição do líder\n", "list";
    message "  arb debug               - Ativar/desativar modo debug\n", "list";
    message "  arb follow [on|off]     - Ir até o líder quando necessário\n", "list";
    message "  arb mode <type>         - Modo movimento (distance/buff/both)\n", "list";
    message "  arb buffstatus          - Ver status atual dos buffs\n", "list";
    message "  arb resetbuffs          - Resetar histórico de buffs\n", "list";
    message "  arb setmove <s>         - Timeout de movimento (segundos)\n", "list";
    message "  arb setdist <stop> <trigger> - Distâncias (parada/trigger)\n", "list";
    message "  arb setcooldown <s>     - Cooldown entre movimentos (segundos)\n", "list";
    message "  arb help                - Mostrar esta ajuda\n", "list";
    message "===============================================\n", "list";
    message "Exemplos:\n", "info";
    message "  arb follow on && arb setdist 3 10\n", "info";
    message "    → Ativa follow, para a 3 células, vai se >10\n", "info";
    message "  arb mode buff\n", "info";
    message "    → Movimento baseado apenas em buffs\n", "info";
    message "  arb mode both\n", "info";
    message "    → Movimento por distância E por buffs\n", "info";
}

sub enablePlugin {
    $enabled = 1;
    $config{autoRenewBuffs_enabled} = 1;
    message "[autoRenewBuffs] Plugin ATIVADO\n", "success";
}

sub disablePlugin {
    $enabled = 0;
    $config{autoRenewBuffs_enabled} = 0;
    message "[autoRenewBuffs] Plugin DESATIVADO\n", "success";
}

sub showStatus {
    message "=============== Auto Renew Buffs Status ===============\n", "list";
    message "Plugin: " . ($enabled ? "ATIVADO" : "DESATIVADO") . "\n", "list";
    message "Intervalo de verificação: $checkTimeout->{timeout}s\n", "list";
    message "Timeout de movimento: ${moveTimeout}s\n", "list";
    message "Modo debug: " . ($debugMode ? "ATIVADO" : "DESATIVADO") . "\n", "list";

    # Movement mode
    message "Modo de movimento: " . uc($movementMode) . "\n", "list";
    if ($movementMode eq 'distance') {
        message "  → Movimento por DISTÂNCIA apenas\n", "list";
    } elsif ($movementMode eq 'buff') {
        message "  → Movimento por BUFFS apenas\n", "list";
    } elsif ($movementMode eq 'both') {
        message "  → Movimento por DISTÂNCIA e BUFFS\n", "list";
    }

    message "Follow líder: " . ($followEnabled ? "ATIVADO" : "DESATIVADO") . "\n", "list";
    if ($followEnabled) {
        message "  Distância de parada: $followDistance células\n", "list";
        message "  Distância trigger: $followTriggerDistance células\n", "list";
        message "  Cooldown: ${moveCooldown}s\n", "list";

        if ($lastMoveTime > 0) {
            my $timeSinceMove = time - $lastMoveTime;
            my $cooldownRemaining = $moveCooldown - $timeSinceMove;
            if ($cooldownRemaining > 0) {
                message "  Próximo movimento em: ${cooldownRemaining}s\n", "list";
            } else {
                message "  Status: Pronto para mover\n", "list";
            }
        } else {
            message "  Status: Aguardando primeira ativação\n", "list";
        }
    }
    message "======================================================\n", "list";

    # Party status
    if ($char->{party}{joined}) {
        message "Party: $char->{party}{name}\n", "list";
        message "Membros: " . scalar(@partyUsersID) . "\n", "list";

        if ($leaderData{isLeader}) {
            message "Status: VOCÊ É O LÍDER\n", "list";
        } elsif ($leaderData{id}) {
            message "Líder: $leaderData{name}\n", "list";
            message "Mapa: $leaderData{map}\n", "list";

            # Exibir posição apenas se disponível
            if (defined($leaderData{x}) && defined($leaderData{y})) {
                message "Posição: ($leaderData{x}, $leaderData{y})\n", "list";

                if ($leaderData{distance} >= 0) {
                    message "Distância: $leaderData{distance} células\n", "list";
                } else {
                    message "Distância: CALCULANDO...\n", "list";
                }
            } else {
                message "Posição: AGUARDANDO DADOS DO SERVIDOR\n", "list";
                message "Dica: O servidor envia coordenadas periodicamente (5-15s)\n", "list";
            }

            message "Online: " . ($leaderData{online} ? "SIM" : "NÃO") . "\n", "list";

            if ($leaderData{lastUpdate} > 0) {
                my $timeSinceUpdate = time - $leaderData{lastUpdate};
                message "Última atualização: há ${timeSinceUpdate}s\n", "list";
            }
        } else {
            message "Líder: NÃO ENCONTRADO\n", "list";
        }
    } else {
        message "Party: NÃO ESTÁ EM PARTY\n", "list";
    }

    message "======================================================\n", "list";
}

sub toggleDebug {
    $debugMode = !$debugMode;
    $config{autoRenewBuffs_debug} = $debugMode;

    if ($debugMode) {
        message "[autoRenewBuffs] Modo debug ATIVADO\n", "success";
        message "[autoRenewBuffs] Mensagens de debug aparecerão com prefixo [autoRenewBuffs DEBUG]\n", "info";

        # Mensagem de teste imediata
        debugLog("Modo debug ativo - teste de mensagem", 1);
        debugLog("Configurações atuais:", 1);
        debugLog("  Enabled: $enabled", 1);
        debugLog("  Check Interval: $checkTimeout->{timeout}s", 1);
        debugLog("  Move Timeout: ${moveTimeout}s", 1);
    } else {
        message "[autoRenewBuffs] Modo debug DESATIVADO\n", "success";
    }
}

sub setMoveTimeout {
    my $seconds = shift;

    if ($seconds < 1) {
        error "[autoRenewBuffs] Timeout deve ser no mínimo 1 segundo\n";
        return;
    }

    $moveTimeout = $seconds;
    $config{autoRenewBuffs_moveTimeout} = $seconds;

    message "[autoRenewBuffs] Timeout de movimento configurado para ${seconds}s\n", "success";
}

sub enableFollow {
    $followEnabled = 1;
    $config{autoRenewBuffs_followEnabled} = 1;

    # Resetar cooldown ao ativar
    $lastMoveTime = 0;

    message "[autoRenewBuffs] Follow ATIVADO - Irá até o líder quando necessário\n", "success";
    message "[autoRenewBuffs] Distância de parada: ${followDistance} | Distância trigger: ${followTriggerDistance}\n", "info";
    message "[autoRenewBuffs] Cooldown entre movimentos: ${moveCooldown}s\n", "info";

    if ($debugMode) {
        debugLog("Follow ativado", 1);
        debugLog("  Stop Distance: $followDistance", 1);
        debugLog("  Trigger Distance: $followTriggerDistance", 1);
        debugLog("  Cooldown: ${moveCooldown}s", 1);
    }
}

sub disableFollow {
    $followEnabled = 0;
    $config{autoRenewBuffs_followEnabled} = 0;
    message "[autoRenewBuffs] Follow DESATIVADO\n", "success";

    # Cancelar rota em andamento se houver
    if (AI::action eq "route") {
        AI::dequeue();
        message "[autoRenewBuffs] Rota cancelada\n", "info";
    }

    debugLog("Follow desativado", 1) if $debugMode;
}

sub setFollowDistance {
    my ($stop, $trigger) = @_;

    if ($stop < 1) {
        error "[autoRenewBuffs] Distância de parada deve ser no mínimo 1\n";
        return;
    }

    if ($trigger <= $stop) {
        error "[autoRenewBuffs] Distância trigger deve ser maior que distância de parada\n";
        return;
    }

    if ($trigger > 17) {
        warning "[autoRenewBuffs] Distância trigger > 17 pode causar problemas (limite de visão)\n";
    }

    $followDistance = $stop;
    $followTriggerDistance = $trigger;
    $config{autoRenewBuffs_followDistance} = $stop;
    $config{autoRenewBuffs_followTriggerDistance} = $trigger;

    message "[autoRenewBuffs] Distâncias configuradas:\n", "success";
    message "  Parada: $stop células | Trigger: $trigger células\n", "info";

    debugLog("Distâncias atualizadas: Stop=$stop, Trigger=$trigger", 1) if $debugMode;
}

sub setMoveCooldown {
    my $seconds = shift;

    if ($seconds < 5) {
        error "[autoRenewBuffs] Cooldown deve ser no mínimo 5 segundos\n";
        return;
    }

    $moveCooldown = $seconds;
    $config{autoRenewBuffs_moveCooldown} = $seconds;

    message "[autoRenewBuffs] Cooldown de movimento configurado para ${seconds}s\n", "success";

    debugLog("Cooldown atualizado: ${seconds}s", 1) if $debugMode;
}

sub setMovementMode {
    my $mode = shift;

    unless ($mode eq 'distance' || $mode eq 'buff' || $mode eq 'both') {
        error "[autoRenewBuffs] Modo inválido: $mode\n";
        message "Modos válidos: distance, buff, both\n", "info";
        return;
    }

    $movementMode = $mode;
    $config{autoRenewBuffs_movementMode} = $mode;

    message "[autoRenewBuffs] Modo de movimento configurado para: " . uc($mode) . "\n", "success";

    if ($mode eq 'distance') {
        message "  → Movimento baseado em DISTÂNCIA do líder\n", "info";
    } elsif ($mode eq 'buff') {
        message "  → Movimento baseado em BUFFS expirados\n", "info";
        message "  → Buffs monitorados: Blessing, Inc Agi, Richmankim, Assassin Cross\n", "info";
    } elsif ($mode eq 'both') {
        message "  → Movimento baseado em DISTÂNCIA e BUFFS\n", "info";
    }

    debugLog("Modo de movimento atualizado: $mode", 1) if $debugMode;
}

sub showBuffStatus {
    message "=============== Buff Status ===============\n", "list";

    # Check if party has Bard/Dancer
    my $hasBardDancer = $buffHistory{EFST_RICHMANKIM} || $buffHistory{EFST_ASSASSINCROSS};

    if ($hasBardDancer) {
        message "Party: COM Bard/Dancer detectado\n", "list";
        message "Lógica: Movimento ao expirar buffs BD\n", "list";
    } else {
        message "Party: SEM Bard/Dancer\n", "list";
        message "Lógica: Movimento ao expirar Blessing OU Inc Agi\n", "list";
    }

    message "-------------------------------------------\n", "list";
    message "Buffs Atuais:\n", "list";

    # Get buff names
    my %buffNames = (
        EFST_BLESSING => 'Blessing',
        EFST_INC_AGI => 'Inc Agi',
        EFST_RICHMANKIM => 'Richmankim (Bard)',
        EFST_ASSASSINCROSS => 'Assassin Cross (Dancer)'
    );

    for my $buffHandle (sort keys %buffStatus) {
        my $active = $buffStatus{$buffHandle};
        my $history = $buffHistory{$buffHandle};
        my $name = $buffNames{$buffHandle};

        my $status = $active ? "ATIVO" : "INATIVO";
        my $historyStr = $history ? "(já recebido)" : "(nunca recebido)";

        message sprintf("  %-30s %s %s\n", $name, $status, $historyStr), "list";
    }

    message "===========================================\n", "list";

    # Show if would move based on current buffs
    if ($movementMode eq 'buff' || $movementMode eq 'both') {
        if (shouldMoveBasedOnBuffs()) {
            message "Status: MOVERIA até o líder (buffs expirados)\n", "warning";
        } else {
            message "Status: Buffs OK, não precisa mover\n", "success";
        }
    } else {
        message "Modo buff DESATIVADO (modo atual: $movementMode)\n", "info";
    }
}

sub resetBuffHistory {
    # Reset history
    for my $buffHandle (keys %buffHistory) {
        $buffHistory{$buffHandle} = 0;
    }

    # Reset current status
    for my $buffHandle (keys %buffStatus) {
        $buffStatus{$buffHandle} = 0;
    }

    message "[autoRenewBuffs] Histórico de buffs resetado\n", "success";
    message "Todos os buffs marcados como 'nunca recebido'\n", "info";

    debugLog("Histórico de buffs resetado", 1) if $debugMode;
}

# ============================================
# Utility Functions
# ============================================
sub debugLog {
    my ($msg, $level) = @_;
    $level ||= 1;

    return unless $debugMode >= $level;

    # Quando debug mode está ativado no plugin, usar message()
    # para garantir que apareça no console (independente do debug do OpenKore)
    if ($debugMode) {
        # Usar diferentes cores baseado no nível
        if ($level == 1) {
            message "[autoRenewBuffs DEBUG] $msg\n", "info";
        } elsif ($level == 2) {
            message "[autoRenewBuffs DEBUG] $msg\n", "list";
        } else {
            message "[autoRenewBuffs DEBUG] $msg\n", "plugins";
        }
    }
}

# ============================================
# Plugin Lifecycle
# ============================================
sub Unload {
    # Remove hooks
    Plugins::delHooks($hooks) if $hooks;

    # Unregister commands
    Commands::unregister($commands) if $commands;

    # Clear data
    clearLeaderData();
    undef $hooks;
    undef $commands;

    message "[autoRenewBuffs] Plugin descarregado\n", "system";
}

sub Reload {
    message "[autoRenewBuffs] Plugin recarregado\n", "system";
    Unload();
}

# ============================================
# Required: Return true
# ============================================
1;
