from locust import HttpUser, task, between, events
import random
import os

# Kullanıcı ve spawn rate parametrelerini environment variable'dan al, yoksa default kullan
USER_COUNT = int(os.getenv("LOCUST_USERS", 100))
SPAWN_RATE = int(os.getenv("LOCUST_SPAWN_RATE", 10))

class TodoUser(HttpUser):
    wait_time = between(0.2, 0.5)  # Daha kısa bekleme, daha gerçekçi yük
    todo_ids = []

    @task(2)
    def list_todos(self):
        response = self.client.get("/todos", catch_response=True)
        if response and response.status_code == 200:
            with response:
                try:
                    todos = response.json()
                    self.todo_ids = [todo["_id"] for todo in todos if "_id" in todo]
                except:
                    pass

    @task(2)
    def add_todo(self):
        title = f"Test Task {random.randint(1, 100000)}"
        data = {
            "title": title,
            "completed": False,
            "dueDate": "2025-12-31",
            "priority": random.choice(["Low", "Medium", "High"])
        }
        response = self.client.post("/todos", json=data, catch_response=True)
        if response and response.status_code == 201:
            with response:
                try:
                    todo = response.json()
                    if "_id" in todo:
                        self.todo_ids.append(todo["_id"])
                except:
                    pass

    @task(1)
    def complete_todo(self):
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            response = self.client.put(f"/todos/{todo_id}", json={"completed": True}, catch_response=True)
            if response and response.status_code == 200:
                with response:
                    pass

    @task(1)
    def delete_todo(self):
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            response = self.client.delete(f"/todos/{todo_id}", catch_response=True)
            if response and response.status_code == 204:
                with response:
                    try:
                        self.todo_ids.remove(todo_id)
                    except:
                        pass

    @task(1)
    def count_completed_todos(self):
        self.client.get("https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos", catch_response=True)

    @task(1)
    def completed_todos(self):
        self.client.get("https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos", catch_response=True)

