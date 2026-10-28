// Separate account, session, and backup tables. LONGTEXT works on both MySQL and XAMPP MariaDB.
// The versioned app document preserves custom categories, themes, notes, and reminders together.
export async function createTables(db) {
  await db.query(`CREATE TABLE IF NOT EXISTS st_users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(254) NOT NULL UNIQUE,
    name VARCHAR(80) NOT NULL DEFAULT '',
    password_hash VARCHAR(256) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
  // Upgrade existing accounts without replacing their IDs, passwords, or backups.
  const [nameColumns] = await db.query("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'st_users' AND COLUMN_NAME = 'name'");
  if (!nameColumns.length) await db.query("ALTER TABLE st_users ADD COLUMN name VARCHAR(80) NOT NULL DEFAULT '' AFTER email");
  await db.query(`CREATE TABLE IF NOT EXISTS st_sessions (
    token_hash BINARY(32) NOT NULL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    expires_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES st_users(id) ON DELETE CASCADE,
    INDEX (expires_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
  await db.query(`CREATE TABLE IF NOT EXISTS st_backups (
    user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    document LONGTEXT NULL,
    revision INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at DATETIME NULL,
    FOREIGN KEY (user_id) REFERENCES st_users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
}
