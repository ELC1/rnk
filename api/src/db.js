const initSqlJs = require('sql.js')
const fs = require('fs')
const path = require('path')

const DB_PATH = path.join(__dirname, '..', 'data', 'rnk.db')
const dataDir = path.join(__dirname, '..', 'data')

let db = null

async function getDb() {
  if (db) return db

  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true })

  const SQL = await initSqlJs()

  if (fs.existsSync(DB_PATH)) {
    const fileBuffer = fs.readFileSync(DB_PATH)
    db = new SQL.Database(fileBuffer)
  } else {
    db = new SQL.Database()
  }

  db.run(`
    CREATE TABLE IF NOT EXISTS players (
      steam_id      TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      score         INTEGER DEFAULT 0,
      kills         INTEGER DEFAULT 0,
      deaths        INTEGER DEFAULT 0,
      knife_kills   INTEGER DEFAULT 0,
      noscope_kills INTEGER DEFAULT 0,
      updated_at    INTEGER DEFAULT (strftime('%s','now'))
    );
  `)

  save()
  return db
}

function save() {
  if (!db) return
  const data = db.export()
  fs.writeFileSync(DB_PATH, Buffer.from(data))
}

module.exports = { getDb, save }
