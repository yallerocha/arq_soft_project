# 🌍 Sistema de Testes de Performance K6 - Local & Global

> **🚀 Simule milhares de usuários acessando sua API localmente OU em diferentes continentes!**

[![Testado ✅](https://img.shields.io/badge/Status-Testado_e_Funcionando-brightgreen.svg)]()
[![Local Ready 🏠](https://img.shields.io/badge/Local-Pronto_para_Usar-blue.svg)]()
[![AWS Ready 🌍](https://img.shields.io/badge/AWS-Distribuído-orange.svg)]()

## 🎯 O que este projeto faz?

**Sistema completo de testes de performance** que permite testar sua API tanto **localmente** (para desenvolvimento) quanto **globalmente distribuído** (para produção).

### 🏠 **Modo Local:**

- ✅ **Teste em segundos** - sem configuração complexa
- ✅ **Múltiplos cenários** - leve, médio, pesado
- ✅ **Relatórios automáticos** - métricas detalhadas na tela
- ✅ **Perfeito para desenvolvimento** - feedback imediato

### 🌍 **Modo Distribuído:**

- ✅ **3 regiões simultâneas** - Brasil, EUA, China
- ✅ **Comparação de cenários** - servidor central vs regional
- ✅ **Análise geográfica** - impacto da latência por região
- ✅ **Relatórios visuais** - gráficos e métricas detalhadas

---

## ⚡ INÍCIO RÁPIDO - 30 segundos

### 1. Clone e prepare:

```bash
cd arq_soft_project
npm install
```

### 2. Teste local instantâneo:

```bash
# Terminal 1: Inicie o servidor
node mock_server.js

# Terminal 2: Execute o teste
./quick_test.sh light
```

### 3. Veja o resultado:

```
🔥 Teste LEVE: 10 usuários por 30 segundos
📊 RESUMO DO TESTE LOCAL
📈 Total de requisições: 300
❌ Taxa de erro: 0.00%
⏱️  Tempo médio: 1.58ms
🎉 Teste concluído!
```

**Pronto! Já testou sua primeira API! 🚀**

---

## 🚀 GUIA COMPLETO

### 🏠 TESTES LOCAIS (Desenvolvimento)

#### 🎛️ Opções de teste disponíveis:

```bash
# Testes rápidos (RECOMENDADO):
./quick_test.sh light          # 🔥 10 usuários, 30s
./quick_test.sh medium         # 🔥 50 usuários, 60s
./quick_test.sh heavy          # 🔥 100 usuários, 30s
./quick_test.sh basic          # 🔥 Teste com script original k6_feed_test.js
./quick_test.sh all            # 🔥 Executa todos os testes acima

# Teste completo com relatórios:
./run_complete_test.sh local   # 📊 Bateria completa + análise + relatórios
./run_complete_test.sh --local # 📊 Mesma coisa

# K6 direto (avançado):
k6 run k6_local_test.js -e VUS=20 -e DURATION=60s
k6 run k6_feed_test.js --vus 10 --duration 30s
```

#### 🔧 Utilitários:

```bash
./cleanup.sh                  # 🧹 Limpa arquivos temporários
./quick_test.sh help           # ❓ Mostra todas as opções
```

---

### 🌍 TESTES DISTRIBUÍDOS (Produção AWS)

**Para testes reais em múltiplas regiões geográficas:**

#### Passo 1: Configure suas informações

Abra o arquivo `config.env` e preencha apenas estas linhas:

```bash
# Sua chave SSH da AWS (arquivo .pem)
AWS_KEY_PATH="./minha-chave.pem"

# IPs das suas máquinas na AWS (uma em cada região)
EC2_BRAZIL="ec2-123-456-789.sa-east-1.compute.amazonaws.com"
EC2_USA="ec2-987-654-321.us-east-1.compute.amazonaws.com"
EC2_CHINA="ec2-111-222-333.cn-north-1.compute.amazonaws.com"

# URLs da sua API em cada região
API_URL_BRAZIL="http://minha-api-brasil.com:8000"
API_URL_USA="http://minha-api-eua.com:8000"
API_URL_CHINA="http://minha-api-china.com:8000"
```

#### Passo 2: Execute o teste distribuído

```bash
# Para testar ambos os cenários e comparar (RECOMENDADO)
./run_complete_test.sh both

# Ou testar apenas um cenário específico:
./run_complete_test.sh unsharded    # Só servidor central
./run_complete_test.sh sharded      # Só servidores regionais
```

#### Passo 3: Veja os resultados

Os resultados aparecem automaticamente em `./test_results/`:

- 📊 **Gráficos comparativos** de performance
- 📈 **Métricas detalhadas** por região
- 🕰️ **Tempos de resposta** (média, p95, máximo)
- ❌ **Taxa de erro** por região
- 📝 **Logs completos** da execução

---

## � RESULTADOS COMPROVADOS

### 🏆 Performance Testada e Aprovada:

| **Teste**     | **Usuários** | **Duração** | **Requisições** | **Erro** | **Tempo Médio** | **P95** |
| ------------- | ------------ | ----------- | --------------- | -------- | --------------- | ------- |
| 🟢 **Light**  | 10           | 30s         | 300             | 0.00%    | 1.58ms          | 3.51ms  |
| 🟡 **Medium** | 50           | 60s         | 3,000           | 0.00%    | 2.14ms          | 6.30ms  |
| 🔴 **Heavy**  | 100          | 30s         | 6,000           | 0.00%    | 2.21ms          | 7.20ms  |

**✅ 100% de sucesso em todos os testes!**

---

## 📁 ESTRUTURA DO PROJETO

### 🚀 Scripts Principais:

| **Arquivo**                | **Função**            | **Quando Usar**           |
| -------------------------- | --------------------- | ------------------------- |
| **`quick_test.sh`**        | Testes rápidos locais | ⭐ Desenvolvimento diário |
| **`run_complete_test.sh`** | Sistema completo      | 📊 Análises detalhadas    |
| **`cleanup.sh`**           | Limpeza de arquivos   | 🧹 Manutenção             |

### 📄 Scripts K6:

| **Arquivo**                  | **Otimizado para** | **Características**                          |
| ---------------------------- | ------------------ | -------------------------------------------- |
| **`k6_local_test.js`**       | Testes locais      | 🎯 Resumo customizado, variáveis de ambiente |
| **`k6_feed_test.js`**        | Testes básicos     | 🔧 Script simples e direto                   |
| **`k6_distributed_test.js`** | AWS distribuído    | 🌍 Multi-região, cenários complexos          |

### ⚙️ Configuração:

| **Arquivo**            | **Para** | **Conteúdo**                       |
| ---------------------- | -------- | ---------------------------------- |
| **`config.env`**       | AWS      | Chaves SSH, IPs EC2, URLs APIs     |
| **`config.local.env`** | Local    | Configurações de carga, thresholds |

### 🔧 Utilitários:

| **Arquivo**                     | **Função**                     |
| ------------------------------- | ------------------------------ |
| **`mock_server.js`**            | Servidor de teste local        |
| **`analyze_results.py`**        | Análise de resultados          |
| **`analyze_system_metrics.py`** | Análise de métricas de sistema |
| **`monitor_resources.sh`**      | Monitoramento de recursos      |

---

## 📋 PRÉ-REQUISITOS

### 🏠 Para Testes Locais (Início Imediato):

```bash
# Instalar dependências:
sudo apt install k6          # ou: brew install k6 (macOS)
npm install                   # Dependências Node.js
```

**Requisitos mínimos:**

- ✅ **Node.js** (para mock server)
- ✅ **K6** (ferramenta de teste)
- ✅ **2 terminais** (um para server, outro para teste)

### 🌍 Para Testes Distribuídos AWS:

- ✅ **Todos os requisitos locais** +
- ✅ **Chave SSH da AWS** (arquivo .pem)
- ✅ **3 instâncias EC2** (Brasil, EUA, China)
- ✅ **Ubuntu** nas instâncias
- ✅ **Portas 22 e 8000** liberadas
- ✅ **APIs rodando** nas 3 regiões

---

## 🎯 CASOS DE USO

### 👩‍💻 **Desenvolvedor:**

```bash
# Teste rápido durante desenvolvimento
./quick_test.sh light
```

### 🔧 **DevOps/QA:**

```bash
# Análise completa com relatórios
./run_complete_test.sh local
```

### 🌍 **Arquiteto de Soluções:**

```bash
# Comparação global de arquiteturas
./run_complete_test.sh both
```

### 🚀 **CI/CD Pipeline:**

```bash
# Automação de testes
./quick_test.sh medium && ./cleanup.sh
```

---

## 🎨 Exemplos de uso

---

## 📺 EXEMPLOS EM AÇÃO

### 🚀 **Teste Local - 30 segundos:**

```bash
# Terminal 1
$ node mock_server.js
Mock server rodando em http://localhost:8000

# Terminal 2
$ ./quick_test.sh light
✅ Tudo pronto! Iniciando teste...
🔥 Teste LEVE: 10 usuários por 30 segundos

📊 RESUMO DO TESTE LOCAL
📈 Total de requisições: 300
❌ Taxa de erro: 0.00%
⏱️  Tempo médio: 1.58ms
⏱️  P95: 3.51ms
🎉 Teste concluído!
```

### 🌍 **Teste Distribuído - Alguns minutos:**

```bash
$ ./run_complete_test.sh both
📊 RESUMO DOS RESULTADOS
==========================================
🇧🇷 BRASIL: 15,000 req | 0.1% erro | 45ms
🇺🇸 EUA:    15,000 req | 0.0% erro | 12ms
🇨🇳 CHINA:  15,000 req | 2.3% erro | 890ms
🏆 VENCEDOR: Servidores Regionais (-65% latência)
```

---

## ⚙️ CONFIGURAÇÕES AVANÇADAS

### 🎛️ Personalizar testes locais (`config.local.env`):

```bash
# Usuários por teste
VUS_LIGHT=10
VUS_MEDIUM=50
VUS_HEAVY=100

# Duração dos testes
DURATION_LIGHT="30s"
DURATION_MEDIUM="60s"
DURATION_HEAVY="30s"

# Limite de tempo aceitável
RESPONSE_TIME_THRESHOLD=500
```

### 🌍 Configurar AWS (`config.env`):

```bash
# Instâncias EC2
AWS_KEY_PATH="./minha-chave.pem"
EC2_BRAZIL="ec2-xxx.sa-east-1.compute.amazonaws.com"
EC2_USA="ec2-xxx.us-east-1.compute.amazonaws.com"
EC2_CHINA="ec2-xxx.cn-north-1.compute.amazonaws.com"

# URLs das APIs
API_URL_BRAZIL="http://minha-api-brasil.com:8000"
API_URL_USA="http://minha-api-eua.com:8000"
API_URL_CHINA="http://minha-api-china.com:8000"
```

### Teste distribuído completo:

```bash
# Configure AWS no config.env, depois:
./run_complete_test.sh both

# Resultado após alguns minutos:
# 📊 RESUMO DOS RESULTADOS
# ==========================================
# 🇧🇷 BRASIL: 15,000 req | 0.1% erro | 45ms
# 🇺🇸 EUA:    15,000 req | 0.0% erro | 12ms
# 🇨🇳 CHINA:  15,000 req | 2.3% erro | 890ms
# � VENCEDOR: Servidores Regionais (-65% latência)
```

Requisições: 15,000 | Erros: 0.0% | Tempo médio: 12ms

🇨🇳 CHINA:
Requisições: 15,000 | Erros: 2.3% | Tempo médio: 890ms

🏆 VENCEDOR: Servidores Regionais (-65% latência)

````

---

## 🔧 Configurações avançadas

Se quiser personalizar o teste, edite estas variáveis no `config.env`:

```bash
# Quantos usuários simultâneos por região (padrão: 50)
VUS_PER_REGION=100

---

## 🆘 RESOLUÇÃO DE PROBLEMAS

### 🏠 **Problemas Locais:**

#### ❌ "Mock server não encontrado"
```bash
# Solução:
node mock_server.js  # Execute em outro terminal
````

#### ❌ "K6 não está instalado"

```bash
# Ubuntu/Debian:
sudo apt install k6

# macOS:
brew install k6

# Ou usando snap:
sudo snap install k6
```

#### ❌ "quick_test.sh: permission denied"

```bash
chmod +x quick_test.sh
chmod +x run_complete_test.sh
chmod +x cleanup.sh
```

### 🌍 **Problemas AWS:**

#### ❌ "Chave SSH não encontrada"

```bash
# Verifique o caminho no config.env:
AWS_KEY_PATH="./minha-chave.pem"  # Caminho correto?
chmod 400 minha-chave.pem         # Permissões corretas?
```

#### ❌ "Falha na conexão com instância"

- ✅ **Instâncias rodando?** - Verifique no console AWS
- ✅ **IPs corretos?** - Atualize no config.env
- ✅ **Security Group?** - Libere porta 22 (SSH) e 8000 (API)
- ✅ **Usuário correto?** - `ubuntu` para Ubuntu, `ec2-user` para Amazon Linux

### 🧹 **Limpeza e Manutenção:**

```bash
./cleanup.sh                    # Limpa arquivos temporários
rm -rf test_results/*           # Remove todos os resultados antigos
npm install                     # Reinstala dependências Node.js
```

---

## 💡 DICAS PRO

### 🚀 **Workflow Recomendado:**

1. **Desenvolva localmente:** `./quick_test.sh light`
2. **Teste cenários:** `./quick_test.sh all`
3. **Análise detalhada:** `./run_complete_test.sh local`
4. **Deploy AWS:** Configure config.env → `./run_complete_test.sh both`

### ⚡ **Comandos Úteis:**

```bash
# Ver ajuda de qualquer script:
./quick_test.sh help
./run_complete_test.sh --help

# Teste específico com K6:
k6 run k6_local_test.js -e VUS=20 -e DURATION=60s

# Monitorar recursos durante teste:
./monitor_resources.sh local 60s

# Analisar resultados antigos:
python3 analyze_results.py ./test_results/local_20250922_223014/
```

### 🎯 **Para CI/CD:**

```bash
# Pipeline simples:
npm install && ./quick_test.sh medium && ./cleanup.sh

# Pipeline completo:
npm install && ./run_complete_test.sh local && ./cleanup.sh
```

---

## 🏆 CONCLUSÃO

**Sistema completo e testado! Agora você pode:**

✅ **Testar localmente** em segundos  
✅ **Analisar performance** detalhadamente  
✅ **Comparar arquiteturas** globalmente  
✅ **Integrar em CI/CD** facilmente

**🚀 Comece agora: `./quick_test.sh light` 🚀**

---

**📄 Documentação adicional:**

- `QUICK_START.md` - Guia de 2 minutos
- `config.env` - Configurações AWS
- `config.local.env` - Configurações locais

````

---

## 🆘 Resolução de problemas

### ❌ "Arquivo de configuração não encontrado"

→ Certifique-se que o arquivo `config.env` existe na mesma pasta

### ❌ "Chave SSH não encontrada"

→ Verifique se o caminho em `AWS_KEY_PATH` está correto

### ❌ "Falha na conexão com instância"

→ Verifique se:

- As instâncias EC2 estão rodando
- Os IPs estão corretos
- A porta 22 está liberada no Security Group
- Você está usando o usuário correto (`ubuntu` para Ubuntu)

### ❌ "Erro ao instalar K6"

→ Verifique se a instância tem acesso à internet

---

## 🚀 Dica Pro

Para testar localmente primeiro, use o servidor mock incluído:

```bash
# Em um terminal, inicie o servidor mock:
node mock_server.js

# Em outro terminal, teste:
./run_complete_test.sh unsharded
````

---

**Pronto! Agora você pode descobrir se sua API funciona bem globalmente! �**
