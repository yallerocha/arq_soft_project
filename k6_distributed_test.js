import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

export let feedRequestsTotal = new Counter('feed_requests_total');
export let feedErrorRate = new Rate('feed_error_rate');
export let feedResponseTime = new Trend('feed_response_time');

export let options = {
    stages: [
        { duration: '2m', target: 20 },   
        { duration: '10m', target: 20 }, 
        { duration: '5m', target: 50 },  
        { duration: '10m', target: 50 },  
        { duration: '3m', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.1'],
        feed_error_rate: ['rate<0.05'],
    },
};

const SERVERS = {
    'brazil': 'http://ec2-brazil.amazonaws.com:8000',
    'usa': 'http://ec2-usa.amazonaws.com:8000', 
    'china': 'http://ec2-china.amazonaws.com:8000'
};

const USER_IDS = {
    'brazil': Array.from({length: 1000}, (_, i) => `br_user_${i + 1}`),
    'usa': Array.from({length: 1000}, (_, i) => `us_user_${i + 1}`),
    'china': Array.from({length: 1000}, (_, i) => `cn_user_${i + 1}`)
};

const REGION = __ENV.REGION || 'brazil';
const BASE_URL = SERVERS[REGION];
const REGION_USER_IDS = USER_IDS[REGION];

export default function () {
    const user_id = REGION_USER_IDS[Math.floor(Math.random() * REGION_USER_IDS.length)];
    
    const startTime = Date.now();
    const response = http.get(`${BASE_URL}/feed?user_id=${user_id}`, {
        headers: {
            'User-Agent': `k6-loadtest-${REGION}`,
            'X-Region': REGION
        },
        timeout: '30s'
    });
    
    const responseTime = Date.now() - startTime;
    
    feedRequestsTotal.add(1);
    feedResponseTime.add(responseTime);
    
    const isSuccess = check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 1000ms': (r) => r.timings.duration < 1000,
        'has posts array': (r) => {
            try {
                const body = JSON.parse(r.body);
                return Array.isArray(body) && body.length <= 20;
            } catch (e) {
                return false;
            }
        },
        'posts have required fields': (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.every(post => 
                    post.hasOwnProperty('id') && 
                    post.hasOwnProperty('user_id') && 
                    post.hasOwnProperty('timestamp') && 
                    post.hasOwnProperty('image_url')
                );
            } catch (e) {
                return false;
            }
        }
    });
    
    if (!isSuccess) {
        feedErrorRate.add(1);
    }

    sleep(Math.random() * 2 + 1);
}

export function handleSummary(data) {
    return {
        [`k6-summary-${REGION}-${Date.now()}.json`]: JSON.stringify(data, null, 2),
        stdout: textSummary(data, { indent: ' ', enableColors: true })
    };
}

function textSummary(data, options = {}) {
    const indent = options.indent || '';
    const enableColors = options.enableColors !== false;
    
    let summary = `${indent}Test Results for Region: ${REGION.toUpperCase()}\n`;
    summary += `${indent}========================================\n`;
    summary += `${indent}Total Requests: ${data.metrics.http_reqs.values.count}\n`;
    summary += `${indent}Failed Requests: ${data.metrics.http_req_failed.values.rate * 100}%\n`;
    summary += `${indent}Avg Response Time: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
    summary += `${indent}95th Percentile: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
    summary += `${indent}Max Response Time: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms\n`;
    summary += `${indent}Requests/sec: ${data.metrics.http_reqs.values.rate.toFixed(2)}\n`;
    
    return summary;
}
