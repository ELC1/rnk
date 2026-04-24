const express = require('express')
const cors = require('cors')
const { GameDig } = require('gamedig')
const db = require('./db')
const fs = require('fs')
const path = require('path')

const app = express()
app.use(cors())
app.use(express.json())

const API_SECRET = process.env.API_SECRET || ''
const SERVER_HOST = process.env.SERVER_HOST || '127.0.0.1'
const SERVER_PORT = parseInt(process.env.SERVER_PORT || '27015')
const PORT = parseInt(process.env.PORT || '3001')

const dataDir = path.join(__dirname, '..', 'data')
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true })

function authMiddleware(req, res, next) {
  if (!API_SECRET) return next()
  const key = req.headers['x-api-key'] || req.query.key
  if (key !== API_SECRET) return res.status(401).json({ error: 'Unauthorized' })
  next()
}

function calcKdr(kills, deaths) {
  if (deaths === 0) return kills
  return Math.round((kills / deaths) * 100) / 100
}

function toPlayer(row) {
  return {
    steamId: row.steam_id,
    name: row.name,
    score: row.score,
    kills: row.kills,
    deaths: row.deaths,
    knifeKills: row.knife_kills,
    noscopeKills: row.noscope_kills,
    kdr: calcKdr(row.kills, row.deaths),
  }
}

app.get('/ranking', (req, res) => {
  const rows = db.prepare(
    'SELECT * FROM players ORDER BY score DESC, kills DESC LIMIT 100'
  ).all()
  res.json(rows.map(toPlayer))
})

app.get('/player/:steamId', (req, res) => {
  const row = db.prepare('SELECT * FROM players WHERE steam_id = ?').get(req.params.steamId)
  if (!row) return res.status(404).json({ error: 'Not found' })
  res.json(toPlayer(row))
})

app.get('/status', async (req, res) => {
  try {
    const state = await GameDig.query({
      type: 'css',
      host: SERVER_HOST,
      port: SERVER_PORT,
      attemptTimeout: 5000,
    })
    res.json({
      online: true,
      name: state.name,
      map: state.map,
      players: state.players.length,
      maxPlayers: state.maxplayers,
      ping: Math.round(state.ping),
    })
  } catch {
    res.json({
      online: false,
      name: 'RNK | Servidor Deathmatch',
      map: '-',
      players: 0,
      maxPlayers: 32,
      ping: 0,
    })
  }
})

app.post('/sync', authMiddleware, (req, res) => {
  const players = req.body
  if (!Array.isArray(players)) return res.status(400).json({ error: 'Expected array' })

  const upsert = db.prepare(`
    INSERT INTO players (steam_id, name, score, kills, deaths, knife_kills, noscope_kills, updated_at)
    VALUES (@steamId, @name, @score, @kills, @deaths, @knifeKills, @noscopeKills, unixepoch())
    ON CONFLICT(steam_id) DO UPDATE SET
      name = excluded.name,
      score = excluded.score,
      kills = excluded.kills,
      deaths = excluded.deaths,
      knife_kills = excluded.knife_kills,
      noscope_kills = excluded.noscope_kills,
      updated_at = unixepoch()
  `)

  const upsertMany = db.transaction((list) => {
    for (const p of list) upsert.run(p)
  })

  upsertMany(players)
  res.json({ ok: true, count: players.length })
})

app.listen(PORT, () => {
  console.log(`RNK API running on port ${PORT}`)
})
