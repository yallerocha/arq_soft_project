import http from 'k6/http';
import { sleep, check } from 'k6';

// Configurações padronizadas para comparação justa
export let options = {
    vus: __ENV.VUS || 10,
    duration: __ENV.DURATION || '30s',
    thresholds: {
        http_req_duration: ['p(95)<5000'], // Padronizado com outros testes
        http_req_failed: ['rate<0.1'],     // Padronizado com outros testes
    },
};

// URLs das APIs - Teste Brasil → Brasil (servidor real no Brasil)
const BASE_URL = __ENV.BASE_URL || 'http://15.228.71.189'; // Servidor real no Brasil
const POSTS_API = `${BASE_URL}/posts`;
const USERS_API = `${BASE_URL}/users`;
const FEED_API = `${BASE_URL}/feed`; // API de feed específica

// Sleep time padrão (sem simulação artificial)
const SLEEP_TIME = parseFloat(__ENV.SLEEP) || 0.5; // Reduzido para teste real

export default function() {
    // Apenas 20% das iterações criam usuários/posts (reduz carga no DB)
    let shouldCreate = Math.random() < 0.2;
    
    if (shouldCreate) {
        // Criar usuário brasileiro (apenas 20% das vezes)
        let userData = {
            name: `Usuario_BR_${__VU}_${Math.floor(__ITER/5)}`,
            email: `user_br_${__VU}_${Math.floor(__ITER/5)}@gmail.com`,
            location: 'São Paulo, Brasil'
        };
        
        let userResponse = http.post(`${BASE_URL}/users`, JSON.stringify(userData), {
            headers: { 'Content-Type': 'application/json' },
            timeout: '15s' // Aumentado para conexões reais
        });
        
        check(userResponse, {
            'POST /users status 200 ou 201': (r) => [200, 201].includes(r.status),
        });
        
        sleep(SLEEP_TIME * 0.5);
        
        if (userResponse.status === 200 || userResponse.status === 201) {
            // Criar post apenas se usuário foi criado com sucesso
            let postData = {
                userId: Math.floor(Math.random() * 20) + 1, // IDs 1-20 (poucos usuários)
                title: `Post BR ${__VU}-${Math.floor(__ITER/5)}`,
                content: `Conteúdo de São Paulo, Brasil. VU: ${__VU}`
            };
            
            let postResponse = http.post(`${BASE_URL}/posts`, JSON.stringify(postData), {
                headers: { 'Content-Type': 'application/json' },
                timeout: '15s' // Aumentado para conexões reais
            });
            
            check(postResponse, {
                'POST /posts status 200 ou 201': (r) => [200, 201].includes(r.status),
            });
            
            sleep(SLEEP_TIME * 0.5);
        }
    }
    
    // FOCO: 80% das operações são GETs (menos carga no DB)
    for (let i = 0; i < 3; i++) {
        let userId = Math.floor(Math.random() * 20) + 1; // Buscar feeds de usuários 1-20
        
        let feedResponse = http.get(`${BASE_URL}/feed/${userId}`, {
            timeout: '15s' // Aumentado para conexões reais
        });
        
        check(feedResponse, {
            'GET /feed status 200': (r) => r.status === 200,
            'GET /feed tem conteúdo': (r) => r.body && r.body.length > 0
        });
        
        sleep(SLEEP_TIME * 0.3); // Sleep menor para GETs
    }
}

export function handleSummary(data) {
    return {
        'stdout': textSummary(data, { indent: ' ', enableColors: true }),
        'summary.json': JSON.stringify(data),
    };
}

function textSummary(data, options = {}) {
    const indent = options.indent || '';
    const colors = options.enableColors;
    
    let summary = '';
    
    // Header
    if (colors) {
        summary += `\n${indent}\x1b[32m🇧🇷→🇧🇷 TESTE BRASIL → BRASIL\x1b[0m\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    } else {
        summary += `\n${indent}🇧🇷→🇧🇷 TESTE BRASIL → BRASIL\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    }
    
    // Métricas principais
    const httpReqs = data.metrics.http_reqs?.values?.count || 0;
    const httpReqFailed = (data.metrics.http_req_failed?.values?.rate || 0) * 100;
    const httpReqDuration = data.metrics.http_req_duration?.values;
    
    summary += `${indent}🌐 APIs testadas: POST /users, POST /posts, GET /feed/:userId\n`;
    summary += `${indent}🇧🇷 Origem: São Paulo, Brasil\n`;
    summary += `${indent}🇧🇷 Destino: Servidor real no Brasil (${BASE_URL})\n`;
    summary += `${indent}📈 Total de requisições: ${httpReqs}\n`;
    summary += `${indent}❌ Taxa de erro: ${httpReqFailed.toFixed(2)}%\n`;
    
    if (httpReqDuration) {
        summary += `${indent}⏱️  Tempo de resposta médio: ${httpReqDuration.avg.toFixed(2)}ms\n`;
        summary += `${indent}⏱️  P95: ${httpReqDuration['p(95)'].toFixed(2)}ms\n`;
        summary += `${indent}⏱️  Máximo: ${httpReqDuration.max.toFixed(2)}ms\n`;
        
        // Análise de latência Brasil→Brasil
        if (httpReqDuration.avg > 500) {
            summary += `${indent}🌎 Alta latência Brasil→Brasil (acima do esperado)\n`;
        } else if (httpReqDuration.avg > 200) {
            summary += `${indent}🌎 Latência normal Brasil→Brasil (50-200ms esperado)\n`;
        } else {
            summary += `${indent}🌎 Baixa latência (ótimo para Brasil→Brasil)\n`;
        }
    }
    
    // Status dos checks
    const checks = data.metrics.checks?.values;
    if (checks) {
        const passRate = (checks.passes / checks.total) * 100;
        summary += `${indent}✅ Checks passando: ${passRate.toFixed(1)}% (${checks.passes}/${checks.total})\n`;
    }
    
    summary += `${indent}${'='.repeat(50)}\n`;
    
    return summary;
}
