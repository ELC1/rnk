import Link from 'next/link'
import { getRanking } from '@/lib/data'
import styles from './page.module.css'

export const revalidate = 60

export default async function RankingPage() {
  const players = await getRanking()

  return (
    <div className="container">
      <div className={styles.header}>
        <h1 className={styles.title}>Ranking</h1>
        <p className={styles.sub}>Top jogadores do servidor RNK Deathmatch</p>
      </div>

      {players.length === 0 ? (
        <p className={styles.empty}>Nenhum dado de ranking disponível.</p>
      ) : (
        <div className={styles.tableWrap}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th className={styles.th}>#</th>
                <th className={styles.th}>Jogador</th>
                <th className={styles.th}>Pontos</th>
                <th className={styles.th}>Kills</th>
                <th className={styles.th}>Deaths</th>
                <th className={styles.th}>KDR</th>
                <th className={styles.th}>HS</th>
                <th className={styles.th}>Noscope</th>
              </tr>
            </thead>
            <tbody>
              {players.map((p, i) => (
                <tr key={p.steamId} className={i % 2 === 0 ? styles.rowEven : styles.rowOdd}>
                  <td className={styles.td}>
                    {i === 0 ? <span className={styles.gold}>1</span>
                     : i === 1 ? <span className={styles.silver}>2</span>
                     : i === 2 ? <span className={styles.bronze}>3</span>
                     : <span className={styles.rank}>{i + 1}</span>}
                  </td>
                  <td className={styles.td}>
                    <Link href={`/jogadores/${p.steamId}`} className={styles.playerLink}>
                      {p.name}
                    </Link>
                  </td>
                  <td className={styles.td}><strong>{p.score}</strong></td>
                  <td className={styles.td}>{p.kills}</td>
                  <td className={styles.td}>{p.deaths}</td>
                  <td className={styles.td}>
                    <span className={p.kdr >= 1.5 ? styles.kdrGood : p.kdr >= 1 ? styles.kdrNeutral : styles.kdrBad}>
                      {p.kdr.toFixed(2)}
                    </span>
                  </td>
                  <td className={styles.td}>{p.knifeKills}</td>
                  <td className={styles.td}>{p.noscopeKills}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
