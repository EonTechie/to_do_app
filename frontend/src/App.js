import React, { useEffect, useState } from 'react';

const API_URL = 'http://34.173.70.29:4000/todos';

function App() {
  const [todos, setTodos] = useState([]);
  const [title, setTitle] = useState('');

  useEffect(() => {
    fetch(API_URL)
      .then(res => res.json())
      .then(setTodos);
  }, []);

  const addTodo = async () => {
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, completed: false })
    });
    const newTodo = await res.json();
    setTodos([...todos, newTodo]);
    setTitle('');
  };

  const toggleTodo = async (id, completed) => {
    await fetch(`${API_URL}/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ completed: !completed })
    });
    setTodos(todos.map(todo => todo._id === id ? { ...todo, completed: !completed } : todo));
  };

  const deleteTodo = async (id) => {
    await fetch(`${API_URL}/${id}`, { method: 'DELETE' });
    setTodos(todos.filter(todo => todo._id !== id));
  };

  return (
    <div>
      <h1>To-Do App</h1>
      <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Yeni görev"/>
      <button onClick={addTodo}>Ekle</button>
      <ul>
        {todos.map(todo => (
          <li key={todo._id}>
            <span
              style={{ textDecoration: todo.completed ? 'line-through' : 'none', cursor: 'pointer' }}
              onClick={() => toggleTodo(todo._id, todo.completed)}
            >
              {todo.title}
            </span>
            <button onClick={() => deleteTodo(todo._id)}>Sil</button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default App;