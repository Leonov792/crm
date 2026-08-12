import React, { useState, useEffect } from 'react'

const API = '/api'

export default function Contacts() {
  const [contacts, setContacts] = useState([])
  const [show, setShow] = useState(false)
  const [form, setForm] = useState({ name: '', phone: '', email: '', company: '' })

  useEffect(() => { load() }, [])

  async function load() {
    try { const r = await fetch(API + '/contacts').then(r => r.json()); if (Array.isArray(r)) setContacts(r) } catch(e) {}
  }

  async function save() {
    if (!form.name) return
    await fetch(API + '/contacts', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(form) })
    setForm({ name: '', phone: '', email: '', company: '' }); setShow(false); load()
  }

  async function del(id) { await fetch(API + '/contacts/' + id, { method: 'DELETE' }); load() }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold">Contacts</h2>
        <button onClick={() => setShow(!show)} className="px-4 py-2 bg-yellow-500 text-black text-sm font-semibold rounded-lg">+ Add</button>
      </div>

      {show && (
        <div className="mb-6 bg-gray-900 rounded-xl p-4 grid grid-cols-2 gap-3">
          <input placeholder="Name *" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-sm" />
          <input placeholder="Phone" value={form.phone} onChange={e => setForm({...form, phone: e.target.value})} className="bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-sm" />
          <input placeholder="Email" value={form.email} onChange={e => setForm({...form, email: e.target.value})} className="bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-sm" />
          <input placeholder="Company" value={form.company} onChange={e => setForm({...form, company: e.target.value})} className="bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-sm" />
          <button onClick={save} className="col-span-2 py-2 bg-yellow-500 text-black text-sm font-semibold rounded-lg">Save Contact</button>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {contacts.map(c => (
          <div key={c.id} className="bg-gray-900 border border-gray-800 rounded-xl p-4 flex justify-between items-start group">
            <div>
              <div className="font-semibold">{c.name}</div>
              {c.phone && <div className="text-sm text-gray-400 mt-1">{c.phone}</div>}
              {c.email && <div className="text-sm text-blue-400 mt-1">{c.email}</div>}
              {c.company && <div className="text-xs text-gray-500 mt-2">{c.company}</div>}
            </div>
            <button onClick={() => del(c.id)} className="opacity-0 group-hover:opacity-100 text-gray-500 hover:text-red-400 transition text-xs">Del</button>
          </div>
        ))}
      </div>
    </div>
  )
}
