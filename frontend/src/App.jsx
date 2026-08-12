import React, { useState } from 'react'
import Kanban from './pages/Kanban'
import Contacts from './pages/Contacts'
import Files from './pages/Files'

export default function App() {
  const [page, setPage] = useState('kanban')

  const tabs = [
    { id: 'kanban', label: 'Kanban' },
    { id: 'contacts', label: 'Contacts' },
    { id: 'files', label: 'Files' },
  ]

  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-gray-900 border-b border-gray-800 px-6 py-3 flex items-center justify-between">
        <h1 className="text-lg font-bold text-yellow-500 tracking-tight">CRM</h1>
        <div className="flex gap-1">
          {tabs.map(t => (
            <button key={t.id} onClick={() => setPage(t.id)}
              className={`px-4 py-2 text-sm rounded-lg transition ${page === t.id ? 'bg-yellow-500/20 text-yellow-500' : 'text-gray-400 hover:text-gray-200'}`}>
              {t.label}
            </button>
          ))}
        </div>
      </header>

      <main className="flex-1 p-6">
        {page === 'kanban' && <Kanban />}
        {page === 'contacts' && <Contacts />}
        {page === 'files' && <Files />}
      </main>
    </div>
  )
}
