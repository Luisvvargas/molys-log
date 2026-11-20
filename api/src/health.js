// Health checks for the boilerplate. Returns only booleans; never echoes config values.
const { Client } = require('pg');
const { DefaultAzureCredential } = require('@azure/identity');
const { BlobServiceClient } = require('@azure/storage-blob');

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
  });
  try {
    await client.connect();
    await client.query('SELECT 1');
    return true;
  } finally {
    await client.end().catch(() => {});
  }
}

async function checkStorage(env) {
  const url = `https://${env.STORAGE_ACCOUNT_NAME}.blob.core.windows.net`;
  const service = new BlobServiceClient(url, new DefaultAzureCredential());
  return service.getContainerClient(env.DOCUMENTS_CONTAINER).exists();
}

async function runChecks(env = process.env, deps = { checkDatabase, checkStorage }) {
  const keyVaultSecretResolved =
    typeof env.DB_PASSWORD === 'string' &&
    env.DB_PASSWORD.length > 0 &&
    !env.DB_PASSWORD.startsWith('@Microsoft.KeyVault');

  const settle = async (fn) => {
    try {
      return (await fn(env)) === true;
    } catch {
      return false;
    }
  };

  const checks = {
    keyVaultSecretResolved,
    database: keyVaultSecretResolved ? await settle(deps.checkDatabase) : false,
    blobStorage: env.STORAGE_ACCOUNT_NAME ? await settle(deps.checkStorage) : false,
  };
  const ok = Object.values(checks).every(Boolean);
  return { status: ok ? 'ok' : 'degraded', service: 'molys-log-api', checks };
}

module.exports = { runChecks };
