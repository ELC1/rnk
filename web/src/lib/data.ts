export type Player = {
  steamId: string
  name: string
  score: number
  kills: number
  deaths: number
  knifeKills: number
  noscopeKills: number
  kdr: number
}

export type ServerStatus = {
  online: boolean
  name: string
  map: string
  players: number
  maxPlayers: number
  ping: number
}

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'https://api.rnk.lat'

export async function getRanking(): Promise<Player[]> {
  try {
    const res = await fetch(`${API_BASE}/ranking`, { next: { revalidate: 60 } })
    if (!res.ok) return []
    return res.json()
  } catch {
    return []
  }
}

export async function getPlayer(steamId: string): Promise<Player | null> {
  try {
    const res = await fetch(`${API_BASE}/player/${steamId}`, { next: { revalidate: 30 } })
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
}

export async function getServerStatus(): Promise<ServerStatus> {
  try {
    const res = await fetch(`${API_BASE}/status`, { next: { revalidate: 15 } })
    if (!res.ok) throw new Error()
    return res.json()
  } catch {
    return { online: false, name: 'RNK | Servidor Deathmatch', map: '-', players: 0, maxPlayers: 32, ping: 0 }
  }
}
