#!/bin/bash

# Script para testar com servidores reais ao invés de simulação
# Uso: ./test_real_servers.sh [light|medium|heavy] [brasil_url] [usa_url] [tokyo_url]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${1}${2}${NC}"
}

# Parâmetros
TEST_TYPE=${1:-"medium"}
BRASIL_URL=${2:-""}
USA_URL=${3:-""}
TOKYO_URL=${4:-""}

# Verificar K6
if ! command -v k6 &> /dev/null; then
    log $RED "❌ K6 não instalado!"
    log $YELLOW "Execute: sudo apt install k6"
    exit 1
fi

# Função de ajuda
show_help() {
    echo
    log $CYAN "🌍 TESTE COM SERVIDORES REAIS"
    log $CYAN "============================="
    echo
    log $YELLOW "Uso:"
    log $YELLOW "  ./test_real_servers.sh [tipo] [url_br] [url_usa] [url_tokyo]"
    echo
    log $YELLOW "Exemplos:"
    log $GREEN "  # Usando URLs diretas:"
    log $GREEN "  ./test_real_servers.sh medium \\"
    log $GREEN "    http://15.228.71.189 \\"
    log $GREEN "    http://54.166.96.217 \\"
    log $GREEN "    http://52.196.245.151"
    echo
    log $GREEN "  # Usando config.env (recomendado):"
    log $GREEN "  cp config.real-servers.env config.env"
    log $GREEN "  # Edite config.env com suas URLs reais"
    log $GREEN "  ./test_real_servers.sh medium"
    echo
    log $YELLOW "Tipos de teste: light, medium, heavy"
    echo
}

# Se não tem URLs nem config.env, mostrar ajuda
if [ -z "$BRASIL_URL" ] && [ ! -f "config.env" ]; then
    log $RED "❌ URLs dos servidores não fornecidas!"
    show_help
    exit 1
fi

# Carregar config.env se existir
if [ -f "config.env" ]; then
    log $BLUE "📋 Carregando config.env..."
    source config.env
    
    # Usar URLs do config.env se não foram passadas via parâmetro
    BRASIL_URL=${BRASIL_URL:-$API_URL_BRAZIL}
    USA_URL=${USA_URL:-$API_URL_USA}
    TOKYO_URL=${TOKYO_URL:-$API_URL_CHINA}
fi

# Validar se temos todas as URLs
if [ -z "$BRASIL_URL" ] || [ -z "$USA_URL" ] || [ -z "$TOKYO_URL" ]; then
    log $RED "❌ URLs incompletas!"
    log $YELLOW "Brasil: $BRASIL_URL"
    log $YELLOW "EUA: $USA_URL"
    log $YELLOW "Tóquio: $TOKYO_URL"
    show_help
    exit 1
fi

log $CYAN "🌍 INICIANDO TESTES COM SERVIDORES REAIS"
log $CYAN "========================================"
log $BLUE "📅 Data/Hora: $(date)"
log $BLUE "🎯 Tipo de teste: $TEST_TYPE"
log $BLUE "🇧🇷 Brasil: $BRASIL_URL"
log $BLUE "🇺🇸 EUA: $USA_URL"
log $BLUE "🗾 Tóquio: $TOKYO_URL"
echo

# Configurar parâmetros do teste
case $TEST_TYPE in
    "light")
        VUS=5
        DURATION="30s"
        ;;
    "medium")
        VUS=10
        DURATION="60s"
        ;;
    "heavy")
        VUS=20
        DURATION="90s"
        ;;
    *)
        log $RED "❌ Tipo de teste inválido!"
        log $YELLOW "Use: light, medium ou heavy"
        exit 1
        ;;
esac

# Criar diretório para resultados
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="test_results/real_servers_${TIMESTAMP}"
mkdir -p $RESULTS_DIR

log $BLUE "📁 Resultados salvos em: $RESULTS_DIR"
echo

# ===========================================
# TESTE 1: BRASIL
# ===========================================
log $GREEN "🇧🇷 TESTE 1/3: BRASIL"
log $BLUE "   URL: $BRASIL_URL"
log $BLUE "   VUs: $VUS | Duração: $DURATION"
echo

k6 run k6_brasil_test.js \
    -e VUS=$VUS \
    -e DURATION=$DURATION \
    -e BASE_URL="$BRASIL_URL" \
    --out json="$RESULTS_DIR/brasil_results.json" \
    > "$RESULTS_DIR/brasil_output.txt" 2>&1 || true

if [ -f "summary.json" ]; then
    cp "summary.json" "$RESULTS_DIR/brasil_summary.json"
fi

log $GREEN "✅ Teste Brasil concluído!"
sleep 3

# ===========================================
# TESTE 2: EUA
# ===========================================
log $BLUE "🇺🇸 TESTE 2/3: EUA"
log $BLUE "   URL: $USA_URL"
log $BLUE "   VUs: $VUS | Duração: $DURATION"
echo

k6 run k6_usa_test.js \
    -e VUS=$VUS \
    -e DURATION=$DURATION \
    -e BASE_URL="$USA_URL" \
    --out json="$RESULTS_DIR/usa_results.json" \
    > "$RESULTS_DIR/usa_output.txt" 2>&1 || true

if [ -f "summary.json" ]; then
    cp "summary.json" "$RESULTS_DIR/usa_summary.json"
fi

log $GREEN "✅ Teste EUA concluído!"
sleep 3

# ===========================================
# TESTE 3: TÓQUIO
# ===========================================
log $PURPLE "🗾 TESTE 3/3: TÓQUIO"
log $BLUE "   URL: $TOKYO_URL"
log $BLUE "   VUs: $VUS | Duração: $DURATION"
echo

k6 run k6_tokyo_test.js \
    -e VUS=$VUS \
    -e DURATION=$DURATION \
    -e BASE_URL="$TOKYO_URL" \
    --out json="$RESULTS_DIR/tokyo_results.json" \
    > "$RESULTS_DIR/tokyo_output.txt" 2>&1 || true

if [ -f "summary.json" ]; then
    cp "summary.json" "$RESULTS_DIR/tokyo_summary.json"
fi

log $GREEN "✅ Teste Tóquio concluído!"
echo

# ===========================================
# ANÁLISE DOS RESULTADOS
# ===========================================
log $CYAN "📊 ANALISANDO RESULTADOS..."
echo

# Verificar se Python e pandas estão disponíveis
if command -v python3 &> /dev/null && python3 -c "import pandas" 2>/dev/null; then
    python3 analyze_results.py "$RESULTS_DIR"
else
    log $YELLOW "⚠️  Python/pandas não disponível para análise automática"
    log $YELLOW "   Resultados disponíveis em: $RESULTS_DIR"
fi

log $CYAN "🎉 TESTES CONCLUÍDOS!"
log $CYAN "==================="
log $BLUE "📁 Todos os resultados: $RESULTS_DIR"
log $BLUE "📊 Summaries individuais:"
log $BLUE "   🇧🇷 Brasil: $RESULTS_DIR/brasil_summary.json"
log $BLUE "   🇺🇸 EUA: $RESULTS_DIR/usa_summary.json" 
log $BLUE "   🗾 Tóquio: $RESULTS_DIR/tokyo_summary.json"
echo
