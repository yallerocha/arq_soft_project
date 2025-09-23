#!/bin/bash

# Script rápido para testes locais
# Uso: ./quick_test.sh [light|medium|heavy|all]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${1}${2}${NC}"
}

TEST_TYPE=${1:-"light"}

# Verificar se mock server está rodando
if ! curl -s http://localhost:8000/feed?user_id=test > /dev/null 2>&1; then
    log $RED "❌ Mock server não está rodando!"
    log $YELLOW "Execute: node mock_server.js"
    exit 1
fi

# Verificar K6
if ! command -v k6 &> /dev/null; then
    log $RED "❌ K6 não instalado!"
    log $YELLOW "Execute: sudo apt install k6"
    exit 1
fi

log $GREEN "✅ Tudo pronto! Iniciando teste..."

case $TEST_TYPE in
    "light")
        log $BLUE "🔥 Teste LEVE: 10 usuários por 30 segundos"
        k6 run k6_local_test.js -e VUS=10 -e DURATION=30s -e API_URL=http://localhost:8000
        ;;
    "medium")
        log $BLUE "🔥 Teste MÉDIO: 50 usuários por 60 segundos"
        k6 run k6_local_test.js -e VUS=50 -e DURATION=60s -e API_URL=http://localhost:8000
        ;;
    "heavy")
        log $BLUE "🔥 Teste PESADO: 100 usuários por 30 segundos"
        k6 run k6_local_test.js -e VUS=100 -e DURATION=30s -e API_URL=http://localhost:8000 -e SLEEP=0.5
        ;;
    "all")
        log $BLUE "🔥 BATERIA COMPLETA de testes!"
        
        log $YELLOW "   Teste 1/3: Leve..."
        k6 run k6_local_test.js -e VUS=10 -e DURATION=30s -e API_URL=http://localhost:8000
        
        log $YELLOW "   Teste 2/3: Médio..."
        k6 run k6_local_test.js -e VUS=50 -e DURATION=60s -e API_URL=http://localhost:8000
        
        log $YELLOW "   Teste 3/3: Pesado..."
        k6 run k6_local_test.js -e VUS=100 -e DURATION=30s -e API_URL=http://localhost:8000 -e SLEEP=0.5
        ;;
    "basic")
        log $BLUE "🔥 Teste BÁSICO: usando script k6_feed_test.js original"
        k6 run k6_feed_test.js --duration 30s --vus 10
        ;;
    *)
        log $RED "❌ Tipo de teste inválido!"
        log $YELLOW "Uso: ./quick_test.sh [light|medium|heavy|all|basic]"
        log $YELLOW ""
        log $YELLOW "Opções:"
        log $YELLOW "  light  - 10 usuários, 30s (recomendado para começar)"
        log $YELLOW "  medium - 50 usuários, 60s"
        log $YELLOW "  heavy  - 100 usuários, 30s"
        log $YELLOW "  all    - Executa todos os testes acima"
        log $YELLOW "  basic  - Teste simples com script k6_feed_test.js"
        exit 1
        ;;
esac

log $GREEN "🎉 Teste concluído!"
