from locust import HttpUser, task, between
import random
import time

class TodoUser(HttpUser):
    wait_time = between(1, 2)
    todo_ids = []

    @task(2)
    def list_todos(self):
        with self.client.get("/todos", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    todos = response.json()
                    # Güncel todo id'lerini sakla
                    self.todo_ids = [todo["_id"] for todo in todos if "_id" in todo]
                except Exception:
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
        with self.client.post("/todos", json=data, catch_response=True) as response:
            if response.status_code == 201:
                try:
                    todo = response.json()
                    if "_id" in todo:
                        self.todo_ids.append(todo["_id"])
                except Exception:
                    pass

    @task(1)
    def complete_todo(self):
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            with self.client.put(f"/todos/{todo_id}", json={"completed": True}, catch_response=True) as response:
                if response.status_code == 200:
                    pass  # Başarılı güncelleme

    @task(1)
    def delete_todo(self):
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            with self.client.delete(f"/todos/{todo_id}", catch_response=True) as response:
                if response.status_code == 204:
                    try:
                        self.todo_ids.remove(todo_id)
                    except ValueError:
                        pass

    @task(1)
    def count_completed_todos(self):
        self.client.get("https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos")

    @task(1)
    def completed_todos(self):
        self.client.get("https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos")


class GradualLoadUser(HttpUser):
    wait_time = between(1, 2)
    todo_ids = []

    def on_start(self):
        # Başlangıçta düşük kullanıcı sayısı
        self.user_count = 10
        self.spawn_rate = 1
        self.test_duration = 60  # 1 dakika

    @task
    def gradual_load(self):
        # Kademeli artış
        for i in range(5):  # 5 kademe
            self.user_count *= 2  # Her kademede kullanıcı sayısını 2 katına çıkar
            self.spawn_rate *= 2  # Her kademede spawn rate'i 2 katına çıkar
            print(f"Kademe {i+1}: Kullanıcı Sayısı: {self.user_count}, Spawn Rate: {self.spawn_rate}")
            time.sleep(self.test_duration)  # Her kademe için 1 dakika bekle

    @task(2)
    def list_todos(self):
        with self.client.get("/todos", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    todos = response.json()
                    self.todo_ids = [todo["_id"] for todo in todos if "_id" in todo]
                except Exception:
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
        with self.client.post("/todos", json=data, catch_response=True) as response:
            if response.status_code == 201:
                try:
                    todo = response.json()
                    if "_id" in todo:
                        self.todo_ids.append(todo["_id"])
                except Exception:
                    pass

    @task(1)
    def complete_todo(self):
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            with self.client.put(f"/todos/{todo_id}", json={"completed": True}, catch_response=True) as response:
                if response.status_code == 200:
                    pass  # Başarılı güncelleme

    @task(1)
    def delete_todo(self):
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            with self.client.delete(f"/todos/{todo_id}", catch_response=True) as response:
                if response.status_code == 204:
                    try:
                        self.todo_ids.remove(todo_id)
                    except ValueError:
                        pass

    @task(1)
    def count_completed_todos(self):
        self.client.get("https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos")

    @task(1)
    def completed_todos(self):
        self.client.get("https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos")