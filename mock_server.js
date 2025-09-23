const express = require('express');
const app = express();
const PORT = 8000;

app.get('/feed', (req, res) => {
    const user_id = req.query.user_id || 'unknown';
    const posts = Array.from({ length: 20 }, (_, i) => ({
        id: i + 1,
        user_id,
        timestamp: Date.now() - i * 1000 * 60,
        image_url: `https://picsum.photos/seed/${user_id}_${i}/200/300`
    }));
    res.json(posts);
});

app.listen(PORT, () => {
    console.log(`Mock server rodando em http://localhost:${PORT}`);
});
