const Database = require('better-sqlite3')
const path = require('path')

const db = new Database(path.join(__dirname, '..', 'data', 'rnk.db'))

db.exec(`
  CREATE TABLE IF NOT EXISTS players (
    steam_id   TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    score      INTEGER DEFAULT 0,
    kills      INTEGER DEFAULT 0,
    deaths     INTEGER DEFAULT 0,
    knife_kills   INTEGER DEFAULT 0,
    noscope_kills INTEGER DEFAULT 0,
    updated_at INTEGER DEFAULT (unixepoch())
  );
`)

module.exports = db
