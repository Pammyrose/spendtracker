import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

// Generate a local database password without printing it to the terminal.
if (!existsSync('.env')) {
  writeFileSync('.env', readFileSync('.env.example', 'utf8').replace('replace-with-a-random-password', randomBytes(24).toString('hex')), { flag: 'wx' });
}
console.log('Local environment file is ready.');
