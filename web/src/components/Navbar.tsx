'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import styles from './Navbar.module.css'

const links = [
  { href: '/', label: 'Início' },
  { href: '/ranking', label: 'Ranking' },
  { href: '/jogadores', label: 'Jogadores' },
  { href: '/servidor', label: 'Servidor' },
]

export default function Navbar() {
  const path = usePathname()
  return (
    <nav className={styles.nav}>
      <div className={styles.inner}>
        <Link href="/" className={styles.logo}>
          <span className={styles.logoAccent}>RNK</span>
          <span className={styles.logoSub}>Deathmatch</span>
        </Link>
        <div className={styles.links}>
          {links.map(l => (
            <Link key={l.href} href={l.href} className={path === l.href ? styles.active : styles.link}>
              {l.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  )
}
