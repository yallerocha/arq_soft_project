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

// URLs dos servidores reais - Tóquio/Ásia (ap-northeast-1)
const BASE_URL = __ENV.BASE_URL || __ENV.API_URL_CHINA || "http://52.196.245.151";
const POSTS_API = `${BASE_URL}/posts`;
const USERS_API = `${BASE_URL}/users`;
const FEED_API = `${BASE_URL}/feed`;

// Sem simulação de latência - usando servidor real em Tóquio
const SLEEP_TIME = parseFloat(__ENV.SLEEP) || 0.5; // Sleep normal entre requisições

export default function() {
    // Apenas 20% das iterações criam usuários/posts (reduz carga no DB)
    let shouldCreate = Math.random() < 0.2;
    
    if (shouldCreate) {
        // Criar usuário brasileiro conectando ao servidor real em Tóquio
        let userData = {
            name: `Usuario_BR_to_Tokyo_${__VU}_${Math.floor(__ITER/5)}`,
            email: `user_br_tokyo_${__VU}_${Math.floor(__ITER/5)}@gmail.com`,
            location: 'São Paulo, Brasil'
        };
        
        let userResponse = http.post(`${BASE_URL}/users`, JSON.stringify(userData), {
            headers: { 
                'Content-Type': 'application/json',
                'User-Agent': 'K6-Test-BR-to-Tokyo/1.0',
                'Accept-Language': 'pt-BR,ja;q=0.8',
                'X-Origin-Region': 'Brazil',
                'X-Target-Region': 'Tokyo'
            },
            timeout: '20s' // Timeout maior para requisições trans-pacíficas
        });
        
        check(userResponse, {
            'POST /users status 200 ou 201': (r) => [200, 201].includes(r.status),
            'POST /users response time < 3s': (r) => r.timings.duration < 3000,
        });
        
        sleep(SLEEP_TIME * 0.5);
        
        if (userResponse.status === 200 || userResponse.status === 201) {
            // Criar post apenas se usuário foi criado com sucesso
            let postData = {
                userId: Math.floor(Math.random() * 20) + 1,
                title: `Post BR→Tokyo ${__VU}-${Math.floor(__ITER/5)}`,
                content: `Conteúdo de São Paulo enviado para servidor real em Tóquio. VU: ${__VU}`
            };
            
            let postResponse = http.post(`${BASE_URL}/posts`, JSON.stringify(postData), {
                headers: { 
                    'Content-Type': 'application/json',
                    'User-Agent': 'K6-Test-BR-to-Tokyo/1.0',
                    'Accept-Language': 'pt-BR,ja;q=0.8',
                    'X-Origin-Region': 'Brazil',
                    'X-Target-Region': 'Tokyo'
                },
                timeout: '20s'
            });
            
            check(postResponse, {
                'POST /posts status 200 ou 201': (r) => [200, 201].includes(r.status),
                'POST /posts response time < 3s': (r) => r.timings.duration < 3000,
            });
            
            sleep(SLEEP_TIME * 0.5);
        }
    }
    
    // FOCO: 80% das operações são GETs (menos carga no DB)
    for (let i = 0; i < 3; i++) {
        let userId = Math.floor(Math.random() * 20) + 1;
        
        let feedResponse = http.get(`${BASE_URL}/feed/${userId}`, {
            headers: { 
                'User-Agent': 'K6-Test-BR-to-Tokyo/1.0',
                'Accept-Language': 'pt-BR,ja;q=0.8',
                'X-Origin-Region': 'Brazil',
                'X-Target-Region': 'Tokyo'
            },
            timeout: '20s'
        });
        
        check(feedResponse, {
            'GET /feed status 200': (r) => r.status === 200,
            'GET /feed tem conteúdo': (r) => r.body && r.body.length > 0,
            'GET /feed response time < 3s': (r) => r.timings.duration < 3000,
        });
        
        sleep(SLEEP_TIME * 0.3);
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
        summary += `\n${indent}\x1b[35m🇧🇷→🗾 TESTE BRASIL → TÓQUIO\x1b[0m\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    } else {
        summary += `\n${indent}🇧🇷→🗾 TESTE BRASIL → TÓQUIO\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    }
    
    // Métricas principais
    const httpReqs = data.metrics.http_reqs?.values?.count || 0;
    const httpReqFailed = (data.metrics.http_req_failed?.values?.rate || 0) * 100;
    const httpReqDuration = data.metrics.http_req_duration?.values;
    
    summary += `${indent}🌐 APIs testadas: POST /users, POST /posts, GET /feed/:userId\n`;
    summary += `${indent}🇧🇷 Origem: São Paulo, Brasil\n`;
    summary += `${indent}🗾 Destino: Servidor real em Tóquio (ap-northeast-1)\n`;
    summary += `${indent}📈 Total de requisições: ${httpReqs}\n`;
    summary += `${indent}❌ Taxa de erro: ${httpReqFailed.toFixed(2)}%\n`;
    
    if (httpReqDuration) {
        summary += `${indent}⏱️  Tempo de resposta médio: ${httpReqDuration.avg.toFixed(2)}ms\n`;
        summary += `${indent}⏱️  P95: ${httpReqDuration['p(95)'].toFixed(2)}ms\n`;
        summary += `${indent}⏱️  Máximo: ${httpReqDuration.max.toFixed(2)}ms\n`;
        
        // Análise de latência real Brasil→Tóquio (ap-northeast-1)
        if (httpReqDuration.avg > 1000) {
            summary += `${indent}🌎 Alta latência Brasil→Tóquio (>1000ms - possível problema)\n`;
        } else if (httpReqDuration.avg > 500) {
            summary += `${indent}🌎 Latência normal Brasil→Tóquio (400-800ms esperado)\n`;
        } else {
            summary += `${indent}🌎 Boa latência Brasil→Tóquio (<500ms)\n`;
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
