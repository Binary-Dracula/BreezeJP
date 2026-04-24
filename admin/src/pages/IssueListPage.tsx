import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../supabase'
import { IssueDetail } from './IssueDetail'

type IssueStatus = 'open' | 'resolved' | 'ignored'

interface IssueReport {
  id: string
  user_id: string
  content_type: 'word' | 'grammar'
  content_id: string
  content_snapshot: Record<string, unknown>
  message: string | null
  status: IssueStatus
  admin_note: string | null
  resolved_at: string | null
  created_at: string
}

export function IssueListPage() {
  const [issues, setIssues] = useState<IssueReport[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<IssueStatus | 'all'>('open')
  const [selectedIssue, setSelectedIssue] = useState<IssueReport | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  const fetchIssues = useCallback(async () => {
    setLoading(true)
    let query = supabase
      .from('issue_reports')
      .select('*')
      .order('created_at', { ascending: false })

    if (filter !== 'all') {
      query = query.eq('status', filter)
    }

    const { data, error } = await query

    if (error) {
      console.error('Failed to fetch issues:', error)
    } else {
      setIssues(data ?? [])
    }
    setLoading(false)
  }, [filter])

  useEffect(() => {
    fetchIssues()
  }, [fetchIssues])

  const showToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(null), 3000)
  }

  const handleBack = () => {
    setSelectedIssue(null)
    fetchIssues()
  }

  if (selectedIssue) {
    return (
      <IssueDetail
        issue={selectedIssue}
        onBack={handleBack}
        onToast={showToast}
      />
    )
  }

  return (
    <>
      <div className="filters">
        {(['all', 'open', 'resolved', 'ignored'] as const).map(s => (
          <button
            key={s}
            className={`filter-btn ${filter === s ? 'active' : ''}`}
            onClick={() => setFilter(s)}
          >
            {s === 'all' ? '全部' : s === 'open' ? '待处理' : s === 'resolved' ? '已解决' : '已忽略'}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="loading">加载中...</div>
      ) : issues.length === 0 ? (
        <div className="empty-state">暂无问题上报</div>
      ) : (
        <div className="issue-list">
          {issues.map(issue => (
            <div
              key={issue.id}
              className="issue-card"
              onClick={() => setSelectedIssue(issue)}
            >
              <div className="issue-card-header">
                <span className={`issue-type-badge ${issue.content_type}`}>
                  {issue.content_type === 'word' ? '单词' : '语法'}
                </span>
                <span className={`issue-status ${issue.status}`}>
                  {issue.status === 'open' ? '待处理' : issue.status === 'resolved' ? '已解决' : '已忽略'}
                </span>
              </div>
              <div className="issue-title">
                {getDisplayTitle(issue)}
              </div>
              {issue.message && (
                <div className="issue-message">{issue.message}</div>
              )}
              <div className="issue-time">
                {new Date(issue.created_at).toLocaleString('zh-CN')}
              </div>
            </div>
          ))}
        </div>
      )}

      {toast && <div className="toast">{toast}</div>}
    </>
  )
}

function getDisplayTitle(issue: IssueReport): string {
  const snap = issue.content_snapshot
  if (issue.content_type === 'word') {
    const word = snap.word as Record<string, unknown> | undefined
    if (word) {
      return `${word.word ?? ''}  ${word.primary_meaning ?? ''}`
    }
  } else {
    const grammar = snap.grammar as Record<string, unknown> | undefined
    if (grammar) {
      return String(grammar.title ?? '')
    }
  }
  return issue.content_id
}
