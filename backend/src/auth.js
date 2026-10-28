import { randomBytes, scrypt, createHash, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const derive = promisify(scrypt);
async function key(password, salt) {
  return derive(password, salt, 64, { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
}
export async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  return `${salt}:${(await key(password, salt)).toString('hex')}`;
}
export async function verifyPassword(password, stored) {
  // Unknown accounts do the same expensive derivation as existing accounts.
  const [salt, encoded] = (stored || `${'0'.repeat(32)}:${'0'.repeat(128)}`).split(':');
  const actual = await key(password, salt);
  const expected = Buffer.from(encoded, 'hex');
  return expected.length === actual.length && timingSafeEqual(actual, expected) && Boolean(stored);
}
export const tokenHash = (token) => createHash('sha256').update(token).digest();
export async function createSession(db, userId) {
  await db.execute('DELETE FROM st_sessions WHERE expires_at <= UTC_TIMESTAMP()');
  const token = randomBytes(32).toString('hex');
  await db.execute('INSERT INTO st_sessions (token_hash, user_id, expires_at) VALUES (?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 DAY))', [tokenHash(token), userId]);
  return token;
}
