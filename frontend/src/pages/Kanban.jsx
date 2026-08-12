import React, { useState, useEffect } from 'react'
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd'

const API = '/api'
const COLUMNS = [
  { id: 'todo', title: 'To Do', color: 'border-gray-600' },
  { id: 'in_progress', title: 'In Progress', color: 'border-blue-500' },
  { id: 'review', title: 'Review', color: 'border-yellow-500' },
  { id: 'done', title: 'Done', color: 'border-green-500' },
]

export default function Kanban() {
  const [tasks, setTasks] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [title, setTitle] = useState('')

  useEffect(() => { loadTasks() }, [])

  async function loadTasks() {
    try {
      const r = await fetch(API + '/tasks').then(r => r.json())
      if (Array.isArray(r)) setTasks(r)
    } catch(e) {}
  }

  async function addTask() {
    if (!title.trim()) return
    await fetch(API + '/tasks', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, status: 'todo', priority: 'medium' })
    })
    setTitle(''); setShowForm(false); loadTasks()
  }

  async function onDragEnd(result) {
    if (!result.destination) return
    const taskId = result.draggableId
    const newStatus = result.destination.droppableId

    // Optimistic update
    setTasks(prev => prev.map(t => t.id === taskId ? { ...t, status: newStatus } : t))

    await fetch(API + '/tasks/' + taskId, {
      method: 'PUT', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStatus })
    })
  }

  async function deleteTask(id) {
    await fetch(API + '/tasks/' + id, { method: 'DELETE' })
    loadTasks()
  }

  const getColumnTasks = (colId) => tasks.filter(t => t.status === colId)

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold">Kanban Board</h2>
        <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-yellow-500 text-black text-sm font-semibold rounded-lg hover:bg-yellow-400 transition">
          + Add Task
        </button>
      </div>

      {showForm && (
        <div className="mb-6 flex gap-3">
          <input value={title} onChange={e => setTitle(e.target.value)} onKeyDown={e => e.key === 'Enter' && addTask()}
            placeholder="Task title..." className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-4 py-2 text-sm outline-none focus:border-yellow-500" autoFocus />
          <button onClick={addTask} className="px-4 py-2 bg-yellow-500 text-black text-sm font-semibold rounded-lg">Add</button>
        </div>
      )}

      <DragDropContext onDragEnd={onDragEnd}>
        <div className="grid grid-cols-4 gap-4">
          {COLUMNS.map(col => (
            <Droppable droppableId={col.id} key={col.id}>
              {(provided) => (
                <div ref={provided.innerRef} {...provided.droppableProps} className={`bg-gray-900 border-t-2 ${col.color} rounded-xl p-3 min-h-[200px]`}>
                  <h3 className="text-sm font-semibold text-gray-400 mb-3 uppercase tracking-wide">{col.title} ({getColumnTasks(col.id).length})</h3>
                  {getColumnTasks(col.id).map((task, index) => (
                    <Draggable draggableId={task.id} index={index} key={task.id}>
                      {(provided) => (
                        <div ref={provided.innerRef} {...provided.draggableProps} {...provided.dragHandleProps}
                          className="bg-gray-800 border border-gray-700 rounded-lg p-3 mb-2 hover:border-gray-500 transition cursor-grab group">
                          <div className="text-sm font-medium">{task.title}</div>
                          {task.description && <div className="text-xs text-gray-500 mt-1">{task.description}</div>}
                          {task.assignee && <div className="text-xs text-yellow-500/70 mt-2">{task.assignee}</div>}
                          <button onClick={() => deleteTask(task.id)} className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 text-gray-500 hover:text-red-400 transition text-xs">x</button>
                        </div>
                      )}
                    </Draggable>
                  ))}
                  {provided.placeholder}
                </div>
              )}
            </Droppable>
          ))}
        </div>
      </DragDropContext>
    </div>
  )
}
