import Link from 'next/link'
import { getRanking } from '@/lib/data'
import styles from './page.module.css'

export const revalidate = 60

export default async function JogadoresPage() {
  const players = await getRanking()

  return (
    <div className="container">
      <div className={styles.header}>
        <h1 className={styles.title}>Jogadores</h1>
        <p className={styles.sub}>{players.length} jogadores registrados</p>
      </div>

      {players.length === 0 ? (
        <p className={styles.empty}>Nenhum jogador registrado ainda.</p>
      ) : (
        <div className={styles.grid}>
          {players.map((p, i) => (
            <Link key={p.steamId} href={`/jogadores/${p.steamId}`} className={styles.card}>
              <div className={styles.cardTop}>
                <span className={styles.pos}>#{i + 1}</span>
                <span className={styles.name}>{p.name}</span>
              </div>
              <div className={styles.stats}>
                <div className={styles.stat}>
                  <span className={styles.statVal}>{p.score}</span>
                  <span className={styles.statLbl}>pts</span>
                </div>
                <div className={styles.stat}>
                  <span className={styles.statVal}>{p.kills}</span>
                  <span className={styles.statLbl}>kills</span>
                </div>
                <div className={styles.stat}>
                  <span className={styles.statVal}>{p.kdr.toFixed(2)}</span>
                  <span className={styles.statLbl}>kdr</span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
