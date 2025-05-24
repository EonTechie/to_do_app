from locust import HttpUser, task, between
import random
import time
from datetime import datetime, timedelta

class TodoUser(HttpUser):
    wait_time = between(1, 3)  # Daha gerçekçi bekleme süreleri
    todo_ids = []
    priorities = ["Low", "Medium", "High"]
    
    def on_start(self):
        """Test başlangıcında çalışır"""
        self.user_count = 0
        self.todo_ids = []
        # İlk başta mevcut todoları al
        self.list_todos()

    def generate_due_date(self):
        """Rastgele bir bitiş tarihi oluşturur"""
        days = random.randint(1, 30)
        due_date = datetime.now() + timedelta(days=days)
        return due_date.strftime("%Y-%m-%d")

    @task(3)
    def list_todos(self):
        """Todoları listele - en sık yapılan işlem"""
        with self.client.get("/todos", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    todos = response.json()
                    self.todo_ids = [todo["_id"] for todo in todos if "_id" in todo]
                except Exception as e:
                    response.failure(f"JSON parse error: {str(e)}")
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(2)
    def add_todo(self):
        """Yeni todo ekle"""
        title = f"Test Task {random.randint(1, 100000)}"
        data = {
            "title": title,
            "completed": False,
            "dueDate": self.generate_due_date(),
            "priority": random.choice(self.priorities)
        }
        with self.client.post("/todos", json=data, catch_response=True) as response:
            if response.status_code == 201:
                try:
                    todo = response.json()
                    if "_id" in todo:
                        self.todo_ids.append(todo["_id"])
                except Exception as e:
                    response.failure(f"JSON parse error: {str(e)}")
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def complete_todo(self):
        """Todo'yu tamamla"""
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            with self.client.put(f"/todos/{todo_id}", 
                               json={"completed": True}, 
                               catch_response=True) as response:
                if response.status_code != 200:
                    response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def delete_todo(self):
        """Todo sil"""
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            with self.client.delete(f"/todos/{todo_id}", catch_response=True) as response:
                if response.status_code == 204:
                    try:
                        self.todo_ids.remove(todo_id)
                    except ValueError:
                        pass
                else:
                    response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def count_completed_todos(self):
        """Tamamlanan todoları say"""
        with self.client.get(
            "https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos",
            catch_response=True
        ) as response:
            if response.status_code != 200:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def get_completed_todos(self):
        """Tamamlanan todoları listele"""
        with self.client.get(
            "https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos",
            catch_response=True
        ) as response:
            if response.status_code != 200:
                response.failure(f"Failed with status code: {response.status_code}")


class GradualLoadUser(HttpUser):
    wait_time = between(1, 2)
    todo_ids = []
    
    def on_start(self):
        """Kademeli yük testi başlangıcı"""
        self.user_count = 10
        self.spawn_rate = 1
        self.test_duration = 300  # 5 dakika
        self.step_count = 5
        self.current_step = 0

    @task
    def gradual_load(self):
        """Kademeli yük artışı"""
        if self.current_step < self.step_count:
            self.user_count *= 2
            self.spawn_rate *= 2
            print(f"Step {self.current_step + 1}: Users: {self.user_count}, Spawn Rate: {self.spawn_rate}")
            self.current_step += 1
            time.sleep(self.test_duration)

    # TodoUser'dan gelen tüm task'ları miras al
    @task(3)
    def list_todos(self):
        with self.client.get("/todos", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    todos = response.json()
                    self.todo_ids = [todo["_id"] for todo in todos if "_id" in todo]
                except Exception as e:
                    response.failure(f"JSON parse error: {str(e)}")
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(2)
    def add_todo(self):
        title = f"Test Task {random.randint(1, 100000)}"
        data = {
            "title": title,
            "completed": False,
            "dueDate": (datetime.now() + timedelta(days=random.randint(1, 30))).strftime("%Y-%m-%d"),
            "priority": random.choice(["Low", "Medium", "High"])
        }
        with self.client.post("/todos", json=data, catch_response=True) as response:
            if response.status_code == 201:
                try:
                    todo = response.json()
                    if "_id" in todo:
                        self.todo_ids.append(todo["_id"])
                except Exception as e:
                    response.failure(f"JSON parse error: {str(e)}")
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def complete_todo(self):
        if self.todo_ids:
            todo_id = random.choice(self.todo_ids)
            with self.client.put(f"/todos/{todo_id}", 
                               json={"completed": True}, 
                               catch_response=True) as response:
                if response.status_code != 200:
                    response.failure(f"Failed with status code: {response.status_code}")

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
                else:
                    response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def count_completed_todos(self):
        with self.client.get(
            "https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/countCompletedTodos",
            catch_response=True
        ) as response:
            if response.status_code != 200:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def get_completed_todos(self):
        with self.client.get(
            "https://us-central1-extreme-wind-457613-b2.cloudfunctions.net/completedTodos",
            catch_response=True
        ) as response:
            if response.status_code != 200:
                response.failure(f"Failed with status code: {response.status_code}")