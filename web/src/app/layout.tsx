import type { Metadata } from 'next'
import './globals.css'
import Navbar from '@/components/Navbar'

export const metadata: Metadata = {
  title: 'RNK | Servidor Deathmatch',
  description: 'Servidor RNK de Counter-Strike: Source — Deathmatch Dust2',
  openGraph: {
    title: 'RNK | Servidor Deathmatch',
    description: 'Ranking, estatísticas e informações do servidor RNK CSS.',
    url: 'https://rnk.lat',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>
        <Navbar />
        <main>{children}</main>
        <footer style={{ textAlign: 'center', padding: '40px 0', color: 'var(--muted)', fontSize: 13 }}>
          © {new Date().getFullYear()} RNK — Counter-Strike: Source
        </footer>
      </body>
    </html>
  )
}
