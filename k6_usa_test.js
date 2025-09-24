import http from "k6/http";
import { sleep, check } from "k6";

export let options = {
    vus: __ENV.VUS || 10,
    duration: __ENV.DURATION || "30s",
    thresholds: {
        http_req_duration: ["p(95)<5000"],
        http_req_failed: ["rate<0.1"],
    },
};

// URLs dos servidores reais - EUA (us-east-1)
const BASE_URL = __ENV.BASE_URL || __ENV.API_URL_USA || "http://54.166.96.217";
const POSTS_API = `${BASE_URL}/posts`;
const USERS_API = `${BASE_URL}/users`;
const FEED_API = `${BASE_URL}/feed`;

// Sem simulação de latência - usando servidor real nos EUA
const SLEEP_TIME = parseFloat(__ENV.SLEEP) || 0.5; // Sleep normal entre requisições

export default function() {
    // Apenas 20% das iterações criam usuários/posts (reduz carga no DB)
    let shouldCreate = Math.random() < 0.2;
    
    if (shouldCreate) {
        // Criar usuário brasileiro conectando ao servidor dos EUA
        let userData = {
            name: `Usuario_BR_to_USA_${__VU}_${Math.floor(__ITER/5)}`,
            email: `user_br_usa_${__VU}_${Math.floor(__ITER/5)}@gmail.com`,
            location: 'São Paulo, Brasil'
        };
        
        let userResponse = http.post(`${BASE_URL}/users`, JSON.stringify(userData), {
            headers: { 
                'Content-Type': 'application/json',
                'User-Agent': 'K6-Test-BR-to-USA/1.0',
                'X-Origin-Region': 'Brazil',
                'X-Target-Region': 'USA'
            },
            timeout: '15s' // Timeout maior para requisições trans-continentais
        });
        
        check(userResponse, {
            'POST /users status 200 ou 201': (r) => [200, 201].includes(r.status),
            'POST /users response time < 2s': (r) => r.timings.duration < 2000,
        });
        
        sleep(SLEEP_TIME * 0.5);
        
        if (userResponse.status === 200 || userResponse.status === 201) {
            // Criar post apenas se usuário foi criado com sucesso
            let postData = {
                userId: Math.floor(Math.random() * 20) + 1,
                title: `Post BR→USA ${__VU}-${Math.floor(__ITER/5)}`,
                content: `Conteúdo de São Paulo enviado para servidor real nos EUA. VU: ${__VU}`
            };
            
            let postResponse = http.post(`${BASE_URL}/posts`, JSON.stringify(postData), {
                headers: { 
                    'Content-Type': 'application/json',
                    'User-Agent': 'K6-Test-BR-to-USA/1.0',
                    'X-Origin-Region': 'Brazil',
                    'X-Target-Region': 'USA'
                },
                timeout: '15s'
            });
            
            check(postResponse, {
                'POST /posts status 200 ou 201': (r) => [200, 201].includes(r.status),
                'POST /posts response time < 2s': (r) => r.timings.duration < 2000,
            });
            
            sleep(SLEEP_TIME * 0.5);
        }
    }
    
        // FOCO: 80% das operações são GETs (menos carga no DB)
    for (let i = 0; i < 3; i++) {
        let userId = Math.floor(Math.random() * 20) + 1;
        
        let feedResponse = http.get(`${BASE_URL}/feed/${userId}`, {
            headers: {
                'User-Agent': 'K6-Test-BR-to-USA/1.0',
                'X-Origin-Region': 'Brazil',
                'X-Target-Region': 'USA'
            },
            timeout: '15s'
        });
        
        check(feedResponse, {
            'GET /feed status 200': (r) => r.status === 200,
            'GET /feed tem conteúdo': (r) => r.body && r.body.length > 0,
            'GET /feed response time < 2s': (r) => r.timings.duration < 2000,
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
        summary += `\n${indent}\x1b[34m🇧🇷→🇺🇸 TESTE BRASIL → EUA\x1b[0m\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    } else {
        summary += `\n${indent}🇧🇷→🇺🇸 TESTE BRASIL → EUA\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    }
    
    // Métricas principais
    const httpReqs = data.metrics.http_reqs?.values?.count || 0;
    const httpReqFailed = (data.metrics.http_req_failed?.values?.rate || 0) * 100;
    const httpReqDuration = data.metrics.http_req_duration?.values;
    
    summary += `${indent}🌐 APIs testadas: POST /users, POST /posts, GET /feed/:userId\n`;
    summary += `${indent}🇧🇷 Origem: São Paulo, Brasil\n`;
    summary += `${indent}🇺🇸 Destino: Servidor real nos EUA (us-east-1)\n`;
    summary += `${indent}📈 Total de requisições: ${httpReqs}\n`;
    summary += `${indent}❌ Taxa de erro: ${httpReqFailed.toFixed(2)}%\n`;
    
    if (httpReqDuration) {
        summary += `${indent}⏱️  Tempo de resposta médio: ${httpReqDuration.avg.toFixed(2)}ms\n`;
        summary += `${indent}⏱️  P95: ${httpReqDuration['p(95)'].toFixed(2)}ms\n`;
        summary += `${indent}⏱️  Máximo: ${httpReqDuration.max.toFixed(2)}ms\n`;
        
        // Análise de latência real Brasil→EUA (us-east-1)
        if (httpReqDuration.avg > 800) {
            summary += `${indent}🌎 Alta latência Brasil→us-east-1 (>800ms - possível problema)\n`;
        } else if (httpReqDuration.avg > 400) {
            summary += `${indent}🌎 Latência normal Brasil→us-east-1 (200-400ms esperado)\n`;
        } else {
            summary += `${indent}🌎 Boa latência Brasil→us-east-1 (<400ms)\n`;
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
