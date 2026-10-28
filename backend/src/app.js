import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { credentials, registration, profileUpdate, uploadSchema } from './validation.js';
import { hashPassword, verifyPassword, createSession, tokenHash } from './auth.js';

export function createApp(db, { webOrigin = process.env.WEB_ORIGIN || '' } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use((req, res, next) => {
    res.set({ 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    if (webOrigin && req.get('origin') === webOrigin) {
      res.set({ 'Access-Control-Allow-Origin': webOrigin, Vary: 'Origin', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS' });
    }
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });
  app.use(express.json({ limit: '8mb', strict: true }));
  app.get('/health', async (_req, res) => {
    await db.query('SELECT 1');
    res.json({ status: 'ok', database: 'connected' });
  });
  const authLimit = rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false, message: { error: 'Too many sign-in attempts. Try again later.' } });
  app.use('/auth', authLimit);
  app.post('/auth/register', async (req, res) => {
    const parsed = registration.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Enter your name (up to 80 characters), a valid email, and a password of 8–128 characters.' });
    const { name, email, password } = parsed.data;
    const passwordHash = await hashPassword(password);
    const connection = await db.getConnection();
    let userId;
    try {
      await connection.beginTransaction();
      const [result] = await connection.execute('INSERT INTO st_users (name, email, password_hash) VALUES (?, ?, ?)', [name, email, passwordHash]);
      userId = result.insertId;
      await connection.execute('INSERT INTO st_backups (user_id) VALUES (?)', [userId]);
      const token = await createSession(connection, userId);
      await connection.commit();
      res.status(201).json({ token, email, name });
    } catch (error) {
      await connection.rollback();
      if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'An account with that email already exists.' });
      throw error;
    } finally { connection.release(); }
  });
  app.post('/auth/login', async (req, res) => {
    const parsed = credentials.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Enter a valid email and password.' });
    const [users] = await db.execute('SELECT id, name, email, password_hash FROM st_users WHERE email = ?', [parsed.data.email]);
    const user = users[0];
    if (!await verifyPassword(parsed.data.password, user?.password_hash)) return res.status(401).json({ error: 'Email or password is incorrect.' });
    res.json({ token: await createSession(db, user.id), email: user.email, name: user.name });
  });
  app.use(async (req, res, next) => {
    const match = /^Bearer ([a-f0-9]{64})$/.exec(req.get('authorization') || '');
    if (!match) return res.status(401).json({ error: 'Sign in to continue.' });
    const [sessions] = await db.execute('SELECT u.id, u.email FROM st_sessions s JOIN st_users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires_at > UTC_TIMESTAMP()', [tokenHash(match[1])]);
    if (!sessions.length) return res.status(401).json({ error: 'Your session expired. Sign in again.' });
    req.user = sessions[0];
    req.tokenHash = tokenHash(match[1]);
    next();
  });
  app.delete('/auth/session', async (req, res) => {
    await db.execute('DELETE FROM st_sessions WHERE token_hash = ?', [req.tokenHash]);
    res.sendStatus(204);
  });
  app.patch('/profile', async (req, res) => {
    const parsed = profileUpdate.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Enter a name of 1–80 characters.' });
    await db.execute('UPDATE st_users SET name = ? WHERE id = ?', [parsed.data.name, req.user.id]);
    res.json({ name: parsed.data.name, email: req.user.email });
  });
  app.get('/backup', async (req, res) => {
    const [rows] = await db.execute('SELECT document, revision, updated_at FROM st_backups WHERE user_id = ?', [req.user.id]);
    const row = rows[0];
    res.json({ revision: row.revision, updatedAt: row.updated_at, data: row.document ? JSON.parse(row.document) : null });
  });
  app.put('/backup', async (req, res) => {
    const parsed = uploadSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'The app backup is invalid or unsupported.' });
    // Compare-and-swap: another device cannot silently overwrite a newer revision.
    const [result] = await db.execute('UPDATE st_backups SET document = ?, revision = revision + 1, updated_at = UTC_TIMESTAMP() WHERE user_id = ? AND revision = ?', [JSON.stringify(parsed.data.data), req.user.id, parsed.data.revision]);
    if (!result.affectedRows) return res.status(409).json({ error: 'The server backup changed. Review the latest backup before saving again.' });
    res.json({ revision: parsed.data.revision + 1 });
  });
  app.use((_req, res) => res.status(404).json({ error: 'Endpoint not found.' }));
  app.use((error, _req, res, _next) => {
    if (error.type === 'entity.too.large') return res.status(413).json({ error: 'The backup is too large (maximum 8 MB).' });
    if (error.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid JSON request.' });
    // Never return SQL details, passwords, or financial records to clients/logs.
    console.error('API request failed:', error.code || error.name);
    res.status(503).json({ error: 'The database is unavailable. Start MySQL and try again.' });
  });
  return app;
}
