import mysql from 'mysql2/promise';
import { config } from '../src/config.js';
import { createTables } from '../src/schema.js';

const { database, user, password, ...connection } = config.db;
if (!/^[a-zA-Z0-9_]+$/.test(database) || !/^[a-zA-Z0-9_]+$/.test(user)) throw new Error('Use letters, numbers and underscores for database/user names.');
if (!password || password === 'replace-with-a-random-password') throw new Error('Set a random DB_PASSWORD in backend/.env first.');
const admin = await mysql.createConnection({ ...connection, user: process.env.DB_ADMIN_USER || 'root', password: process.env.DB_ADMIN_PASSWORD || '' });
try {
  await admin.query(`CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await admin.query(`USE \`${database}\``);
  await createTables(admin);
  for (const host of ['localhost', '127.0.0.1']) {
    // Account identifiers are validated above; password and host are escaped by the driver.
    await admin.query('CREATE USER IF NOT EXISTS ?@? IDENTIFIED BY ?', [user, host, password]);
    await admin.query(`GRANT SELECT, INSERT, UPDATE, DELETE ON \`${database}\`.* TO ?@?`, [user, host]);
  }
  console.log(`Database ${database} is ready. Run npm start.`);
} finally {
  await admin.end();
}
