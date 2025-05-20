const { MongoClient } = require('mongodb');

exports.countCompletedTodos = async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const client = new MongoClient(process.env.MONGO_URI);
  try {
    await client.connect();
    const db = client.db('tododb');
    const count = await db.collection('todos').countDocuments({ completed: true });
    console.log('Completed todos count:', count);
    res.status(200).send({ completedCount: count });
  } catch (err) {
    console.error('countCompletedTodos error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    await client.close();
  }
};
