from locust import HttpUser, task, between

class TradingSystemUser(HttpUser):
    wait_time = between(1, 5)
    
    @task
    def get_market_data(self):
        self.client.get("/api/market-data")
        
    @task(3)
    def place_order(self):
        self.client.post("/api/orders", json={
            "symbol": "EURUSD",
            "quantity": 1000,
            "side": "buy"
        })
        
    @task(2)
    def get_portfolio(self):
        self.client.get("/api/portfolio")
