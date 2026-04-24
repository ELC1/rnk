import { getServerStatus } from '@/lib/data'
import styles from './page.module.css'

export const revalidate = 15

export default async function ServidorPage() {
  const status = await getServerStatus()

  return (
    <div className="container">
      <div className={styles.header}>
        <h1 className={styles.title}>Servidor</h1>
        <p className={styles.sub}>Informações e status em tempo real</p>
      </div>

      <div className={styles.grid}>
        <div className={styles.card}>
          <div className={styles.statusRow}>
            <span className={status.online ? styles.dotOnline : styles.dotOffline} />
            <span className={styles.statusText}>{status.online ? 'Online' : 'Offline'}</span>
          </div>
          <h2 className={styles.serverName}>{status.name}</h2>

          <div className={styles.infoGrid}>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Endereço</span>
              <code className={styles.infoVal}>rnk.lat:27015</code>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Jogo</span>
              <span className={styles.infoVal}>Counter-Strike: Source</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Modo</span>
              <span className={styles.infoVal}>Deathmatch</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Mapa</span>
              <span className={styles.infoVal}>{status.map}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Jogadores</span>
              <span className={styles.infoVal}>{status.players} / {status.maxPlayers}</span>
            </div>
            {status.online && (
              <div className={styles.infoItem}>
                <span className={styles.infoLabel}>Ping</span>
                <span className={styles.infoVal}>{status.ping}ms</span>
              </div>
            )}
          </div>

          {status.online && (
            <div className={styles.playerBar}>
              <div className={styles.barWrap}>
                <div
                  className={styles.barFill}
                  style={{ width: `${(status.players / status.maxPlayers) * 100}%` }}
                />
              </div>
              <span className={styles.barLabel}>{status.players}/{status.maxPlayers} jogadores</span>
            </div>
          )}
        </div>

        <div className={styles.card}>
          <h2 className={styles.cardTitle}>Como Conectar</h2>
          <div className={styles.connectMethods}>
            <div className={styles.method}>
              <span className={styles.methodNum}>1</span>
              <div>
                <p className={styles.methodTitle}>Via console no CSS</p>
                <code className={styles.code}>connect rnk.lat</code>
              </div>
            </div>
            <div className={styles.method}>
              <span className={styles.methodNum}>2</span>
              <div>
                <p className={styles.methodTitle}>Link direto Steam</p>
                <a href="steam://connect/rnk.lat:27015" className={styles.steamLink}>
                  steam://connect/rnk.lat:27015
                </a>
              </div>
            </div>
            <div className={styles.method}>
              <span className={styles.methodNum}>3</span>
              <div>
                <p className={styles.methodTitle}>Browser de servidores</p>
                <p className={styles.methodDesc}>Procure por "RNK" na aba Favoritos ou Internet</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
