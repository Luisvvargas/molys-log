// Health checks for the boilerplate. Returns only booleans; never echoes config values.
const { Client } = require('pg');
const { DefaultAzureCredential, ManagedIdentityCredential } = require('@azure/identity');
const { BlobServiceClient } = require('@azure/storage-blob');

const CHECK_TIMEOUT_MS = 8000;

async function checkDatabase(env) {
  // DB_PASSWORD arrives from a Key Vault reference resolved by the platform.
  const client = new Client({
    host: env.DB_HOST,
    database: env.DB_NAME,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    port: 5432,
    ssl: { rejectUnauthorized: true },
    connectionTimeoutMillis: 5000,
    query_timeout: 5000,
  });
  try {
    await client.connect();
    await client.query('SELECT 1');
    return true;
  } finally {
    client.end().catch(() => {});
  }
}

async function checkStorage(env) {
  const url = `https://${env.STORAGE_ACCOUNT_NAME}.blob.core.windows.net`;
  // In Azure use the app's managed identity directly (no slow credential-chain probing).
  const credential = env.IDENTITY_ENDPOINT ? new ManagedIdentityCredential() : new DefaultAzureCredential();
  const service = new BlobServiceClient(url, credential);
  return service.getContainerClient(env.DOCUMENTS_CONTAINER).exists();
}

function withTimeout(promise, ms) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(Object.assign(new Error('timeout'), { code: 'CHECK_TIMEOUT' })), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

async function runChecks(env = process.env, deps = { checkDatabase, checkStorage }, log = () => {}) {
  const keyVaultSecretResolved =
    typeof env.DB_PASSWORD === 'string' &&
    env.DB_PASSWORD.length > 0 &&
    !env.DB_PASSWORD.startsWith('@Microsoft.KeyVault');

  const settle = async (name, fn) => {
    try {
      return (await withTimeout(fn(env), CHECK_TIMEOUT_MS)) === true;
    } catch (err) {
      // Log only the error class/code, never messages that could carry connection details.
      log(`health check '${name}' failed: ${err?.code ?? err?.name ?? 'Error'}`);
      return false;
    }
  };

  const [database, blobStorage] = await Promise.all([
    keyVaultSecretResolved ? settle('database', deps.checkDatabase) : false,
    env.STORAGE_ACCOUNT_NAME ? settle('blobStorage', deps.checkStorage) : false,
  ]);
  const checks = { keyVaultSecretResolved, database, blobStorage };
  const ok = Object.values(checks).every(Boolean);
  return { status: ok ? 'ok' : 'degraded', service: 'molys-log-api', checks };
}

module.exports = { runChecks, withTimeout };
