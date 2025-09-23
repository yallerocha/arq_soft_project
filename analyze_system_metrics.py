#!/usr/bin/env python3
"""
Script para análise das métricas de sistema (CPU, memória, I/O, rede)
coletadas durante os testes k6
"""

import os
import sys
import re
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime
import glob

def parse_sar_cpu_memory(file_path):
    """Parse do arquivo SAR para CPU e memória"""
    
    if not os.path.exists(file_path):
        return None, None
    
    cpu_data = []
    memory_data = []
    current_section = None
    
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            
            if 'CPU' in line and '%user' in line:
                current_section = 'cpu'
                continue
            elif 'kbmemfree' in line or 'memfree' in line:
                current_section = 'memory'
                continue
            elif line.startswith('Average:'):
                current_section = None
                continue
            
            if current_section == 'cpu' and re.match(r'^\d{2}:\d{2}:\d{2}', line):
                parts = line.split()
                if len(parts) >= 7:
                    try:
                        cpu_data.append({
                            'time': parts[0],
                            'cpu': parts[1] if parts[1] != 'all' else 'all',
                            'user': float(parts[2]),
                            'nice': float(parts[3]),
                            'system': float(parts[4]),
                            'iowait': float(parts[5]),
                            'steal': float(parts[6]),
                            'idle': float(parts[7])
                        })
                    except (ValueError, IndexError):
                        continue
            
            elif current_section == 'memory' and re.match(r'^\d{2}:\d{2}:\d{2}', line):
                parts = line.split()
                if len(parts) >= 9:
                    try:
                        memory_data.append({
                            'time': parts[0],
                            'memfree': float(parts[1]),
                            'memused': float(parts[2]),
                            'memused_pct': float(parts[3]),
                            'buffers': float(parts[4]),
                            'cached': float(parts[5]),
                            'commit': float(parts[6]),
                            'commit_pct': float(parts[7]),
                            'active': float(parts[8]) if len(parts) > 8 else 0,
                            'inactive': float(parts[9]) if len(parts) > 9 else 0
                        })
                    except (ValueError, IndexError):
                        continue
    
    return pd.DataFrame(cpu_data), pd.DataFrame(memory_data)

def parse_iostat(file_path):
    """Parse do arquivo iostat"""
    
    if not os.path.exists(file_path):
        return None
    
    io_data = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    sections = re.split(r'\n\n+', content)
    
    for section in sections:
        lines = section.strip().split('\n')
        if len(lines) < 2:
            continue
            
        header_idx = -1
        for i, line in enumerate(lines):
            if 'Device' in line and 'r/s' in line:
                header_idx = i
                break
        
        if header_idx == -1:
            continue
            
        headers = lines[header_idx].split()
        
        for line in lines[header_idx + 1:]:
            if not line.strip():
                continue
                
            parts = line.split()
            if len(parts) >= len(headers):
                try:
                    row = {'device': parts[0]}
                    for i, header in enumerate(headers[1:], 1):
                        if i < len(parts):
                            row[header] = float(parts[i])
                    io_data.append(row)
                except (ValueError, IndexError):
                    continue
    
    return pd.DataFrame(io_data)

def parse_system_metrics(file_path):
    """Parse do arquivo CSV com métricas do sistema"""
    
    if not os.path.exists(file_path):
        return None
    
    try:
        df = pd.read_csv(file_path)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        return df
    except Exception as e:
        print(f"Erro ao ler {file_path}: {e}")
        return None

def analyze_region_metrics(region_dir, region_name):
    """Analisa métricas de uma região específica"""
    
    print(f"\n📊 Analisando métricas da região: {region_name.upper()}")
    print("=" * 50)
    
    results = {
        'region': region_name,
        'cpu_avg': 0,
        'cpu_max': 0,
        'memory_avg_pct': 0,
        'memory_max_pct': 0,
        'io_read_avg': 0,
        'io_write_avg': 0,
        'load_avg': 0,
        'load_max': 0
    }
    
    sar_files = glob.glob(os.path.join(region_dir, 'cpu_memory_*.log'))
    for sar_file in sar_files:
        print(f"📈 Processando: {os.path.basename(sar_file)}")
        cpu_df, memory_df = parse_sar_cpu_memory(sar_file)
        
        if cpu_df is not None and not cpu_df.empty:
            cpu_all = cpu_df[cpu_df['cpu'] == 'all']
            if not cpu_all.empty:
                cpu_usage = 100 - cpu_all['idle']
                results['cpu_avg'] = cpu_usage.mean()
                results['cpu_max'] = cpu_usage.max()
                print(f"   CPU médio: {results['cpu_avg']:.2f}%")
                print(f"   CPU máximo: {results['cpu_max']:.2f}%")
        
        if memory_df is not None and not memory_df.empty:
            results['memory_avg_pct'] = memory_df['memused_pct'].mean()
            results['memory_max_pct'] = memory_df['memused_pct'].max()
            print(f"   Memória média: {results['memory_avg_pct']:.2f}%")
            print(f"   Memória máxima: {results['memory_max_pct']:.2f}%")
    
    io_files = glob.glob(os.path.join(region_dir, 'io_*.log'))
    for io_file in io_files:
        print(f"💾 Processando: {os.path.basename(io_file)}")
        io_df = parse_iostat(io_file)
        
        if io_df is not None and not io_df.empty:
            if 'r/s' in io_df.columns:
                results['io_read_avg'] = io_df['r/s'].sum()
            if 'w/s' in io_df.columns:
                results['io_write_avg'] = io_df['w/s'].sum()
            print(f"   I/O leitura avg: {results['io_read_avg']:.2f} r/s")
            print(f"   I/O escrita avg: {results['io_write_avg']:.2f} w/s")
    
    sys_files = glob.glob(os.path.join(region_dir, 'system_metrics_*.csv'))
    for sys_file in sys_files:
        print(f"🖥️  Processando: {os.path.basename(sys_file)}")
        sys_df = parse_system_metrics(sys_file)
        
        if sys_df is not None and not sys_df.empty:
            if 'load_1min' in sys_df.columns:
                results['load_avg'] = sys_df['load_1min'].mean()
                results['load_max'] = sys_df['load_1min'].max()
                print(f"   Load average: {results['load_avg']:.2f}")
                print(f"   Load máximo: {results['load_max']:.2f}")
    
    return results

def generate_system_charts(results_data, output_dir):
    """Gera gráficos das métricas de sistema"""
    
    try:
        df = pd.DataFrame(results_data)
        
        if df.empty:
            print("⚠️  Nenhum dado para gerar gráficos")
            return
        
        fig, axes = plt.subplots(2, 3, figsize=(18, 12))
        fig.suptitle('Métricas de Sistema por Região', fontsize=16)
        
        # CPU
        if 'cpu_avg' in df.columns:
            axes[0, 0].bar(df['region'], df['cpu_avg'], color='skyblue', alpha=0.7)
            axes[0, 0].bar(df['region'], df['cpu_max'], color='red', alpha=0.5, width=0.5)
            axes[0, 0].set_title('CPU Usage (%)')
            axes[0, 0].set_ylabel('CPU %')
            axes[0, 0].legend(['Médio', 'Máximo'])
            axes[0, 0].tick_params(axis='x', rotation=45)
        
        # Memória
        if 'memory_avg_pct' in df.columns:
            axes[0, 1].bar(df['region'], df['memory_avg_pct'], color='lightgreen', alpha=0.7)
            axes[0, 1].bar(df['region'], df['memory_max_pct'], color='orange', alpha=0.5, width=0.5)
            axes[0, 1].set_title('Memory Usage (%)')
            axes[0, 1].set_ylabel('Memory %')
            axes[0, 1].legend(['Médio', 'Máximo'])
            axes[0, 1].tick_params(axis='x', rotation=45)
        
        # Load Average
        if 'load_avg' in df.columns:
            axes[0, 2].bar(df['region'], df['load_avg'], color='gold', alpha=0.7)
            axes[0, 2].bar(df['region'], df['load_max'], color='red', alpha=0.5, width=0.5)
            axes[0, 2].set_title('Load Average')
            axes[0, 2].set_ylabel('Load')
            axes[0, 2].legend(['Médio', 'Máximo'])
            axes[0, 2].tick_params(axis='x', rotation=45)
        
        # I/O Read
        if 'io_read_avg' in df.columns:
            axes[1, 0].bar(df['region'], df['io_read_avg'], color='purple', alpha=0.7)
            axes[1, 0].set_title('Disk I/O - Read (r/s)')
            axes[1, 0].set_ylabel('Reads/sec')
            axes[1, 0].tick_params(axis='x', rotation=45)
        
        # I/O Write
        if 'io_write_avg' in df.columns:
            axes[1, 1].bar(df['region'], df['io_write_avg'], color='brown', alpha=0.7)
            axes[1, 1].set_title('Disk I/O - Write (w/s)')
            axes[1, 1].set_ylabel('Writes/sec')
            axes[1, 1].tick_params(axis='x', rotation=45)
        
        # Resumo geral
        if len(df) > 0:
            axes[1, 2].axis('off')
            summary_text = f"""
RESUMO GERAL
============
Regiões analisadas: {len(df)}

CPU médio geral: {df['cpu_avg'].mean():.2f}%
CPU máximo geral: {df['cpu_max'].max():.2f}%

Memória média geral: {df['memory_avg_pct'].mean():.2f}%
Memória máxima geral: {df['memory_max_pct'].max():.2f}%

Load médio geral: {df['load_avg'].mean():.2f}
            """
            axes[1, 2].text(0.1, 0.9, summary_text, transform=axes[1, 2].transAxes, 
                           fontsize=10, verticalalignment='top', fontfamily='monospace')
        
        plt.tight_layout()
        
        chart_path = os.path.join(output_dir, 'system_metrics_analysis.png')
        plt.savefig(chart_path, dpi=300, bbox_inches='tight')
        print(f"📊 Gráficos de sistema salvos em: {chart_path}")
        
        # Salvar dados em CSV
        csv_path = os.path.join(output_dir, 'system_metrics_summary.csv')
        df.to_csv(csv_path, index=False)
        print(f"💾 Resumo salvo em: {csv_path}")
        
    except Exception as e:
        print(f"⚠️  Erro ao gerar gráficos de sistema: {e}")

def analyze_system_metrics(results_dir):
    """Função principal para análise das métricas de sistema"""
    
    print(f"🖥️  Analisando métricas de sistema em: {results_dir}")
    print("=" * 60)
    
    monitoring_dirs = glob.glob(os.path.join(results_dir, 'monitoring_*'))
    
    if not monitoring_dirs:
        print("❌ Nenhum diretório de monitoramento encontrado")
        return
    
    results_data = []
    
    for mon_dir in monitoring_dirs:
        region_name = os.path.basename(mon_dir).replace('monitoring_', '')
        result = analyze_region_metrics(mon_dir, region_name)
        results_data.append(result)
    
    if results_data:
        generate_system_charts(results_data, results_dir)
        
        print(f"\n🎯 RESUMO FINAL")
        print("=" * 40)
        for result in results_data:
            print(f"📍 {result['region'].upper()}:")
            print(f"   CPU: {result['cpu_avg']:.1f}% (máx: {result['cpu_max']:.1f}%)")
            print(f"   Memória: {result['memory_avg_pct']:.1f}% (máx: {result['memory_max_pct']:.1f}%)")
            print(f"   Load: {result['load_avg']:.2f} (máx: {result['load_max']:.2f})")
    
    else:
        print("❌ Nenhum dado de sistema foi coletado")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 analyze_system_metrics.py <diretório_resultados>")
        sys.exit(1)
    
    try:
        import pandas as pd
        import matplotlib.pyplot as plt
    except ImportError:
        print("⚠️  Instalando dependências...")
        os.system("pip3 install pandas matplotlib")
        import pandas as pd
        import matplotlib.pyplot as plt
    
    analyze_system_metrics(sys.argv[1])
