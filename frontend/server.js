const express = require('express');
const axios = require('axios');
const app = express();
const port = 3000;

const MIDDLEWARE_URL = process.env.MIDDLEWARE_URL || 'http://middleware:8000/api/data';

app.get('/', async (req, res) => {
    const startFrontend = process.hrtime();

    let middlewareQueryTime = 0;
    let middlewareStatus = 'unknown';

    try {
        const startMiddleware = process.hrtime();
        const response = await axios.get(MIDDLEWARE_URL);
        const endMiddleware = process.hrtime(startMiddleware);
        
        middlewareQueryTime = (endMiddleware[0] * 1000) + (endMiddleware[1] / 1e6);
        middlewareStatus = response.data;
    } catch (error) {
        middlewareStatus = `Error: ${error.message}`;
    }

    const endFrontend = process.hrtime(startFrontend);
    const frontendExecutionTime = (endFrontend[0] * 1000) + (endFrontend[1] / 1e6);

    res.json({
        message: "Hello Marc",
        timings: {
            frontend_execution_time: `${frontendExecutionTime.toFixed(2)}ms`,
            middleware_rest_query_time: `${middlewareQueryTime.toFixed(2)}ms`
        },
        middleware_response: middlewareStatus
    });
});

app.listen(port, () => {
    console.log(`Frontend listening at http://localhost:${port}`);
});
