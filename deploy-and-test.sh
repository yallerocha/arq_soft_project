#!/bin/bash

# Script para automação completa do teste distribuído
# Uso: ./deploy-and-test.sh [unsharded|sharded]

set -e

SCENARIO=$1
if [ -z "$SCENARIO" ]; then
    echo "Uso: ./deploy-and-test.sh [unsharded|sharded]"
    exit 1
fi

echo "🚀 Iniciando deployment e teste distribuído - Cenário: $SCENARIO"

# Configuração
KEY_PATH="sua-chave.pem"
REGIONS=("brazil" "usa" "china")
INSTANCES=(
    "ubuntu@ec2-brazil.amazonaws.com"
    "ubuntu@ec2-usa.amazonaws.com" 
    "ubuntu@ec2-china.amazonaws.com"
)

echo "📡 Verificando conectividade com as instâncias..."
for i in "${!INSTANCES[@]}"; do
    region="${REGIONS[$i]}"
    instance="${INSTANCES[$i]}"
    echo "Testando $region ($instance)..."
    if ssh -i $KEY_PATH -o ConnectTimeout=10 $instance "echo 'OK'" > /dev/null 2>&1; then
        echo "✅ $region: Conectado"
    else
        echo "❌ $region: Falha na conexão"
        exit 1
    fi
done

echo "📁 Copiando scripts de teste..."
for instance in "${INSTANCES[@]}"; do
    scp -i $KEY_PATH k6_distributed_test.js $instance:~/
done

echo "🏃 Executando testes em paralelo..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

for i in "${!INSTANCES[@]}"; do
    region="${REGIONS[$i]}"
    instance="${INSTANCES[$i]}"
    
    echo "Iniciando teste na região: $region"
    ssh -i $KEY_PATH $instance "
        export REGION=$region
        export SCENARIO=$SCENARIO
        nohup k6 run --env REGION=$region --env SCENARIO=$SCENARIO k6_distributed_test.js > k6_output_${region}_${TIMESTAMP}.log 2>&1 &
        echo \$! > k6_pid_${region}.txt
    " &
done

echo "⏳ Aguardando conclusão dos testes..."
wait

echo "📊 Verificando status dos testes..."
sleep 5

for i in "${!INSTANCES[@]}"; do
    region="${REGIONS[$i]}"
    instance="${INSTANCES[$i]}"
    
    echo "Status $region:"
    ssh -i $KEY_PATH $instance "
        if [ -f k6_pid_${region}.txt ]; then
            pid=\$(cat k6_pid_${region}.txt)
            if ps -p \$pid > /dev/null; then
                echo '🟡 Em execução (PID: '\$pid')'
            else
                echo '✅ Concluído'
            fi
        else
            echo '❓ Status desconhecido'
        fi
    "
done

echo "📥 Coletando resultados..."
RESULTS_DIR="results_${SCENARIO}_${TIMESTAMP}"
mkdir -p $RESULTS_DIR

for i in "${!INSTANCES[@]}"; do
    region="${REGIONS[$i]}"
    instance="${INSTANCES[$i]}"
    
    echo "Coletando de $region..."
    scp -i $KEY_PATH $instance:~/k6-summary-*.json $RESULTS_DIR/ 2>/dev/null || true
    scp -i $KEY_PATH $instance:~/k6_output_${region}_*.log $RESULTS_DIR/ 2>/dev/null || true
done

echo "✅ Teste distribuído concluído!"
echo "📁 Resultados salvos em: $RESULTS_DIR"

echo "📈 Resumo dos resultados:"
echo "========================"
for json_file in $RESULTS_DIR/k6-summary-*.json; do
    if [ -f "$json_file" ]; then
        region=$(basename "$json_file" | cut -d'-' -f3)
        echo "Região: $region"
        jq -r '.metrics.http_reqs.values.count as $total | .metrics.http_req_failed.values.rate as $error_rate | .metrics.http_req_duration.values.avg as $avg_duration | "  Total Requests: \($total)\n  Error Rate: \(($error_rate * 100) | tostring + "%")\n  Avg Response Time: \(($avg_duration) | tostring + "ms")"' "$json_file" 2>/dev/null || echo "  Erro ao processar arquivo"
        echo ""
    fi
done
