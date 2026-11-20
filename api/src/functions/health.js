const { app } = require('@azure/functions');
const { runChecks } = require('../health');

app.http('health', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'health',
  handler: async (_request, context) => {
    const result = await runChecks(process.env, undefined, (msg) => context.warn(msg));
    return { status: result.status === 'ok' ? 200 : 503, jsonBody: result };
  },
});
