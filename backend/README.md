# SpendTracker Node.js + MySQL API

This backend works with **XAMPP MariaDB or MySQL**. Apache is optional: Flutter calls Node.js directly.

## Local Windows setup

1. Start **MySQL** in the XAMPP Control Panel.
2. In this `backend` directory, run `npm install`.
3. Copy `.env.example` to `.env` and set a random `DB_PASSWORD`. A local `.env` may already have been generated during setup. Do not commit it.
4. Run `npm run db:init`. It creates the `spendtracker_api` database, three tables, and a limited `spendtracker_app` database account. The admin login defaults to XAMPP's `root` with an empty password; change `DB_ADMIN_PASSWORD` if yours differs. Existing database account passwords are not changed by this script.
5. Run `npm start`. Check `http://127.0.0.1:3000/health` for `{"status":"ok","database":"connected"}`.
6. Run Flutter. Tap **Get Started** on the welcome screen, then sign in or create an account. Successful authentication opens Home. Use **More → Settings → Data → Cloud backup** to save or restore data.

The Android emulator reaches your computer at `http://10.0.2.2:3000`. Desktop uses `http://127.0.0.1:3000`. For a physical phone, set `HOST=0.0.0.0`, use your computer's private LAN IP in the app, and allow Node through the local firewall. Only debug builds accept local HTTP; deployed builds require an HTTPS URL. Flutter web can use `WEB_ORIGIN` for its exact browser origin.

You can set the initial app URL using `flutter run --dart-define=API_BASE_URL=https://your-api.example.com`. The app's Server URL field also lets you change it before signing in.

## How data works

- Sign in after the welcome screen to load the account's current MySQL records. New accounts start empty. Demo records are used only by tests, not the live app.
- Changes save automatically through a serialized queue. Bills, paid/unpaid status, payment plans, categories, activity, and settings are stored together in the account's versioned document in MySQL.
- Android retains pending changes in a cache keyed by server and account. Failed saves remain visibly marked and can be retried. A stale revision never silently replaces newer server data.
- Signing out hides the records and cancels that account's device reminders. Signing into a different account loads only its records.
- **Save to server** can deliberately replace a reviewed server revision. **Restore from server** reloads its records after confirmation. Create a local JSON export to retain an independent backup file.
- The first live-data upgrade archives the old device JSON. Its first signed-in owner can export it from **Backup & Restore → Export previous device backup**, and explicitly restore it if those old records are wanted.
- Revision checks reject stale uploads from another device. Refresh server status and review the counts before deliberately replacing the newer copy.
- The latest 200 transaction activity events are included. Importing a backup does not invent new notifications.
- Sessions are held in app memory; closing the app requires signing in again. Server sessions expire after seven days and are revoked by Sign out.
- Clear All Data in the live app clears the current account's records and saves the change to MySQL after its confirmation.

## Database tables

| Table | Purpose |
| --- | --- |
| `st_users` | Display name, unique email, and salted scrypt password hash |
| `st_sessions` | Hashed, expiring bearer tokens |
| `st_backups` | One versioned app document per account |

The API uses parameterized SQL, account-scoped queries, validation, an 8 MB request limit, and sign-in rate limiting. Database credentials stay in `.env`, outside Flutter and outside app exports. Financial records and passwords are not logged.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Database connection check |
| POST | `/auth/register` | `{name,email,password}` → account and session |
| POST | `/auth/login` | `{email,password}` → session |
| DELETE | `/auth/session` | Revoke current bearer token |
| PATCH | `/profile` | Update the signed-in account's `{name}` |
| GET | `/backup` | Current account's `{revision,updatedAt,data}` |
| PUT | `/backup` | `{revision,data}` → next revision; HTTP 409 if stale |

Protected routes use `Authorization: Bearer <token>`. There is no client-supplied user ID.

Registration requires a name of up to 80 characters. Sign-in responses include the saved name for the Home greeting and account profile in More. `npm run db:init` also upgrades older databases by adding the name column; accounts without a saved name keep their email username as the display fallback.

Use **More → Account profile → Edit** to update your name. The email stays unchanged. The Home greeting uses device-local time: morning from 5 AM, afternoon from noon, and evening from 6 PM through the night. It updates at minute boundaries and when the app resumes.

## Checks

`npm test` checks credentials, password hashing, and document validation without MySQL. `npm run test:db` checks the actual API against the configured database, creates two uniquely named temporary test accounts, and deletes only those accounts afterward.

For deployment, use HTTPS, a private database connection, and backups of the database. This initial local-development backend does not include email verification, password recovery, or automated multi-device merging.
