# Load Test Generator

Generates Locust load test scripts for API endpoints to validate performance before production deployment.

## Steps

1. **Identify the API endpoints to test**
   Review changed handlers and the SAM template:
   ```bash
   git diff --name-only main...HEAD -- 'src/handlers/*.py' 'template.yaml'
   ```
   Read the handler code and template to understand the endpoint paths, methods, and expected payloads.

2. **Design load test scenarios**
   For each endpoint, define:
   - **Baseline load**: Normal expected traffic pattern.
   - **Peak load**: 3-5x baseline to simulate traffic spikes.
   - **Key user flows**: Weighted task sequences that mimic real usage (e.g., 70% reads, 20% creates, 10% updates).

3. **Generate Locust test file**
   Create the test in `tests/load/` following this pattern:

   ```python
   from locust import HttpUser, task, between

   class ApiUser(HttpUser):
       wait_time = between(1, 3)
       host = "https://api-id.execute-api.region.amazonaws.com"

       def on_start(self):
           """Set up authentication headers."""
           self.headers = {"x-api-key": "test-api-key"}

       @task(7)
       def list_items(self):
           self.client.get("/v1/items", headers=self.headers)

       @task(2)
       def create_item(self):
           self.client.post(
               "/v1/items",
               json={"name": "test-item", "category": "load-test"},
               headers=self.headers,
           )

       @task(1)
       def get_item(self):
           self.client.get("/v1/items/test-id", headers=self.headers)
   ```

4. **Configure test parameters**
   - Start with 10 users, ramp up by 5 users/second.
   - Run for 5 minutes minimum for baseline, 15 minutes for endurance.
   - Set failure thresholds: p99 latency < 3s, error rate < 1%.

5. **DynamoDB considerations**
   - Ensure test data exists before running (seed script or on_start setup).
   - Use on-demand billing mode for the test table to avoid throttling during load tests.
   - Monitor DynamoDB consumed capacity in CloudWatch during the test.

6. **Running instructions**
   Provide the exact commands:
   ```bash
   # Install locust
   pip install locust

   # Run headless
   locust -f tests/load/test_api.py --headless -u 50 -r 5 -t 5m

   # Run with web UI
   locust -f tests/load/test_api.py
   ```

## Output

Generate the complete Locust test file and provide:
- What endpoints and user flows are covered.
- Recommended user counts and duration for baseline and peak scenarios.
- What metrics to monitor in CloudWatch during the test (Lambda duration, DynamoDB consumed capacity, API Gateway 4xx/5xx rates).
- How to run: `locust -f tests/load/<test-file>.py --headless -u <users> -r <rate> -t <duration>`.
