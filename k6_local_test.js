import http from 'k6/http';
import { sleep, check } from 'k6';

// Configurações podem ser passadas via variáveis de ambiente
export let options = {
    vus: __ENV.VUS || 10,
    duration: __ENV.DURATION || '30s',
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% das requisições devem ser < 500ms
        http_req_failed: ['rate<0.02'],   // Taxa de erro < 2%
    },
};

const userIds = [
    'user1', 'user2', 'user3', 'user4', 'user5',
    'user6', 'user7', 'user8', 'user9', 'user10'
];

const BASE_URL = __ENV.API_URL || 'http://localhost:8000';

export default function () {
    // Simular comportamento real de usuário
    const user_id = userIds[Math.floor(Math.random() * userIds.length)];
    
    // Requisição principal - buscar feed
    const res = http.get(`${BASE_URL}/feed?user_id=${user_id}`);
    
    check(res, {
        'status is 200': (r) => r.status === 200,
        'response time < 500ms': (r) => r.timings.duration < 500,
        'response time < 1000ms': (r) => r.timings.duration < 1000,
        'response contains posts': (r) => r.json().length > 0,
        'response is valid JSON': (r) => {
            try {
                r.json();
                return true;
            } catch (e) {
                return false;
            }
        },
    });
    
    // Simular tempo de leitura do usuário
    const sleepTime = parseFloat(__ENV.SLEEP || '1');
    sleep(sleepTime);
}

export function handleSummary(data) {
    return {
        'stdout': textSummary(data, { indent: ' ', enableColors: true }), // Saída colorida no terminal
        'summary.json': JSON.stringify(data), // Salvar dados detalhados em JSON
    };
}

function textSummary(data, options = {}) {
    const indent = options.indent || '';
    const colors = options.enableColors;
    
    let summary = '';
    
    // Header
    if (colors) {
        summary += `\n${indent}\x1b[36m📊 RESUMO DO TESTE LOCAL\x1b[0m\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    } else {
        summary += `\n${indent}📊 RESUMO DO TESTE LOCAL\n`;
        summary += `${indent}${'='.repeat(50)}\n`;
    }
    
    // Métricas principais
    const httpReqs = data.metrics.http_reqs?.values?.count || 0;
    const httpReqFailed = (data.metrics.http_req_failed?.values?.rate || 0) * 100;
    const httpReqDuration = data.metrics.http_req_duration?.values;
    
    summary += `${indent}📈 Total de requisições: ${httpReqs}\n`;
    summary += `${indent}❌ Taxa de erro: ${httpReqFailed.toFixed(2)}%\n`;
    
    if (httpReqDuration) {
        summary += `${indent}⏱️  Tempo de resposta médio: ${httpReqDuration.avg.toFixed(2)}ms\n`;
        summary += `${indent}⏱️  P95: ${httpReqDuration['p(95)'].toFixed(2)}ms\n`;
        summary += `${indent}⏱️  Máximo: ${httpReqDuration.max.toFixed(2)}ms\n`;
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
