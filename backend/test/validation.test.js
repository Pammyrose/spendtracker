import test from 'node:test';
import assert from 'node:assert/strict';
import { backupSchema, credentials, registration } from '../src/validation.js';
import { hashPassword, verifyPassword, tokenHash } from '../src/auth.js';
import { backup } from './fixture.js';

test('backups validate financial amounts, dates, and category references', () => {
  assert.equal(backupSchema.safeParse(backup()).success, true);
  const invalid = backup(); invalid.expenses[0].amount = -1;
  assert.equal(backupSchema.safeParse(invalid).success, false);
  invalid.expenses[0].amount = 1; invalid.expenses[0].category = 199;
  assert.equal(backupSchema.safeParse(invalid).success, false);
  invalid.expenses[0].category = 0; invalid.expenses[0].date = 'invalid';
  assert.equal(backupSchema.safeParse(invalid).success, false);
});
test('credentials normalize email without changing passwords', () => {
  const parsed = credentials.parse({ email: ' USER@example.com ', password: ' password123 ' });
  assert.equal(parsed.email, 'user@example.com'); assert.equal(parsed.password, ' password123 ');
  assert.equal(credentials.safeParse({ email: 'bad', password: '123' }).success, false);
});
test('registration requires a real display name and normalizes spaces', () => {
  const account = { email: 'person@example.com', password: 'password123', name: '  Alex   Reyes  ' };
  assert.equal(registration.parse(account).name, 'Alex Reyes');
  assert.equal(registration.safeParse({ ...account, name: ' ' }).success, false);
  assert.equal(registration.safeParse({ ...account, name: 'x'.repeat(81) }).success, false);
  assert.equal(registration.safeParse({ ...account, name: 'Alex\nReyes' }).success, false);
});
test('passwords are salted and tokens are stored as hashes', async () => {
  const hash = await hashPassword('example-password-123');
  assert.notEqual(hash, await hashPassword('example-password-123'));
  assert.equal(await verifyPassword('example-password-123', hash), true);
  assert.equal(await verifyPassword('incorrect', hash), false);
  assert.equal(await verifyPassword('incorrect', undefined), false);
  assert.equal(tokenHash('token').length, 32);
});
