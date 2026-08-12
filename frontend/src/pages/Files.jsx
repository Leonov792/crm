import React, { useState, useEffect } from 'react'

const API = '/api'

export default function Files() {
  const [files, setFiles] = useState([])

  useEffect(() => { load() }, [])

  async function load() {
    try { const r = await fetch(API + '/files').then(r => r.json()); if (Array.isArray(r)) setFiles(r) } catch(e) {}
  }

  async function upload(e) {
    const file = e.target.files[0]
    if (!file) return
    const fd = new FormData()
    fd.append('file', file)
    await fetch(API + '/files', { method: 'POST', body: fd })
    load()
  }

  function formatSize(bytes) {
    if (bytes < 1024) return bytes + ' B'
    if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + ' KB'
    return (bytes/(1024*1024)).toFixed(1) + ' MB'
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold">Files</h2>
        <label className="px-4 py-2 bg-yellow-500 text-black text-sm font-semibold rounded-lg cursor-pointer hover:bg-yellow-400 transition">
          Upload
          <input type="file" onChange={upload} className="hidden" />
        </label>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {files.map(f => (
          <div key={f.id} className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <div className="text-sm font-medium truncate">{f.name}</div>
            <div className="text-xs text-gray-500 mt-1">{formatSize(f.size)} · {f.type || 'unknown'}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
