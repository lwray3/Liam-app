const sqlite3 = require("sqlite3").verbose();
const db = new sqlite3.Database("users.db");

// Helper: add a column only if it's missing
function ensureColumn(table, columnDef, cb) {
  const columnName = columnDef.split(/\s+/)[0];
  db.all(`PRAGMA table_info(${table})`, (err, rows) => {
    if (err) return cb && cb(err);
    const exists = rows.some((r) => r.name === columnName);
    if (exists) return cb && cb(null);
    db.run(`ALTER TABLE ${table} ADD COLUMN ${columnDef}`, cb);
  });
}

db.serialize(() => {
  // Enforce foreign keys
  db.run(`PRAGMA foreign_keys = ON`);

  // Users
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL
    )
  `);

  // Moods
  db.run(`
    CREATE TABLE IF NOT EXISTS moods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      mood REAL NOT NULL,          -- 1..10 (or your scale)
      date TEXT NOT NULL,          -- ISO 8601
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Goals (1:1 with user)
  db.run(`
    CREATE TABLE IF NOT EXISTS goals (
      user_id INTEGER PRIMARY KEY,
      goal_text TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Sleep
  db.run(`
    CREATE TABLE IF NOT EXISTS sleep (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      date TEXT NOT NULL,          -- ISO 8601
      hours REAL NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Journals
  db.run(`
    CREATE TABLE IF NOT EXISTS journals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      title TEXT,
      entry TEXT,
      timestamp TEXT,              -- ISO 8601
      mood TEXT,                   -- e.g., "😊 Good"
      tags TEXT,                   -- JSON array string
      gratitude TEXT,              -- JSON array string
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Pillars (include color + progress)
  db.run(`
    CREATE TABLE IF NOT EXISTS pillars (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      color INTEGER DEFAULT 4280391411, -- 0xFF3B82F6
      progress INTEGER DEFAULT 0,       -- 0..100
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Habits (used by /pillars/:pillarId/habits and /habits/:id/toggle)
  db.run(`
    CREATE TABLE IF NOT EXISTS habits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      pillar_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      completed INTEGER DEFAULT 0,  -- 0/1
      streak INTEGER DEFAULT 0,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(pillar_id) REFERENCES pillars(id) ON DELETE CASCADE
    )
  `);

// In db.js (run once; safe with IF NOT EXISTS)
db.run(`
  CREATE TABLE IF NOT EXISTS friendships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_low  INTEGER NOT NULL,   -- smaller id of the pair (canonical order)
    user_high INTEGER NOT NULL,   -- larger id of the pair
    requester_id INTEGER NOT NULL, -- who sent the request
    status TEXT NOT NULL CHECK(status IN ('pending','accepted','declined')),
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_low, user_high),
    FOREIGN KEY(user_low)  REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(user_high) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(requester_id) REFERENCES users(id) ON DELETE CASCADE
  )
`);

function pair(u1, u2) {
  const a = Math.min(u1, u2);
  const b = Math.max(u1, u2);
  return { a, b };
}


ensureColumn("users", "friend_code TEXT UNIQUE", (err) => {
  if (!err) {
    // optional: backfill a code for existing users
    db.all("SELECT id FROM users WHERE friend_code IS NULL", (e, rows) => {
      if (!e) {
        for (const r of rows) {
          const code = Math.random().toString(36).slice(2, 8).toUpperCase();
          db.run("UPDATE users SET friend_code = ? WHERE id = ?", [code, r.id]);
        }
      }
    });
  }
});

  // Habit events (used by /habit/complete and /predict_from_history)
  db.run(`
    CREATE TABLE IF NOT EXISTS habit_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      habit_name TEXT NOT NULL,
      date TEXT NOT NULL,             -- ISO 8601
      -- optional/nullable fields to avoid breaking /habit/complete inserts
      pillar_id INTEGER,
      title TEXT,
      completed INTEGER DEFAULT 0,
      streak INTEGER DEFAULT 0,
      UNIQUE(user_id, habit_name, date),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(pillar_id) REFERENCES pillars(id) ON DELETE SET NULL
    )
  `);

  // --- Migrations for older DBs ---
  ensureColumn("journals", "mood TEXT", (err) => {
    if (err) console.error("Add journals.mood failed:", err.message);
  });
  ensureColumn("journals", "tags TEXT", (err) => {
    if (err) console.error("Add journals.tags failed:", err.message);
    else db.run(`UPDATE journals SET tags = '[]' WHERE tags IS NULL`);
  });
  ensureColumn("journals", "gratitude TEXT", (err) => {
    if (err) console.error("Add journals.gratitude failed:", err.message);
    else db.run(`UPDATE journals SET gratitude = '[]' WHERE gratitude IS NULL`);
  });
  ensureColumn("pillars", "color INTEGER DEFAULT 4280391411", (err) => {
    if (err) console.error("Add pillars.color failed:", err.message);
  });
  ensureColumn("pillars", "progress INTEGER DEFAULT 0", (err) => {
    if (err) console.error("Add pillars.progress failed:", err.message);
  });

  // Indexes
  db.run(`CREATE INDEX IF NOT EXISTS idx_moods_user_date ON moods(user_id, date)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_sleep_user_date ON sleep(user_id, date)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_journals_user_time ON journals(user_id, timestamp)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_pillars_user ON pillars(user_id)`);
  db.run(`
    CREATE INDEX IF NOT EXISTS idx_habits_user_pillar ON habits(user_id, pillar_id)
  `);
  db.run(`
    CREATE INDEX IF NOT EXISTS idx_habitevents_user_name_date
      ON habit_events(user_id, habit_name, date)
  `);
});

module.exports = db;
