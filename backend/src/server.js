import mysql from 'mysql2/promise';
import { config } from './config.js';
import { createApp } from './app.js';

const db = mysql.createPool(config.db);
try {
  await db.query('SELECT revision FROM st_backups LIMIT 1');
} catch (error) {
  console.error('Cannot connect to the SpendTracker database. Start XAMPP MySQL and run npm run db:init. Error:', error.code);
  await db.end();
  process.exit(1);
}
const server = createApp(db).listen(config.port, config.host, () => console.log(`SpendTracker API: http://${config.host}:${config.port}`));
server.on('error', async error => { console.error('API could not start:', error.code); await db.end(); process.exitCode = 1; });
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(async () => { await db.end(); process.exit(0); }));
