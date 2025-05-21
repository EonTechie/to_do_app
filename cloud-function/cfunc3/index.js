require('dotenv').config(); 
const { MongoClient } = require('mongodb');
const nodemailer = require('nodemailer');

exports.notifyDueTasks = async (req, res) => {
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
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0);

    // Yarın bitiş tarihi olan ve tamamlanmamış görevleri bul
    const dueTasks = await db.collection('todos').find({
      completed: false,
      dueDate: { $eq: tomorrow.toISOString().slice(0, 10) }
    }).toArray();

    if (dueTasks.length === 0) {
      res.status(200).send('No due tasks for tomorrow.');
      return;
    }

    // E-posta gönderimi için transporter ayarları (SMTP)
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,      // .env ve GCP env 
        pass: process.env.EMAIL_PASS
      }
    });

    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: process.env.NOTIFY_EMAIL.split(',').map(email => email.trim()),        
      subject: 'Yarın bitmesi gereken görevler!',
      text: `Yarın bitmesi gereken görevler:\n\n${dueTasks.map(t => t.title).join('\n')}`
    };

    await transporter.sendMail(mailOptions);

    console.log('Notification function executed successfully');
    res.status(200).send('Notifications sent');
  } catch (err) {
    console.error('notifyDueTasks error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    await client.close();
  }
};
