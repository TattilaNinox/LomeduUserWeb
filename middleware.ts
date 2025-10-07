import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// Publicly accessible routes that do not require authentication
const PUBLIC_PATHS = ['/login', '/register', '/verify-email', '/api', '/']

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Skip auth check for public paths
  if (PUBLIC_PATHS.some((path) => pathname.startsWith(path))) {
    return NextResponse.next()
  }

  // Very simple auth check – adapt to your actual auth cookie / header
  const authToken = request.cookies.get('authToken')?.value

  // If no token, redirect to login
  if (!authToken) {
    const loginUrl = request.nextUrl.clone()
    loginUrl.pathname = '/login'
    loginUrl.searchParams.set('from', pathname)
    return NextResponse.redirect(loginUrl)
  }

  // For authenticated requests, disable caching so that history cannot serve stale pages
  const response = NextResponse.next()
  response.headers.set('Cache-Control', 'no-store, must-revalidate')
  return response
}

// Apply middleware to all routes except Next.js internals and static assets
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}
