import http from 'k6/http';
import { sleep, check } from 'k6';

export let options = {
    vus: 50,
    duration: '30m',
};

const userIds = [
    'user1', 'user2', 'user3', 'user4', 'user5',
];

const BASE_URL = 'http://localhost:8000';

export default function () {
    const user_id = userIds[Math.floor(Math.random() * userIds.length)];
    const res = http.get(`${BASE_URL}/feed?user_id=${user_id}`);
    check(res, {
        'status is 200': (r) => r.status === 200,
        'response time < 500ms': (r) => r.timings.duration < 500,
    });
    sleep(1);
}
