import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import DeviceChecker from './components/DeviceChecker'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'OrLomed Admin',
  description: 'OrLomed Adminisztrációs Felület',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="hu">
      <body className={inter.className}>
        <DeviceChecker />
        {children}
      </body>
    </html>
  )
} 