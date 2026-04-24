import Link from 'next/link'
import { getRanking, getServerStatus } from '@/lib/data'
import styles from './page.module.css'

export const revalidate = 30

export default async function HomePage() {
  const [players, status] = await Promise.all([getRanking(), getServerStatus()])
  const top3 = players.slice(0, 3)

  return (
    <div className={styles.wrap}>
      <section className={styles.hero}>
        <div className={styles.heroContent}>
          <h1 className={styles.heroTitle}>
            <span className={styles.accent}>RNK</span> Deathmatch
          </h1>
          <p className={styles.heroSub}>Servidor Counter-Strike: Source — Dust2 24/7</p>
          <div className={styles.heroActions}>
            <a href="steam://connect/rnk.lat:27015" className={styles.btnPrimary}>
              Conectar ao Servidor
            </a>
            <Link href="/ranking" className={styles.btnSecondary}>
              Ver Ranking
            </Link>
          </div>
        </div>
      </section>

      <div className={styles.grid}>
        <section className={styles.card}>
          <h2 className={styles.cardTitle}>Status do Servidor</h2>
          <div className={styles.statusRow}>
            <span className={status.online ? styles.dotOnline : styles.dotOffline} />
            <span className={styles.statusName}>{status.name}</span>
          </div>
          {status.online ? (
            <div className={styles.statusDetails}>
              <div className={styles.statLine}><span className={styles.statLabel}>Mapa</span><span>{status.map}</span></div>
              <div className={styles.statLine}><span className={styles.statLabel}>Jogadores</span><span>{status.players}/{status.maxPlayers}</span></div>
              <div className={styles.statLine}><span className={styles.statLabel}>Ping</span><span>{status.ping}ms</span></div>
            </div>
          ) : (
            <p className={styles.offline}>Servidor offline</p>
          )}
          <Link href="/servidor" className={styles.cardLink}>Mais detalhes →</Link>
        </section>

        <section className={styles.card}>
          <h2 className={styles.cardTitle}>Top 3 Jogadores</h2>
          {top3.length === 0 ? (
            <p className={styles.offline}>Sem dados disponíveis</p>
          ) : (
            <ol className={styles.topList}>
              {top3.map((p, i) => (
                <li key={p.steamId} className={styles.topItem}>
                  <span className={styles.rank}>#{i + 1}</span>
                  <Link href={`/jogadores/${p.steamId}`} className={styles.playerName}>{p.name}</Link>
                  <span className={styles.playerScore}>{p.score} pts</span>
                </li>
              ))}
            </ol>
          )}
          <Link href="/ranking" className={styles.cardLink}>Ranking completo →</Link>
        </section>

        <section className={styles.card}>
          <h2 className={styles.cardTitle}>Como Jogar</h2>
          <ul className={styles.howList}>
            <li>Abra o CS:Source</li>
            <li>No console: <code className={styles.code}>connect rnk.lat</code></li>
            <li>ou clique em "Conectar ao Servidor"</li>
          </ul>
          <p className={styles.howNote}>Servidor Deathmatch — respawn automático, sem freezetime.</p>
        </section>
      </div>
    </div>
  )
}
