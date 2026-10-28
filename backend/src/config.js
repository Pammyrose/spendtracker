import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const envPath = fileURLToPath(new URL('../.env', import.meta.url));
if (existsSync(envPath)) process.loadEnvFile(envPath);

export const config = {
  host: process.env.HOST || '127.0.0.1',
  port: Number(process.env.PORT || 3000),
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    database: process.env.DB_NAME || 'spendtracker_api',
    user: process.env.DB_USER || 'spendtracker_app',
    password: process.env.DB_PASSWORD || '',
    connectionLimit: 5,
    connectTimeout: 5000,
    charset: 'utf8mb4',
    timezone: 'Z',
  },
};
for (const port of [config.port, config.db.port]) {
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid server/database port.');
}
