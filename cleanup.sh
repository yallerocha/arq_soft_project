#!/bin/bash

# Script para limpeza de arquivos temporários e órfãos
# Uso: ./cleanup.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${1}${2}${NC}"
}

log $YELLOW "🧹 Limpando arquivos temporários..."

# Remover arquivos temporários do K6
rm -f k6_dynamic_test.js 2>/dev/null
rm -f k6_pid_*.txt 2>/dev/null
rm -f k6_output_*.log 2>/dev/null

# Remover arquivos de resumo órfãos
rm -f summary.json 2>/dev/null

# Limpar resultados antigos (opcional - manter apenas últimos 5)
if [ -d "test_results" ]; then
    cd test_results
    # Manter apenas os 5 diretórios mais recentes
    ls -dt */ 2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null
    cd ..
    log $GREEN "✅ Resultados antigos limpos (mantidos últimos 5)"
fi

# Remover node_modules se muito grande (opcional)
if [ -d "node_modules" ]; then
    size=$(du -sm node_modules | cut -f1)
    if [ "$size" -gt 100 ]; then
        log $YELLOW "📦 node_modules é grande (${size}MB). Recriar com 'npm install' se necessário"
    fi
fi

log $GREEN "✅ Limpeza concluída!"
log $YELLOW "💡 Para reinstalar dependências: npm install"
