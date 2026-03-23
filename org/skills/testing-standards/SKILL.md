# Testing Standards Review

Checks test code against organizational standards for pytest, moto mocking, fixtures, and coverage.

## Steps

1. **Identify changed test files**
   Determine the scope of test changes:
   ```bash
   git diff --name-only main...HEAD -- 'tests/**/*.py' 'test_*.py'
   ```
   Also check if production code was changed without corresponding test changes:
   ```bash
   git diff --name-only main...HEAD -- 'src/**/*.py'
   ```

2. **Test framework and structure**
   - Use `pytest` as the test runner.
   - Use `@pytest.fixture` for all setup. Avoid `setUp`/`tearDown` class methods.
   - Tests must be independent and not rely on execution order.
   - Use descriptive test names that explain the scenario: `test_returns_404_when_item_not_found`.

3. **AWS mocking with moto**
   - Use `mock_aws` context manager (not the older `mock_dynamodb` etc.) for all AWS service mocking.
   - Create DynamoDB tables in fixtures matching the CloudFormation template exactly -- all GSIs, key schemas, and attribute definitions.
   - Reset module-level caches between tests to prevent cross-test contamination.
   - Accept optional boto3 clients via constructor parameters for dependency injection.

4. **Fixture patterns**
   - Provide a `make_api_event()` helper in `conftest.py` for building API Gateway event dicts.
   - DynamoDB table fixtures should use `mock_aws` and create tables matching the SAM template.

   Example fixture:
   ```python
   @pytest.fixture
   def dynamodb_table():
       with mock_aws():
           dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
           table = dynamodb.create_table(
               TableName="test-table",
               KeySchema=[{"AttributeName": "pk", "KeyType": "HASH"}],
               AttributeDefinitions=[{"AttributeName": "pk", "AttributeType": "S"}],
               BillingMode="PAY_PER_REQUEST",
           )
           yield table
   ```

5. **Exception mocking**
   - Mock exception types must match the `except` clause exactly.
   - If code catches `requests.RequestException`, the test must raise `requests.ConnectionError` (a subclass), not bare `Exception`.

6. **Property-based testing**
   - Use Hypothesis for property-based testing of data model serialization round-trips (`to_dynamodb_item` -> `from_dynamodb_item`), validation logic, and idempotency invariants.

7. **Coverage expectations**
   - Every PR must include unit tests for new logic.
   - Lambda handlers must have tests for success, validation error, and unexpected error paths.

## Output

Provide a summary organized by category:
- **Framework usage**: Incorrect pytest patterns or missing fixtures.
- **AWS mocking**: Incorrect moto usage or missing table definitions.
- **Test isolation**: Cross-test contamination risks or order dependencies.
- **Coverage gaps**: Production code changes without corresponding tests.
- **Exception mocking**: Incorrect exception types in mocks.

For each finding, include the file path, line number, the issue, and the recommended fix.
