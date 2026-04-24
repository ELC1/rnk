const express = require('express')
const cors = require('cors')
const { GameDig } = require('gamedig')
const { getDb, save } = require('./db')

const app = express()
app.use(cors())
app.use(express.json())

const API_SECRET  = process.env.API_SECRET  || ''
const SERVER_HOST = process.env.SERVER_HOST || '127.0.0.1'
const SERVER_PORT = parseInt(process.env.SERVER_PORT || '27015')
const PORT        = parseInt(process.env.PORT || '3001')

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

function rowToPlayer(row) {
  const [steam_id, name, score, kills, deaths, knife_kills, noscope_kills] = row
  return {
    steamId: steam_id,
    name,
    score,
    kills,
    deaths,
    knifeKills: knife_kills,
    noscopeKills: noscope_kills,
    kdr: calcKdr(kills, deaths),
  }
}

app.get('/ranking', async (req, res) => {
  try {
    const db = await getDb()
    const result = db.exec('SELECT steam_id, name, score, kills, deaths, knife_kills, noscope_kills FROM players ORDER BY score DESC, kills DESC LIMIT 100')
    if (!result.length) return res.json([])
    res.json(result[0].values.map(rowToPlayer))
  } catch (e) {
    res.status(500).json({ error: e.message })
  }
})

app.get('/player/:steamId', async (req, res) => {
  try {
    const db = await getDb()
    const result = db.exec(
      'SELECT steam_id, name, score, kills, deaths, knife_kills, noscope_kills FROM players WHERE steam_id = ?',
      [req.params.steamId]
    )
    if (!result.length || !result[0].values.length) return res.status(404).json({ error: 'Not found' })
    res.json(rowToPlayer(result[0].values[0]))
  } catch (e) {
    res.status(500).json({ error: e.message })
  }
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
    res.json({ online: false, name: 'RNK | Servidor Deathmatch', map: '-', players: 0, maxPlayers: 32, ping: 0 })
  }
})

app.post('/sync', authMiddleware, async (req, res) => {
  const players = req.body
  if (!Array.isArray(players)) return res.status(400).json({ error: 'Expected array' })

  try {
    const db = await getDb()
    for (const p of players) {
      db.run(`
        INSERT INTO players (steam_id, name, score, kills, deaths, knife_kills, noscope_kills, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, strftime('%s','now'))
        ON CONFLICT(steam_id) DO UPDATE SET
          name          = excluded.name,
          score         = excluded.score,
          kills         = excluded.kills,
          deaths        = excluded.deaths,
          knife_kills   = excluded.knife_kills,
          noscope_kills = excluded.noscope_kills,
          updated_at    = excluded.updated_at
      `, [p.steamId, p.name, p.score, p.kills, p.deaths, p.knifeKills, p.noscopeKills])
    }
    save()
    res.json({ ok: true, count: players.length })
  } catch (e) {
    res.status(500).json({ error: e.message })
  }
})

app.listen(PORT, () => console.log(`RNK API running on port ${PORT}`))
