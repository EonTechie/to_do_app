const { MongoClient } = require('mongodb');

exports.countCompletedTodos = async (req, res) => {
  const client = new MongoClient(process.env.MONGO_URI);
  await client.connect();
  const db = client.db('tododb');
  const count = await db.collection('todos').countDocuments({ completed: true });
  await client.close();
  res.status(200).send({ completedCount: count });
};
