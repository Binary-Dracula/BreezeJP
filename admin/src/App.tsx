import { useState, useEffect } from 'react'
import { supabase } from './supabase'
import type { Session } from '@supabase/supabase-js'
import { LoginPage } from './pages/LoginPage'
import { IssueListPage } from './pages/IssueListPage'

export default function App() {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })

    return () => subscription.unsubscribe()
  }, [])

  if (loading) {
    return <div className="loading">Loading...</div>
  }

  if (!session) {
    return <LoginPage />
  }

  return (
    <div className="app">
      <div className="header">
        <h1>BreezeJP Issues</h1>
        <button onClick={() => supabase.auth.signOut()}>退出</button>
      </div>
      <IssueListPage />
    </div>
  )
}
