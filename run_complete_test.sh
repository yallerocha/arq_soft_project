#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

log() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Detectar modo local
LOCAL_MODE=false
if [[ "$1" == "--local" ]] || [[ "$2" == "--local" ]]; then
    LOCAL_MODE=true
    # Remover --local dos argumentos
    ARGS=("$@")
    ARGS=("${ARGS[@]/--local}")
    set -- "${ARGS[@]}"
fi

SCENARIO=${1:-"both"}
if [[ ! "$SCENARIO" =~ ^(unsharded|sharded|both|local)$ ]]; then
    log $RED "❌ Uso: ./run_complete_test.sh [unsharded|sharded|both|local] [--local]"
    log $YELLOW "   Exemplos:"
    log $YELLOW "   ./run_complete_test.sh local      # Teste local rápido"
    log $YELLOW "   ./run_complete_test.sh --local    # Teste local rápido"
    log $YELLOW "   ./run_complete_test.sh both       # Teste distribuído AWS"
    exit 1
fi

# Se o cenário for 'local', ativar modo local
if [[ "$SCENARIO" == "local" ]]; then
    LOCAL_MODE=true
fi

CONFIG_FILE="./config.env"

# Função para executar teste local
run_local_test() {
    log $BLUE "🏠 Executando teste local..."
    log $YELLOW "   Verificando se mock server está rodando..."
    
    # Verificar se o servidor está rodando
    if curl -s http://localhost:8000/feed?user_id=test > /dev/null 2>&1; then
        log $GREEN "✅ Mock server detectado em localhost:8000"
    else
        log $RED "❌ Mock server não encontrado em localhost:8000"
        log $YELLOW "   Execute em outro terminal:"
        log $YELLOW "   node mock_server.js"
        exit 1
    fi
    
    # Verificar se k6 está instalado
    if ! command -v k6 &> /dev/null; then
        log $RED "❌ K6 não está instalado"
        log $YELLOW "   Instale com: sudo apt install k6"
        exit 1
    fi
    
    log $GREEN "✅ K6 encontrado: $(k6 version --quiet 2>/dev/null || k6 version | head -1)"
    
    # Carregar configurações locais se existirem
    LOCAL_CONFIG="./config.local.env"
    if [ -f "$LOCAL_CONFIG" ]; then
        source "$LOCAL_CONFIG"
        log $GREEN "✅ Configurações locais carregadas"
    fi
    
    # Executar teste local
    log $BLUE "🚀 Iniciando bateria de testes de performance local..."
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    RESULTS_DIR="./test_results/local_${TIMESTAMP}"
    mkdir -p "$RESULTS_DIR"
    
    # Teste com diferentes configurações usando o script local otimizado
    log $YELLOW "   📊 Teste 1: Carga leve (${VUS_LIGHT:-10} usuários, ${DURATION_LIGHT:-30s})"
    VUS=${VUS_LIGHT:-10} DURATION=${DURATION_LIGHT:-30s} API_URL=http://localhost:8000 SLEEP=1 \
        k6 run k6_local_test.js --out json="$RESULTS_DIR/light_test.json" --summary-export="$RESULTS_DIR/light_summary.json"
    
    log $YELLOW "   📊 Teste 2: Carga média (${VUS_MEDIUM:-50} usuários, ${DURATION_MEDIUM:-60s})"  
    VUS=${VUS_MEDIUM:-50} DURATION=${DURATION_MEDIUM:-60s} API_URL=http://localhost:8000 SLEEP=1 \
        k6 run k6_local_test.js --out json="$RESULTS_DIR/medium_test.json" --summary-export="$RESULTS_DIR/medium_summary.json"
    
    log $YELLOW "   📊 Teste 3: Carga pesada (${VUS_HEAVY:-100} usuários, ${DURATION_HEAVY:-30s})"
    VUS=${VUS_HEAVY:-100} DURATION=${DURATION_HEAVY:-30s} API_URL=http://localhost:8000 SLEEP=0.5 \
        k6 run k6_local_test.js --out json="$RESULTS_DIR/heavy_test.json" --summary-export="$RESULTS_DIR/heavy_summary.json"
    
    log $GREEN "✅ Todos os testes locais concluídos!"
    log $BLUE "📁 Resultados detalhados salvos em: $RESULTS_DIR"
    
    # Gerar relatório consolidado
    log $YELLOW "   📄 Gerando relatório consolidado..."
    generate_local_report "$RESULTS_DIR"
    
    # Analisar resultados se Python estiver disponível
    if command -v python3 &> /dev/null; then
        log $YELLOW "   📈 Gerando análise Python..."
        python3 analyze_results.py "$RESULTS_DIR" 2>/dev/null || log $YELLOW "   ⚠️  Análise Python não disponível"
        
        # Analisar métricas de sistema se disponíveis
        if [ -f "analyze_system_metrics.py" ] && [ -d "$RESULTS_DIR" ]; then
            log $YELLOW "   🔧 Analisando métricas de sistema..."
            python3 analyze_system_metrics.py "$RESULTS_DIR" 2>/dev/null || log $YELLOW "   ⚠️  Análise de sistema não disponível"
        fi
    fi
    
    log $GREEN "🎉 Teste local finalizado com sucesso!"
    log $BLUE "   Abra $RESULTS_DIR/report.txt para ver o relatório completo"
    
    exit 0
}

# Função para gerar relatório consolidado local
generate_local_report() {
    local results_dir=$1
    local report_file="$results_dir/report.txt"
    
    {
        echo "🌍 RELATÓRIO DE TESTE LOCAL - $(date)"
        echo "=========================================="
        echo ""
        
        for test_type in light medium heavy; do
            local summary_file="$results_dir/${test_type}_summary.json"
            if [ -f "$summary_file" ]; then
                echo "📊 TESTE ${test_type^^}:"
                echo "----------------------------------------"
                
                # Extrair métricas principais usando jq se disponível, senão grep
                if command -v jq &> /dev/null; then
                    local reqs=$(jq -r '.metrics.http_reqs.values.count // 0' "$summary_file")
                    local fail_rate=$(jq -r '(.metrics.http_req_failed.values.rate // 0) * 100' "$summary_file")
                    local avg_duration=$(jq -r '.metrics.http_req_duration.values.avg // 0' "$summary_file")
                    local p95_duration=$(jq -r '.metrics.http_req_duration.values["p(95)"] // 0' "$summary_file")
                    
                    printf "Total de requisições: %s\n" "$reqs"
                    printf "Taxa de erro: %.2f%%\n" "$fail_rate"
                    printf "Tempo médio: %.2fms\n" "$avg_duration"
                    printf "P95: %.2fms\n" "$p95_duration"
                else
                    echo "Arquivo de métricas: $summary_file"
                fi
                echo ""
            fi
        done
        
        echo "✅ Teste concluído com sucesso!"
        echo "📁 Arquivos gerados:"
        find "$results_dir" -name "*.json" -exec basename {} \; | sed 's/^/   - /'
        
    } > "$report_file"
    
    log $GREEN "✅ Relatório gerado: $report_file"
}

# Se modo local, executar teste local
if [ "$LOCAL_MODE" = true ]; then
    run_local_test
fi

if [ ! -f "$CONFIG_FILE" ]; then
    log $RED "❌ Arquivo de configuração não encontrado: $CONFIG_FILE"
    log $YELLOW "   Execute: cp config.env.example config.env"
    log $YELLOW "   E preencha as configurações necessárias"
    exit 1
fi

log $BLUE "📋 Carregando configurações..."
source $CONFIG_FILE

validate_config() {
    local errors=0
    
    if [ ! -f "$AWS_KEY_PATH" ]; then
        log $RED "❌ Chave SSH não encontrada: $AWS_KEY_PATH"
        errors=$((errors + 1))
    fi
    
    if [ -z "$EC2_BRAZIL" ] || [ -z "$EC2_USA" ] || [ -z "$EC2_CHINA" ]; then
        log $RED "❌ IPs das instâncias EC2 não configurados"
        errors=$((errors + 1))
    fi
    
    if [ -z "$API_URL_BRAZIL" ] || [ -z "$API_URL_USA" ] || [ -z "$API_URL_CHINA" ]; then
        log $RED "❌ URLs da API não configuradas"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        log $RED "❌ Corrija as configurações em $CONFIG_FILE antes de continuar"
        exit 1
    fi
    
    log $GREEN "✅ Configurações validadas"
}

check_connectivity() {
    log $BLUE "📡 Verificando conectividade..."
    
    declare -A instances=(
        ["brazil"]="$SSH_USER@$EC2_BRAZIL"
        ["usa"]="$SSH_USER@$EC2_USA"
        ["china"]="$SSH_USER@$EC2_CHINA"
    )
    
    for region in "${!instances[@]}"; do
        instance="${instances[$region]}"
        log $YELLOW "   Testando $region ($instance)..."
        
        if ssh -i "$AWS_KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$instance" "echo 'OK'" > /dev/null 2>&1; then
            log $GREEN "   ✅ $region: Conectado"
        else
            log $RED "   ❌ $region: Falha na conexão"
            log $YELLOW "      Verifique: IP, chave SSH, security groups"
            exit 1
        fi
    done
}

install_k6() {
    log $BLUE "🔧 Instalando k6 nas instâncias..."
    
    declare -A instances=(
        ["brazil"]="$SSH_USER@$EC2_BRAZIL"
        ["usa"]="$SSH_USER@$EC2_USA"
        ["china"]="$SSH_USER@$EC2_CHINA"
    )
    
    for region in "${!instances[@]}"; do
        instance="${instances[$region]}"
        log $YELLOW "   Instalando k6 em $region..."
        
        ssh -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no "$instance" "
            # Verificar se k6 já está instalado
            if command -v k6 &> /dev/null; then
                echo 'k6 já instalado'
                k6 version
            else
                echo 'Instalando k6...'
                sudo apt-get update -y > /dev/null 2>&1
                sudo snap install k6 > /dev/null 2>&1
                echo 'k6 instalado com sucesso'
                k6 version
            fi
        " &
    done
    
    wait
    log $GREEN "✅ k6 instalado em todas as instâncias"
}

generate_k6_script() {
    local scenario=$1
    
    cat > k6_dynamic_test.js << EOF
import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Métricas customizadas
export let feedRequestsTotal = new Counter('feed_requests_total');
export let feedErrorRate = new Rate('feed_error_rate');
export let feedResponseTime = new Trend('feed_response_time');

// Configuração do teste
export let options = {
    stages: [
        { duration: '2m', target: Math.floor($VUS_PER_REGION * 0.4) },
        { duration: '5m', target: $VUS_PER_REGION },
        { duration: '${TEST_DURATION}', target: $VUS_PER_REGION },
        { duration: '2m', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<${RESPONSE_TIME_THRESHOLD}'],
        http_req_failed: ['rate<0.$(echo "scale=2; $ERROR_RATE_THRESHOLD/100" | bc)'],
    },
};

// URLs por cenário
const SERVERS = {
    'unsharded': {
        'brazil': '$API_URL_CENTRAL',
        'usa': '$API_URL_CENTRAL', 
        'china': '$API_URL_CENTRAL'
    },
    'sharded': {
        'brazil': '$API_URL_BRAZIL',
        'usa': '$API_URL_USA',
        'china': '$API_URL_CHINA'
    }
};

// IDs de usuários por região
const USER_IDS = {
    'brazil': Array.from({length: $SYNTHETIC_USERS_PER_REGION}, (_, i) => \`${USER_PREFIX_BRAZIL}_\${i + 1}\`),
    'usa': Array.from({length: $SYNTHETIC_USERS_PER_REGION}, (_, i) => \`${USER_PREFIX_USA}_\${i + 1}\`),
    'china': Array.from({length: $SYNTHETIC_USERS_PER_REGION}, (_, i) => \`${USER_PREFIX_CHINA}_\${i + 1}\`)
};

const SCENARIO = __ENV.SCENARIO || '$scenario';
const REGION = __ENV.REGION || 'brazil';
const BASE_URL = SERVERS[SCENARIO][REGION];
const REGION_USER_IDS = USER_IDS[REGION];

export default function () {
    const user_id = REGION_USER_IDS[Math.floor(Math.random() * REGION_USER_IDS.length)];
    
    const startTime = Date.now();
    const response = http.get(\`\${BASE_URL}/feed?user_id=\${user_id}\`, {
        headers: {
            'User-Agent': \`k6-loadtest-\${REGION}-\${SCENARIO}\`,
            'X-Region': REGION,
            'X-Scenario': SCENARIO
        },
        timeout: '30s'
    });
    
    const responseTime = Date.now() - startTime;
    
    feedRequestsTotal.add(1);
    feedResponseTime.add(responseTime);
    
    const isSuccess = check(response, {
        'status is 200': (r) => r.status === 200,
        'response time ok': (r) => r.timings.duration < $RESPONSE_TIME_THRESHOLD,
        'has posts array': (r) => {
            try {
                const body = JSON.parse(r.body);
                return Array.isArray(body) && body.length <= 20;
            } catch (e) {
                return false;
            }
        }
    });
    
    if (!isSuccess) {
        feedErrorRate.add(1);
    }
    
    sleep(Math.random() * $(echo "$SLEEP_BETWEEN_REQUESTS" | cut -d'-' -f2) + $(echo "$SLEEP_BETWEEN_REQUESTS" | cut -d'-' -f1));
}

export function handleSummary(data) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    return {
        [\`k6-summary-\${REGION}-\${SCENARIO}-\${timestamp}.json\`]: JSON.stringify(data, null, 2),
    };
}
EOF
}

deploy_scripts() {
    log $BLUE "📁 Enviando scripts para as instâncias..."
    
    declare -A instances=(
        ["brazil"]="$SSH_USER@$EC2_BRAZIL"
        ["usa"]="$SSH_USER@$EC2_USA"
        ["china"]="$SSH_USER@$EC2_CHINA"
    )
    
    for region in "${!instances[@]}"; do
        instance="${instances[$region]}"
        log $YELLOW "   Enviando para $region..."
        scp -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no k6_dynamic_test.js "$instance":~/ > /dev/null
    done
    
    log $GREEN "✅ Scripts enviados"
}

run_test() {
    local scenario=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    log $BLUE "🚀 Executando teste: $scenario"
    
    declare -A instances=(
        ["brazil"]="$SSH_USER@$EC2_BRAZIL"
        ["usa"]="$SSH_USER@$EC2_USA"  
        ["china"]="$SSH_USER@$EC2_CHINA"
    )
    
    log $YELLOW "📊 Enviando script de monitoramento..."
    for region in "${!instances[@]}"; do
        instance="${instances[$region]}"
        scp -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no monitor_resources.sh "$instance":~/ > /dev/null
    done
    
    for region in "${!instances[@]}"; do
        instance="${instances[$region]}"
        log $YELLOW "   Iniciando teste + monitoramento em $region..."
        
        ssh -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no "$instance" "
            export REGION=$region
            export SCENARIO=$scenario
            
            # Iniciar monitoramento de recursos
            chmod +x monitor_resources.sh
            nohup ./monitor_resources.sh $region $TEST_DURATION ./monitoring > monitoring_${region}_${scenario}_${timestamp}.log 2>&1 &
            echo \$! > monitoring_pid_${region}_${scenario}.txt
            
            # Aguardar 5 segundos para monitoramento inicializar
            sleep 5
            
            # Iniciar teste k6
            nohub k6 run --env REGION=$region --env SCENARIO=$scenario k6_dynamic_test.js > k6_output_${region}_${scenario}_${timestamp}.log 2>&1 &
            echo \$! > k6_pid_${region}_${scenario}.txt
        " &
    done
    
    log $YELLOW "⏳ Aguardando conclusão dos testes..."
    wait
    
    sleep 10
    
    log $BLUE "📊 Verificando status dos testes..."
    for region in "${!instances[@]}"; do
        instance="${instances[$region]}"
        status=$(ssh -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no "$instance" "
            if [ -f k6_pid_${region}_${scenario}.txt ]; then
                pid=\$(cat k6_pid_${region}_${scenario}.txt)
                if ps -p \$pid > /dev/null 2>&1; then
                    echo 'RUNNING'
                else
                    echo 'COMPLETED'
                fi
            else
                echo 'UNKNOWN'
            fi
        ")
        
        case $status in
            "RUNNING") log $YELLOW "   🟡 $region: Em execução" ;;
            "COMPLETED") log $GREEN "   ✅ $region: Concluído" ;;
            *) log $RED "   ❓ $region: Status desconhecido" ;;
        esac
    done
}

collect_results() {
    local scenario=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local results_dir="${RESULTS_BASE_DIR}/results_${scenario}_${timestamp}"
    
    log $BLUE "📥 Coletando resultados..."
    mkdir -p "$results_dir"
    
    declare -A instances=(
        ["brazil"]="$SSH_USER@$EC2_BRAZIL"
        ["usa"]="$SSH_USER@$EC2_USA"
        ["china"]="$SSH_USER@$EC2_CHINA"
    )
    
    for region in "${!instances[@]}"; do
        instance="${instances[$region]}"
        log $YELLOW "   Coletando de $region..."
        
        scp -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no "$instance":~/k6-summary-*.json "$results_dir/" 2>/dev/null || true
        scp -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no "$instance":~/k6_output_${region}_*.log "$results_dir/" 2>/dev/null || true
        
        log $YELLOW "   📊 Coletando métricas de sistema de $region..."
        scp -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no -r "$instance":~/monitoring/ "$results_dir/monitoring_${region}/" 2>/dev/null || true
        scp -i "$AWS_KEY_PATH" -o StrictHostKeyChecking=no "$instance":~/monitoring_*.log "$results_dir/" 2>/dev/null || true
    done
    
    log $GREEN "✅ Resultados coletados em: $results_dir"
    
    if [ "$GENERATE_CHARTS" = "true" ] && [ -f "analyze_results.py" ]; then
        log $BLUE "📊 Gerando análise automática..."
        python3 analyze_results.py "$results_dir"
        
        if [ -f "analyze_system_metrics.py" ]; then
            log $BLUE "🖥️  Analisando métricas de sistema..."
            python3 analyze_system_metrics.py "$results_dir"
        fi
    fi
    
    echo "$results_dir"
}

main() {
    log $GREEN "🎯 Iniciando Sistema de Testes K6 Distribuídos"
    log $BLUE "📅 $(date)"
    log $BLUE "🎭 Cenário: $SCENARIO"
    
    validate_config
    check_connectivity
    install_k6
    
    if [ "$SCENARIO" = "both" ]; then
        log $GREEN "\n🔹 EXECUTANDO CENÁRIO UNSHARDED"
        generate_k6_script "unsharded"
        deploy_scripts
        run_test "unsharded"
        unsharded_results=$(collect_results "unsharded")
        
        log $YELLOW "⏸️  Aguardando 5 minutos entre cenários..."
        sleep 300
        
        log $GREEN "\n🔹 EXECUTANDO CENÁRIO SHARDED"
        generate_k6_script "sharded"
        deploy_scripts
        run_test "sharded"
        sharded_results=$(collect_results "sharded")
        
        if [ -f "analyze_results.py" ]; then
            log $BLUE "🔄 Gerando comparação entre cenários..."
            python3 analyze_results.py "$unsharded_results" "$sharded_results"
        fi
        
    else
        generate_k6_script "$SCENARIO"
        deploy_scripts
        run_test "$SCENARIO"
        collect_results "$SCENARIO"
    fi
    
    log $GREEN "🎉 Teste distribuído concluído com sucesso!"
    log $BLUE "📁 Resultados salvos em: $RESULTS_BASE_DIR"
}

main
