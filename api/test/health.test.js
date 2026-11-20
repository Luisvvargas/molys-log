const test = require('node:test');
const assert = require('node:assert');
const { runChecks } = require('../src/health');

const ok = async () => true;
const boom = async () => {
  throw new Error('unreachable');
};
const env = { DB_PASSWORD: 'resolved-value', STORAGE_ACCOUNT_NAME: 'st', DOCUMENTS_CONTAINER: 'c' };

test('all checks pass -> ok', async () => {
  const r = await runChecks(env, { checkDatabase: ok, checkStorage: ok });
  assert.strictEqual(r.status, 'ok');
});

test('unresolved Key Vault reference -> degraded, DB not attempted', async () => {
  let called = false;
  const r = await runChecks(
    { ...env, DB_PASSWORD: '@Microsoft.KeyVault(VaultName=x;SecretName=y)' },
    { checkDatabase: async () => (called = true), checkStorage: ok },
  );
  assert.strictEqual(r.status, 'degraded');
  assert.strictEqual(r.checks.keyVaultSecretResolved, false);
  assert.strictEqual(called, false);
});

test('dependency error -> degraded, no secret in response', async () => {
  const r = await runChecks(env, { checkDatabase: boom, checkStorage: ok });
  assert.strictEqual(r.checks.database, false);
  assert.ok(!JSON.stringify(r).includes('resolved-value'));
});
