import Link from 'next/link'
import { getPlayer } from '@/lib/data'
import { notFound } from 'next/navigation'
import styles from './page.module.css'

export const revalidate = 30

export default async function PlayerPage({ params }: { params: { steamId: string } }) {
  const player = await getPlayer(params.steamId)
  if (!player) notFound()

  const stats = [
    { label: 'Pontos', value: player.score },
    { label: 'Kills', value: player.kills },
    { label: 'Deaths', value: player.deaths },
    { label: 'KDR', value: player.kdr.toFixed(2) },
    { label: 'Knife Kills', value: player.knifeKills },
    { label: 'Noscope Kills', value: player.noscopeKills },
  ]

  return (
    <div className="container">
      <div className={styles.header}>
        <Link href="/jogadores" className={styles.back}>← Jogadores</Link>
        <h1 className={styles.title}>{player.name}</h1>
        <p className={styles.steamId}>{player.steamId}</p>
      </div>

      <div className={styles.statsGrid}>
        {stats.map(s => (
          <div key={s.label} className={styles.statCard}>
            <span className={styles.statVal}>{s.value}</span>
            <span className={styles.statLbl}>{s.label}</span>
          </div>
        ))}
      </div>

      <div className={styles.kdrBar}>
        <span className={styles.kdrLabel}>Taxa de abate</span>
        <div className={styles.barWrap}>
          <div
            className={styles.barFill}
            style={{ width: `${Math.min((player.kdr / 3) * 100, 100)}%` }}
          />
        </div>
        <span className={player.kdr >= 1.5 ? styles.kdrGood : player.kdr >= 1 ? styles.kdrNeutral : styles.kdrBad}>
          {player.kdr.toFixed(2)} KDR
        </span>
      </div>
    </div>
  )
}
