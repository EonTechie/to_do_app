import React, { useEffect, useState } from 'react';

const API_URL = 'http://34.59.215.211:4000/todos';

const PRIORITIES = ['Low', 'Medium', 'High'];

function App() {
  const [todos, setTodos] = useState([]);
  const [title, setTitle] = useState('');
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [editingId, setEditingId] = useState(null);
  const [editTitle, setEditTitle] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [priority, setPriority] = useState('Medium');
  const [completedCount, setCompletedCount] = useState(0);
  const [completedTodos, setCompletedTodos] = useState([]);

  useEffect(() => {
    fetch(API_URL)
      .then(res => res.json())
      .then(setTodos);
    // Fetch completed count and completed todos from Cloud Functions on mount
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos')
      .then(res => res.json())
      .then(data => setCompletedCount(data.completedCount || 0));
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos')
      .then(res => res.json())
      .then(data => setCompletedTodos(data.completed || []));
  }, []);

  const addTodo = async () => {
    if (!title.trim()) return;
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title,
        completed: false,
        dueDate,
        priority
      })
    });
    const newTodo = await res.json();
    setTodos([...todos, newTodo]);
    setTitle('');
    setDueDate('');
    setPriority('Medium');
    // Fetch updated completed count and completed todos
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos')
      .then(res => res.json())
      .then(data => setCompletedCount(data.completedCount || 0));
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos')
      .then(res => res.json())
      .then(data => setCompletedTodos(data.completed || []));
  };

  const toggleTodo = async (id, completed) => {
    await fetch(`${API_URL}/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ completed: !completed })
    });
    // Fetch updated todos
    fetch(API_URL)
      .then(res => res.json())
      .then(setTodos);
    // Fetch updated completed count and completed todos
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos')
      .then(res => res.json())
      .then(data => setCompletedCount(data.completedCount || 0));
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos')
      .then(res => res.json())
      .then(data => setCompletedTodos(data.completed || []));
  };

  const deleteTodo = async (id) => {
    await fetch(`${API_URL}/${id}`, { method: 'DELETE' });
    setTodos(todos.filter(todo => todo._id !== id));
    // Fetch updated completed count and completed todos
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos')
      .then(res => res.json())
      .then(data => setCompletedCount(data.completedCount || 0));
    fetch('https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos')
      .then(res => res.json())
      .then(data => setCompletedTodos(data.completed || []));
  };

  const startEdit = (todo) => {
    setEditingId(todo._id);
    setEditTitle(todo.title);
  };

  const saveEdit = async (id) => {
    await fetch(`${API_URL}/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: editTitle })
    });
    setTodos(todos.map(todo => todo._id === id ? { ...todo, title: editTitle } : todo));
    setEditingId(null);
    setEditTitle('');
  };

  const filteredTodos = todos
    .filter(todo =>
      (filter === 'all' ||
        (filter === 'completed' && todo.completed) ||
        (filter === 'active' && !todo.completed))
      && todo.title.toLowerCase().includes(search.toLowerCase())
    );

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #f8fafc 0%, #e0e7ff 100%)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      fontFamily: 'Segoe UI, sans-serif'
    }}>
      <h1 style={{ marginTop: 40, color: '#3730a3', fontWeight: 700, fontSize: 40 }}>📝 To-Do App</h1>
      <div style={{
        background: '#fff',
        padding: 32,
        borderRadius: 16,
        boxShadow: '0 4px 24px rgba(55,48,163,0.08)',
        marginTop: 24,
        minWidth: 350,
        maxWidth: 500
      }}>
        <div style={{ display: 'flex', marginBottom: 16, gap: 8 }}>
          <input
            value={title}
            onChange={e => setTitle(e.target.value)}
            placeholder="Add a new task..."
            style={{
              flex: 2,
              padding: 12,
              border: '1px solid #a5b4fc',
              borderRadius: 8,
              fontSize: 16,
              outline: 'none'
            }}
            onKeyDown={e => e.key === 'Enter' && addTodo()}
          />
          <input
            type="date"
            value={dueDate}
            onChange={e => setDueDate(e.target.value)}
            style={{
              flex: 1,
              padding: 12,
              border: '1px solid #a5b4fc',
              borderRadius: 8,
              fontSize: 14
            }}
          />
          <select
            value={priority}
            onChange={e => setPriority(e.target.value)}
            style={{
              flex: 1,
              padding: 12,
              border: '1px solid #a5b4fc',
              borderRadius: 8,
              fontSize: 14
            }}
          >
            {PRIORITIES.map(p => <option key={p}>{p}</option>)}
          </select>
          <button
            onClick={addTodo}
            style={{
              marginLeft: 8,
              padding: '12px 20px',
              background: '#6366f1',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              fontWeight: 600,
              fontSize: 16,
              cursor: 'pointer',
              transition: 'background 0.2s'
            }}
          >
            Add
          </button>
        </div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          <button onClick={() => setFilter('all')}
            style={{
              flex: 1,
              background: filter === 'all' ? '#6366f1' : '#e0e7ff',
              color: filter === 'all' ? '#fff' : '#6366f1',
              border: 'none',
              borderRadius: 8,
              padding: 8,
              fontWeight: 600,
              cursor: 'pointer'
            }}>All</button>
          <button onClick={() => setFilter('active')}
            style={{
              flex: 1,
              background: filter === 'active' ? '#6366f1' : '#e0e7ff',
              color: filter === 'active' ? '#fff' : '#6366f1',
              border: 'none',
              borderRadius: 8,
              padding: 8,
              fontWeight: 600,
              cursor: 'pointer'
            }}>Active</button>
          <button onClick={() => setFilter('completed')}
            style={{
              flex: 1,
              background: filter === 'completed' ? '#6366f1' : '#e0e7ff',
              color: filter === 'completed' ? '#fff' : '#6366f1',
              border: 'none',
              borderRadius: 8,
              padding: 8,
              fontWeight: 600,
              cursor: 'pointer'
            }}>Completed</button>
        </div>
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search tasks..."
          style={{
            width: '100%',
            padding: 10,
            border: '1px solid #a5b4fc',
            borderRadius: 8,
            fontSize: 15,
            marginBottom: 16
          }}
        />
        <div style={{ marginBottom: 12, color: '#6366f1', fontWeight: 600 }}>
          Total Tasks: {filteredTodos.length}
        </div>
        <div style={{ color: '#22c55e', fontWeight: 600, marginBottom: 8 }}>
          Completed Task Count: {completedCount}
        </div>
        <div style={{ color: '#6366f1', fontWeight: 600, marginBottom: 8 }}>
          Completed Tasks:
          <ul>
            {completedTodos.map(todo => (
              <li key={todo._id}>{todo.title}</li>
            ))}
          </ul>
        </div>
        <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
          {filteredTodos.map(todo => (
            <li key={todo._id} style={{
              display: 'flex',
              alignItems: 'center',
              padding: '10px 0',
              borderBottom: '1px solid #f1f5f9'
            }}>
              <input
                type="checkbox"
                checked={todo.completed}
                onChange={() => toggleTodo(todo._id, todo.completed)}
                style={{ marginRight: 10, width: 18, height: 18 }}
              />
              {editingId === todo._id ? (
                <>
                  <input
                    value={editTitle}
                    onChange={e => setEditTitle(e.target.value)}
                    style={{
                      flex: 1,
                      fontSize: 16,
                      border: '1px solid #a5b4fc',
                      borderRadius: 6,
                      padding: 6
                    }}
                  />
                  <button onClick={() => saveEdit(todo._id)}
                    style={{
                      marginLeft: 8,
                      background: '#22c55e',
                      color: '#fff',
                      border: 'none',
                      borderRadius: 6,
                      padding: '6px 12px',
                      fontWeight: 600,
                      cursor: 'pointer'
                    }}>Save</button>
                  <button onClick={() => setEditingId(null)}
                    style={{
                      marginLeft: 4,
                      background: '#f87171',
                      color: '#fff',
                      border: 'none',
                      borderRadius: 6,
                      padding: '6px 12px',
                      fontWeight: 600,
                      cursor: 'pointer'
                    }}>Cancel</button>
                </>
              ) : (
                <>
                  <span
                    style={{
                      flex: 1,
                      fontSize: 18,
                      color: todo.completed ? '#a5b4fc' : '#3730a3',
                      textDecoration: todo.completed ? 'line-through' : 'none',
                      cursor: 'pointer',
                      transition: 'color 0.2s'
                    }}
                  >
                    {todo.title}
                    {todo.dueDate && (
                      <span style={{
                        marginLeft: 10,
                        fontSize: 13,
                        color: '#64748b'
                      }}>
                        📅 {todo.dueDate}
                      </span>
                    )}
                    {todo.priority && (
                      <span style={{
                        marginLeft: 10,
                        fontSize: 13,
                        color: todo.priority === 'High' ? '#ef4444' : todo.priority === 'Medium' ? '#f59e42' : '#22c55e',
                        fontWeight: 600
                      }}>
                        {todo.priority}
                      </span>
                    )}
                  </span>
                  <button
                    onClick={() => startEdit(todo)}
                    style={{
                      marginLeft: 8,
                      background: '#fbbf24',
                      color: '#fff',
                      border: 'none',
                      borderRadius: 6,
                      padding: '6px 12px',
                      fontWeight: 600,
                      cursor: 'pointer'
                    }}>Edit</button>
                  <button
                    onClick={() => deleteTodo(todo._id)}
                    style={{
                      marginLeft: 8,
                      background: '#f87171',
                      color: '#fff',
                      border: 'none',
                      borderRadius: 6,
                      padding: '6px 12px',
                      fontWeight: 600,
                      cursor: 'pointer'
                    }}>Delete</button>
                </>
              )}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default App;