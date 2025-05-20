const mongoose = require('mongoose');

const todoSchema = new mongoose.Schema({
  title: String,
  completed: Boolean,
  dueDate: String,
  priority: String
});

module.exports = mongoose.model('Todo', todoSchema);