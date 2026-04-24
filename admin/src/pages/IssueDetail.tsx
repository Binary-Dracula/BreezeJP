import { useState } from 'react'
import { supabase } from '../supabase'

interface IssueReport {
  id: string
  user_id: string
  content_type: 'word' | 'grammar'
  content_id: string
  content_snapshot: Record<string, unknown>
  message: string | null
  status: string
  admin_note: string | null
  resolved_at: string | null
  created_at: string
}

interface Props {
  issue: IssueReport
  onBack: () => void
  onToast: (msg: string) => void
}

export function IssueDetail({ issue, onBack, onToast }: Props) {
  const [adminNote, setAdminNote] = useState(issue.admin_note ?? '')
  const [saving, setSaving] = useState(false)
  const [editedSnapshot, setEditedSnapshot] = useState<Record<string, unknown>>(
    JSON.parse(JSON.stringify(issue.content_snapshot))
  )

  const updateField = (section: string, key: string, value: string) => {
    setEditedSnapshot(prev => {
      const next = JSON.parse(JSON.stringify(prev))
      if (next[section] && typeof next[section] === 'object' && !Array.isArray(next[section])) {
        (next[section] as Record<string, unknown>)[key] = value
      }
      return next
    })
  }

  const updateArrayField = (section: string, index: number, key: string, value: string) => {
    setEditedSnapshot(prev => {
      const next = JSON.parse(JSON.stringify(prev))
      const arr = next[section]
      if (Array.isArray(arr) && arr[index]) {
        arr[index][key] = value
      }
      return next
    })
  }

  /** 保存数据修改到实际数据表 + 标记 issue 为 resolved */
  const handleSaveAndResolve = async () => {
    setSaving(true)
    try {
      if (issue.content_type === 'word') {
        await saveWordChanges()
      } else {
        await saveGrammarChanges()
      }

      // 更新 issue 状态
      const { error } = await supabase
        .from('issue_reports')
        .update({
          status: 'resolved',
          admin_note: adminNote || null,
          resolved_at: new Date().toISOString(),
        })
        .eq('id', issue.id)

      if (error) throw error
      onToast('已保存并标记为已解决')
      onBack()
    } catch (e) {
      onToast(`保存失败: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setSaving(false)
    }
  }

  /** 仅更新 issue 状态（不修改数据） */
  const handleUpdateStatus = async (status: 'resolved' | 'ignored') => {
    setSaving(true)
    try {
      const { error } = await supabase
        .from('issue_reports')
        .update({
          status,
          admin_note: adminNote || null,
          resolved_at: status === 'resolved' ? new Date().toISOString() : null,
        })
        .eq('id', issue.id)

      if (error) throw error
      onToast(status === 'resolved' ? '已标记为已解决' : '已忽略')
      onBack()
    } catch (e) {
      onToast(`操作失败: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setSaving(false)
    }
  }

  /** 保存单词修改到 words + word_details 表 */
  const saveWordChanges = async () => {
    const wordData = editedSnapshot.word as Record<string, unknown> | undefined
    if (wordData) {
      const { error: wordErr } = await supabase
        .from('words')
        .update({
          word: wordData.word,
          reading: wordData.reading,
          romaji: wordData.romaji,
          pitch_accent: wordData.pitch_accent,
          jlpt_level: wordData.jlpt_level,
          part_of_speech: wordData.part_of_speech,
          transitivity: wordData.transitivity,
          primary_meaning: wordData.primary_meaning,
        })
        .eq('id', issue.content_id)

      if (wordErr) throw wordErr
    }

    const richContent = editedSnapshot.rich_content
    if (richContent) {
      const contentValue = typeof richContent === 'string'
        ? JSON.parse(richContent)
        : richContent

      const { error: detailErr } = await supabase
        .from('word_details')
        .update({ rich_content: contentValue })
        .eq('word_id', issue.content_id)

      if (detailErr) throw detailErr
    }
  }

  /** 保存语法修改到 grammars + grammar_meanings + grammar_examples 表 */
  const saveGrammarChanges = async () => {
    const grammarData = editedSnapshot.grammar as Record<string, unknown> | undefined
    if (grammarData) {
      const { error } = await supabase
        .from('grammars')
        .update({ title: grammarData.title })
        .eq('id', issue.content_id)

      if (error) throw error
    }

    const meanings = editedSnapshot.meanings as Array<Record<string, unknown>> | undefined
    if (meanings) {
      for (const m of meanings) {
        const { error } = await supabase
          .from('grammar_meanings')
          .update({
            definition_cn: m.definition_cn,
            definition_en: m.definition_en,
            how_to_use_cn: m.how_to_use_cn,
            how_to_use_en: m.how_to_use_en,
          })
          .eq('id', m.id)

        if (error) throw error
      }
    }

    const examples = editedSnapshot.examples as Array<Record<string, unknown>> | undefined
    if (examples) {
      for (const ex of examples) {
        const { error } = await supabase
          .from('grammar_examples')
          .update({
            sentence: ex.sentence,
            translation_cn: ex.translation_cn,
            translation_en: ex.translation_en,
          })
          .eq('id', ex.id)

        if (error) throw error
      }
    }
  }

  return (
    <>
      <button className="back-btn" onClick={onBack}>← 返回列表</button>

      {/* 用户信息 */}
      <div className="detail-section">
        <h2>用户反馈</h2>
        <div className="snapshot-field">
          <label>类型</label>
          <input value={issue.content_type === 'word' ? '单词' : '语法'} className="readonly" readOnly />
        </div>
        <div className="snapshot-field">
          <label>提交时间</label>
          <input value={new Date(issue.created_at).toLocaleString('zh-CN')} className="readonly" readOnly />
        </div>
        {issue.message && (
          <div className="snapshot-field">
            <label>用户描述</label>
            <textarea value={issue.message} className="readonly" readOnly />
          </div>
        )}
      </div>

      {/* 数据快照（可编辑） */}
      {issue.content_type === 'word' ? (
        <WordSnapshotEditor
          snapshot={editedSnapshot}
          onUpdateField={updateField}
          onUpdateArrayField={updateArrayField}
        />
      ) : (
        <GrammarSnapshotEditor
          snapshot={editedSnapshot}
          onUpdateField={updateField}
          onUpdateArrayField={updateArrayField}
        />
      )}

      {/* 管理员备注 */}
      <div className="detail-section">
        <h2>管理员备注</h2>
        <div className="snapshot-field">
          <textarea
            value={adminNote}
            onChange={e => setAdminNote(e.target.value)}
            placeholder="处理备注（可选）"
          />
        </div>
      </div>

      {/* 操作按钮 */}
      <div className="actions">
        <button
          className="btn-primary"
          onClick={handleSaveAndResolve}
          disabled={saving}
        >
          {saving ? '保存中...' : '保存修改并解决'}
        </button>
        <button
          className="btn-success"
          onClick={() => handleUpdateStatus('resolved')}
          disabled={saving}
        >
          仅标记已解决
        </button>
        <button
          className="btn-danger"
          onClick={() => handleUpdateStatus('ignored')}
          disabled={saving}
        >
          忽略
        </button>
      </div>
    </>
  )
}

/* ====== Word Snapshot Editor ====== */
function WordSnapshotEditor({ snapshot, onUpdateField }: {
  snapshot: Record<string, unknown>
  onUpdateField: (section: string, key: string, value: string) => void
  onUpdateArrayField: (section: string, index: number, key: string, value: string) => void
}) {
  const word = (snapshot.word ?? {}) as Record<string, unknown>
  const richContentRaw = snapshot.rich_content
  let richContent: Record<string, unknown> = {}
  try {
    richContent = typeof richContentRaw === 'string'
      ? JSON.parse(richContentRaw)
      : (richContentRaw as Record<string, unknown>) ?? {}
  } catch {
    // keep empty
  }

  const wordFields = [
    { key: 'word', label: '日文' },
    { key: 'reading', label: '读音' },
    { key: 'romaji', label: '罗马音' },
    { key: 'pitch_accent', label: '声调' },
    { key: 'jlpt_level', label: 'JLPT' },
    { key: 'part_of_speech', label: '词性' },
    { key: 'transitivity', label: '自他性' },
    { key: 'primary_meaning', label: '首要释义' },
  ]

  return (
    <>
      <div className="detail-section">
        <h2>单词基本信息</h2>
        {wordFields.map(({ key, label }) => (
          <div className="snapshot-field" key={key}>
            <label>{label}</label>
            <input
              value={String(word[key] ?? '')}
              onChange={e => onUpdateField('word', key, e.target.value)}
            />
          </div>
        ))}
      </div>

      <div className="detail-section">
        <h2>详细内容 (rich_content)</h2>
        <div className="snapshot-field">
          <label>完整 JSON</label>
          <textarea
            style={{ minHeight: 200, fontFamily: 'monospace', fontSize: 12 }}
            value={JSON.stringify(richContent, null, 2)}
            onChange={e => {
              try {
                const parsed = JSON.parse(e.target.value)
                onUpdateField('rich_content' as never, '' as never, '' as never)
                // Directly set rich_content as parsed object
                snapshot.rich_content = parsed
              } catch {
                // Allow typing invalid JSON temporarily
                snapshot.rich_content = e.target.value
              }
            }}
          />
        </div>
      </div>
    </>
  )
}

/* ====== Grammar Snapshot Editor ====== */
function GrammarSnapshotEditor({ snapshot, onUpdateField, onUpdateArrayField }: {
  snapshot: Record<string, unknown>
  onUpdateField: (section: string, key: string, value: string) => void
  onUpdateArrayField: (section: string, index: number, key: string, value: string) => void
}) {
  const grammar = (snapshot.grammar ?? {}) as Record<string, unknown>
  const meanings = (snapshot.meanings ?? []) as Array<Record<string, unknown>>
  const examples = (snapshot.examples ?? []) as Array<Record<string, unknown>>

  return (
    <>
      <div className="detail-section">
        <h2>语法基本信息</h2>
        <div className="snapshot-field">
          <label>标题</label>
          <input
            value={String(grammar.title ?? '')}
            onChange={e => onUpdateField('grammar', 'title', e.target.value)}
          />
        </div>
      </div>

      {meanings.length > 0 && (
        <div className="detail-section">
          <h2>释义</h2>
          {meanings.map((m, i) => (
            <div key={i} style={{ borderBottom: '1px solid #f3f4f6', paddingBottom: 12, marginBottom: 12 }}>
              <div className="snapshot-field">
                <label>中文释义 #{i + 1}</label>
                <input
                  value={String(m.definition_cn ?? '')}
                  onChange={e => onUpdateArrayField('meanings', i, 'definition_cn', e.target.value)}
                />
              </div>
              <div className="snapshot-field">
                <label>英文释义 #{i + 1}</label>
                <input
                  value={String(m.definition_en ?? '')}
                  onChange={e => onUpdateArrayField('meanings', i, 'definition_en', e.target.value)}
                />
              </div>
              <div className="snapshot-field">
                <label>用法说明（中文）</label>
                <textarea
                  value={String(m.how_to_use_cn ?? '')}
                  onChange={e => onUpdateArrayField('meanings', i, 'how_to_use_cn', e.target.value)}
                />
              </div>
            </div>
          ))}
        </div>
      )}

      {examples.length > 0 && (
        <div className="detail-section">
          <h2>例句</h2>
          {examples.map((ex, i) => (
            <div key={i} style={{ borderBottom: '1px solid #f3f4f6', paddingBottom: 12, marginBottom: 12 }}>
              <div className="snapshot-field">
                <label>日文例句 #{i + 1}</label>
                <input
                  value={String(ex.sentence ?? '')}
                  onChange={e => onUpdateArrayField('examples', i, 'sentence', e.target.value)}
                />
              </div>
              <div className="snapshot-field">
                <label>中文翻译 #{i + 1}</label>
                <input
                  value={String(ex.translation_cn ?? '')}
                  onChange={e => onUpdateArrayField('examples', i, 'translation_cn', e.target.value)}
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}
