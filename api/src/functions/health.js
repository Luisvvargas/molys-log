const { app } = require('@azure/functions');
const { runChecks } = require('../health');

app.http('health', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'health',
  handler: async () => {
    const result = await runChecks();
    return { status: result.status === 'ok' ? 200 : 503, jsonBody: result };
  },
});
