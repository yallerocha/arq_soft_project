# 🚀 Sistema Automatizado de Testes K6 Distribuídos

## Como Usar (Super Simples!)

### 1. Preencha o arquivo de configuração

```bash
nano config.env
```

Edite apenas as linhas que precisam dos seus dados:

- `AWS_KEY_PATH` - caminho para sua chave .pem
- `EC2_BRAZIL`, `EC2_USA`, `EC2_CHINA` - IPs das suas instâncias
- `API_URL_BRAZIL`, `API_URL_USA`, `API_URL_CHINA` - URLs da sua API

### 2. Execute o teste

```bash
# Testar apenas cenário unsharded
./run_complete_test.sh unsharded

# Testar apenas cenário sharded
./run_complete_test.sh sharded

# Testar ambos os cenários e comparar
./run_complete_test.sh both
```

### 3. Veja os resultados

Os resultados ficam automaticamente em `./test_results/` com:

- Métricas detalhadas por região
- Gráficos comparativos (se Python/matplotlib instalado)
- Logs completos de execução
- Análise automatizada

## O que o script faz automaticamente:

✅ **Valida suas configurações**
✅ **Testa conexão com todas as instâncias**  
✅ **Instala k6 nas instâncias (se necessário)**
✅ **Gera script k6 personalizado baseado na config**
✅ **Executa testes em paralelo nas 3 regiões**
✅ **Coleta todos os resultados automaticamente**
✅ **Gera análise e gráficos**
✅ **Compara cenários (se executar 'both')**

## Exemplo de configuração mínima:

```bash
# config.env
AWS_KEY_PATH="./my-key.pem"
EC2_BRAZIL="ec2-54-233-123-45.sa-east-1.compute.amazonaws.com"
EC2_USA="ec2-34-201-67-89.us-east-1.compute.amazonaws.com"
EC2_CHINA="ec2-52-81-12-34.cn-north-1.compute.amazonaws.com"
API_URL_BRAZIL="http://your-api-brazil.com:8000"
API_URL_USA="http://your-api-usa.com:8000"
API_URL_CHINA="http://your-api-china.com:8000"
```

Só isso! O resto é automático 🎉
