const { MongoClient } = require('mongodb');

exports.completedTodos = async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  const client = new MongoClient("mongodb://34.60.227.68:27017/tododb");
  try {
    await client.connect();
    const db = client.db('tododb');
    // Sadece tamamlanan görevleri getir
    const completed = await db.collection('todos').find({ completed: true }).toArray();
    res.status(200).json({ completed });
  } catch (err) {
    console.error('Function error:', err); // Hata loglansın
    res.status(500).json({ error: err.message });
  } finally {
    await client.close();
  }
};