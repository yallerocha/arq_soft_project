# 🌍 Teste de Performance Global - K6 Distribuído

> **Simule milhares de usuários acessando sua API de diferentes continentes e compare a performance!**

## 🎯 O que este projeto faz?

Imagine que você tem uma API que precisa funcionar bem para usuários no **Brasil**, **EUA** e **China**. Este sistema:

1. **🚀 Simula usuários reais** em cada região fazendo milhares de requisições
2. **📊 Mede a performance** (velocidade, erro, latência)
3. **🔍 Compara dois cenários:**
   - **Servidor Central**: Todos acessam um servidor nos EUA
   - **Servidores Regionais**: Cada região tem seu próprio servidor
4. **📈 Gera relatórios visuais** mostrando qual é melhor

---

## 🚀 Como usar em 3 passos

### Passo 1: Configure suas informações

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

### Passo 2: Execute o teste

```bash
# Para testar ambos os cenários e comparar (RECOMENDADO)
./run_complete_test.sh both

# Ou testar apenas um cenário específico:
./run_complete_test.sh unsharded    # Só servidor central
./run_complete_test.sh sharded      # Só servidores regionais
```

### Passo 3: Veja os resultados

Os resultados aparecem automaticamente em `./test_results/`:

- 📊 **Gráficos comparativos** de performance
- 📈 **Métricas detalhadas** por região
- 🕰️ **Tempos de resposta** (média, p95, máximo)
- ❌ **Taxa de erro** por região
- 📝 **Logs completos** da execução

---

## 🤖 O que acontece automaticamente

Quando você roda o script, ele faz tudo sozinho:

```
✅ Valida se suas configurações estão corretas
✅ Testa conexão com as 3 máquinas na AWS
✅ Instala o K6 nas máquinas (se não tiver)
✅ Cria scripts de teste personalizados
✅ Executa testes simultâneos nas 3 regiões
✅ Coleta todos os resultados
✅ Gera gráficos e análises automáticas
✅ Compara os cenários (se escolheu 'both')
```

**Você só precisa esperar!** ⏳

---

## 📋 Pré-requisitos

Antes de começar, você precisa ter:

### Na sua máquina local:

- ✅ **Linux/macOS** com Bash
- ✅ **Python 3** (para gráficos) - opcional
- ✅ **Chave SSH da AWS** (arquivo .pem)

### Na AWS:

- ✅ **3 instâncias EC2** rodando (Brasil, EUA, China)
- ✅ **Ubuntu** nas instâncias
- ✅ **Portas 22 e 8000** liberadas no Security Group
- ✅ **Sua API** rodando nas 3 regiões

---

## 🎨 Exemplo de resultado

Depois do teste, você vai ver algo assim:

```
📊 RESUMO DOS RESULTADOS
==========================================
🇧🇷 BRASIL:
   Requisições: 15,000 | Erros: 0.1% | Tempo médio: 45ms

🇺🇸 EUA:
   Requisições: 15,000 | Erros: 0.0% | Tempo médio: 12ms

🇨🇳 CHINA:
   Requisições: 15,000 | Erros: 2.3% | Tempo médio: 890ms

🏆 VENCEDOR: Servidores Regionais (-65% latência)
```

---

## 🔧 Configurações avançadas

Se quiser personalizar o teste, edite estas variáveis no `config.env`:

```bash
# Quantos usuários simultâneos por região (padrão: 50)
VUS_PER_REGION=100

# Quanto tempo o teste vai durar (padrão: 30 minutos)
TEST_DURATION="60m"

# Intervalo entre requisições (padrão: 1-3 segundos)
SLEEP_BETWEEN_REQUESTS="0.5-2"

# Limite de tempo de resposta considerado aceitável (padrão: 500ms)
RESPONSE_TIME_THRESHOLD=300
```

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
```

---

**Pronto! Agora você pode descobrir se sua API funciona bem globalmente! �**
