const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const Todo = require('./models/todo');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// MongoDB bağlantısı
mongoose.connect(process.env.MONGO_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
}).then(() => {
  console.log('MongoDB bağlantısı başarılı');
}).catch((err) => {
  console.error('MongoDB bağlantı hatası:', err);
});

// Tüm todoları getir
app.get('/todos', async (req, res) => {
  try {
    const todos = await Todo.find();
    res.json(todos);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Yeni todo ekle
app.post('/todos', async (req, res) => {
  try {
    const todo = new Todo(req.body);
    await todo.save();
    res.status(201).json(todo);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Todo güncelle
app.put('/todos/:id', async (req, res) => {
  try {
    const todo = await Todo.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    if (!todo) {
      return res.status(404).json({ error: 'Todo bulunamadı' });
    }
    res.json(todo);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});



// Tamamlanan tüm todoları sil
// Tamamlanan tüm todoları sil
app.delete('/todos/completed', async (req, res) => {
  try {
    const result = await Todo.deleteMany({ completed: true });
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// Tüm görevleri sil
app.delete('/todos', async (req, res) => {
  try {
    await Todo.deleteMany({});
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Tekil todo sil
app.delete('/todos/:id', async (req, res) => {
  try {
    const todo = await Todo.findByIdAndDelete(req.params.id);
    if (!todo) {
      return res.status(404).json({ error: 'Todo bulunamadı' });
    }
    res.status(204).end();
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});
// Sunucuyu başlat
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Backend ${PORT} portunda çalışıyor`);
});