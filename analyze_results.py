#!/usr/bin/env python3
"""
Script para análise dos resultados dos testes k6 distribuídos
"""

import json
import sys
import os
from datetime import datetime
import pandas as pd
import matplotlib.pyplot as plt

def analyze_k6_results(results_dir):
    """Analisa os resultados dos testes k6"""
    
    if not os.path.exists(results_dir):
        print(f"❌ Diretório não encontrado: {results_dir}")
        return
    
    print(f"📊 Analisando resultados em: {results_dir}")
    print("=" * 50)
    
    summary_files = []
    for file in os.listdir(results_dir):
        if file.startswith('k6-summary-') and file.endswith('.json'):
            summary_files.append(os.path.join(results_dir, file))
    
    if not summary_files:
        print("❌ Nenhum arquivo de resumo encontrado")
        return
    
    results = []
    
    for file_path in summary_files:
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            
            filename = os.path.basename(file_path)
            region = filename.split('-')[2] if len(filename.split('-')) > 2 else 'unknown'
            
            metrics = data.get('metrics', {})
            
            result = {
                'region': region,
                'total_requests': metrics.get('http_reqs', {}).get('values', {}).get('count', 0),
                'failed_requests': metrics.get('http_req_failed', {}).get('values', {}).get('rate', 0) * 100,
                'avg_duration': metrics.get('http_req_duration', {}).get('values', {}).get('avg', 0),
                'p95_duration': metrics.get('http_req_duration', {}).get('values', {}).get('p(95)', 0),
                'max_duration': metrics.get('http_req_duration', {}).get('values', {}).get('max', 0),
                'requests_per_sec': metrics.get('http_reqs', {}).get('values', {}).get('rate', 0)
            }
            
            results.append(result)
            
        except Exception as e:
            print(f"❌ Erro ao processar {file_path}: {e}")
    
    for result in results:
        print(f"\n🌍 Região: {result['region'].upper()}")
        print(f"   Total de Requisições: {result['total_requests']:,}")
        print(f"   Taxa de Erro: {result['failed_requests']:.2f}%")
        print(f"   Tempo Médio: {result['avg_duration']:.2f}ms")
        print(f"   95º Percentil: {result['p95_duration']:.2f}ms")
        print(f"   Tempo Máximo: {result['max_duration']:.2f}ms")
        print(f"   Requisições/seg: {result['requests_per_sec']:.2f}")
    
    df = pd.DataFrame(results)
    
    if len(df) > 0:
        print(f"\n📈 Resumo Estatístico:")
        print("=" * 30)
        print(f"Total Geral de Requisições: {df['total_requests'].sum():,}")
        print(f"Taxa Média de Erro: {df['failed_requests'].mean():.2f}%")
        print(f"Tempo Médio Geral: {df['avg_duration'].mean():.2f}ms")
        print(f"Throughput Total: {df['requests_per_sec'].sum():.2f} req/s")
        
        generate_charts(df, results_dir)
        
        csv_path = os.path.join(results_dir, 'analysis_summary.csv')
        df.to_csv(csv_path, index=False)
        print(f"💾 Análise salva em: {csv_path}")

def generate_charts(df, output_dir):
    """Gera gráficos dos resultados"""
    try:
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        
        ax1.bar(df['region'], df['avg_duration'])
        ax1.set_title('Tempo Médio de Resposta por Região')
        ax1.set_ylabel('Tempo (ms)')
        ax1.tick_params(axis='x', rotation=45)
        
        ax2.bar(df['region'], df['failed_requests'], color='red', alpha=0.7)
        ax2.set_title('Taxa de Erro por Região')
        ax2.set_ylabel('Taxa de Erro (%)')
        ax2.tick_params(axis='x', rotation=45)
        
        ax3.bar(df['region'], df['requests_per_sec'], color='green', alpha=0.7)
        ax3.set_title('Throughput por Região')
        ax3.set_ylabel('Requisições/seg')
        ax3.tick_params(axis='x', rotation=45)
        
        ax4.bar(df['region'], df['p95_duration'], color='orange', alpha=0.7)
        ax4.set_title('95º Percentil por Região')
        ax4.set_ylabel('Tempo (ms)')
        ax4.tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        
        chart_path = os.path.join(output_dir, 'performance_analysis.png')
        plt.savefig(chart_path, dpi=300, bbox_inches='tight')
        print(f"📊 Gráficos salvos em: {chart_path}")
        
    except Exception as e:
        print(f"⚠️  Erro ao gerar gráficos: {e}")
        print("   (certifique-se de ter matplotlib instalado: pip install matplotlib)")

def compare_scenarios(unsharded_dir, sharded_dir):
    """Compara os cenários unsharded vs sharded"""
    print("\n🔄 Comparação de Cenários")
    print("=" * 40)
    
    print("\n📊 Cenário UNSHARDED:")
    analyze_k6_results(unsharded_dir)
    
    print("\n📊 Cenário SHARDED:")
    analyze_k6_results(sharded_dir)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 analyze_results.py <diretório_resultados>")
        print("Ou: python3 analyze_results.py <dir_unsharded> <dir_sharded>")
        sys.exit(1)
    
    try:
        import pandas as pd
        import matplotlib.pyplot as plt
    except ImportError:
        print("⚠️  Instalando dependências...")
        os.system("pip3 install pandas matplotlib")
        import pandas as pd
        import matplotlib.pyplot as plt
    
    if len(sys.argv) == 2:
        # Análise simples
        analyze_k6_results(sys.argv[1])
    else:
        # Comparação de cenários
        compare_scenarios(sys.argv[1], sys.argv[2])
