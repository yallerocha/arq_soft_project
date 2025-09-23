#!/bin/bash

REGION=$1
DURATION=${2:-"30m"}
OUTPUT_DIR=${3:-"./monitoring"}

if [ -z "$REGION" ]; then
    echo "Uso: ./monitor_resources.sh <region> [duration] [output_dir]"
    echo "Exemplo: ./monitor_resources.sh brazil 30m ./monitoring"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

duration_to_seconds() {
    local duration=$1
    local number=$(echo $duration | grep -o '[0-9]*')
    local unit=$(echo $duration | grep -o '[a-z]*')
    
    case $unit in
        "s") echo $number ;;
        "m") echo $((number * 60)) ;;
        "h") echo $((number * 3600)) ;;
        *) echo 1800 ;; 
    esac
}

DURATION_SECONDS=$(duration_to_seconds $DURATION)

echo "🔍 Iniciando monitoramento de recursos para região: $REGION"
echo "⏱️  Duração: $DURATION ($DURATION_SECONDS segundos)"
echo "📁 Salvando em: $OUTPUT_DIR"

monitor_cpu_memory() {
    echo "📊 Iniciando monitoramento CPU/Memória..."
    
    sar -u -r 5 $((DURATION_SECONDS / 5)) > "$OUTPUT_DIR/cpu_memory_${REGION}_${TIMESTAMP}.log" &
    SAR_PID=$!
    
    (
        for i in $(seq 1 $((DURATION_SECONDS / 30))); do
            echo "=== TOP $(date) ===" >> "$OUTPUT_DIR/top_processes_${REGION}_${TIMESTAMP}.log"
            top -b -n 1 >> "$OUTPUT_DIR/top_processes_${REGION}_${TIMESTAMP}.log"
            sleep 30
        done
    ) &
    TOP_PID=$!
    
    echo "CPU/Memória: PIDs $SAR_PID, $TOP_PID"
}

monitor_network() {
    echo "🌐 Iniciando monitoramento de rede..."
    
    sar -n DEV 5 $((DURATION_SECONDS / 5)) > "$OUTPUT_DIR/network_${REGION}_${TIMESTAMP}.log" &
    NET_PID=$!
    
    (
        for i in $(seq 1 $((DURATION_SECONDS / 10))); do
            echo "=== NETSTAT $(date) ===" >> "$OUTPUT_DIR/connections_${REGION}_${TIMESTAMP}.log"
            netstat -tn | grep :8000 >> "$OUTPUT_DIR/connections_${REGION}_${TIMESTAMP}.log" 2>/dev/null || true
            ss -tn | grep :8000 >> "$OUTPUT_DIR/connections_${REGION}_${TIMESTAMP}.log" 2>/dev/null || true
            sleep 10
        done
    ) &
    CONN_PID=$!
    
    echo "Rede: PIDs $NET_PID, $CONN_PID"
}

monitor_io() {
    echo "💾 Iniciando monitoramento I/O..."
    
    iostat -x 5 $((DURATION_SECONDS / 5)) > "$OUTPUT_DIR/io_${REGION}_${TIMESTAMP}.log" &
    IO_PID=$!
    
    echo "I/O: PID $IO_PID"
}

monitor_k6_process() {
    echo "🎯 Iniciando monitoramento do processo k6..."
    
    (
        for i in $(seq 1 $((DURATION_SECONDS / 5))); do
            K6_PID=$(pgrep k6 | head -1)
            if [ ! -z "$K6_PID" ]; then
                echo "$(date),$(ps -p $K6_PID -o pid,ppid,pcpu,pmem,vsz,rss,time,cmd --no-headers)" >> "$OUTPUT_DIR/k6_process_${REGION}_${TIMESTAMP}.csv"
            fi
            sleep 5
        done
    ) &
    K6_MON_PID=$!
    
    echo "K6 Process: PID $K6_MON_PID"
}

monitor_system() {
    echo "🖥️  Iniciando monitoramento do sistema..."
    
    (
        echo "timestamp,load_1min,load_5min,load_15min,memory_used_mb,memory_free_mb,swap_used_mb" > "$OUTPUT_DIR/system_metrics_${REGION}_${TIMESTAMP}.csv"
        
        for i in $(seq 1 $((DURATION_SECONDS / 10))); do
            TIMESTAMP_NOW=$(date +"%Y-%m-%d %H:%M:%S")
            LOAD=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')
            MEMORY=$(free -m | awk 'NR==2{printf "%s,%s", $3,$4}')
            SWAP=$(free -m | awk 'NR==3{printf "%s", $3}')
            
            echo "$TIMESTAMP_NOW,$LOAD,$MEMORY,$SWAP" >> "$OUTPUT_DIR/system_metrics_${REGION}_${TIMESTAMP}.csv"
            sleep 10
        done
    ) &
    SYS_PID=$!
    
    echo "Sistema: PID $SYS_PID"
}

capture_system_info() {
    echo "📋 Capturando informações do sistema..."
    
    {
        echo "=== INFORMAÇÕES DO SISTEMA ==="
        echo "Data/Hora: $(date)"
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime)"
        echo ""
        
        echo "=== CPU INFO ==="
        lscpu
        echo ""
        
        echo "=== MEMÓRIA ==="
        free -h
        echo ""
        
        echo "=== DISCO ==="
        df -h
        echo ""
        
        echo "=== REDE ==="
        ip addr show
        echo ""
        
        echo "=== PROCESSOS ATIVOS ==="
        ps aux --sort=-%cpu | head -20
        
    } > "$OUTPUT_DIR/system_info_${REGION}_${TIMESTAMP}.txt"
}

cleanup() {
    echo ""
    echo "🛑 Parando monitoramento..."
    
    for pid in $SAR_PID $TOP_PID $NET_PID $CONN_PID $IO_PID $K6_MON_PID $SYS_PID; do
        if [ ! -z "$pid" ]; then
            kill $pid 2>/dev/null || true
        fi
    done
    
    echo "✅ Monitoramento finalizado"
    echo "📁 Arquivos salvos em: $OUTPUT_DIR"
    
    generate_summary
}

generate_summary() {
    echo "📊 Gerando resumo do monitoramento..."
    
    SUMMARY_FILE="$OUTPUT_DIR/monitoring_summary_${REGION}_${TIMESTAMP}.txt"
    
    {
        echo "=== RESUMO DO MONITORAMENTO ==="
        echo "Região: $REGION"
        echo "Duração: $DURATION"
        echo "Timestamp: $TIMESTAMP"
        echo "Data: $(date)"
        echo ""
        
        echo "=== ARQUIVOS GERADOS ==="
        ls -la "$OUTPUT_DIR"/*${REGION}_${TIMESTAMP}* 2>/dev/null || echo "Nenhum arquivo encontrado"
        echo ""
        
        echo "=== ESTATÍSTICAS RÁPIDAS ==="
        
        if [ -f "$OUTPUT_DIR/cpu_memory_${REGION}_${TIMESTAMP}.log" ]; then
            MAX_CPU=$(awk '/Average:/ && /all/ {print $3}' "$OUTPUT_DIR/cpu_memory_${REGION}_${TIMESTAMP}.log" | tail -1)
            echo "CPU médio: ${MAX_CPU}%"
        fi
        
        if [ -f "$OUTPUT_DIR/system_metrics_${REGION}_${TIMESTAMP}.csv" ]; then
            MAX_MEM=$(awk -F',' 'NR>1 {print $4}' "$OUTPUT_DIR/system_metrics_${REGION}_${TIMESTAMP}.csv" | sort -n | tail -1)
            echo "Memória máxima usada: ${MAX_MEM}MB"
        fi
        
        echo ""
        echo "=== FIM DO RESUMO ==="
        
    } > "$SUMMARY_FILE"
    
    echo "📄 Resumo salvo em: $SUMMARY_FILE"
}

trap cleanup INT TERM

check_tools() {
    local missing_tools=()
    
    for tool in sar iostat netstat ss; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "⚠️  Ferramentas faltando: ${missing_tools[@]}"
        echo "📦 Instalando ferramentas necessárias..."
        
        sudo apt-get update -y > /dev/null 2>&1
        sudo apt-get install -y sysstat net-tools > /dev/null 2>&1
        
        echo "✅ Ferramentas instaladas"
    fi
}

main() {
    check_tools
    capture_system_info
    
    monitor_cpu_memory
    monitor_network  
    monitor_io
    monitor_k6_process
    monitor_system
    
    echo ""
    echo "✅ Todos os monitoramentos iniciados"
    echo "⏱️  Aguardando $DURATION para finalizar..."
    echo "🛑 Pressione Ctrl+C para parar antecipadamente"
    
    sleep $DURATION_SECONDS
    
    cleanup
}

main
