# API Design Review

Reviews API endpoint design against backend team standards for RESTful conventions, error handling, pagination, and SAM template configuration.

## Steps

1. **Identify changed API endpoints**
   ```bash
   git diff --name-only main...HEAD -- 'src/handlers/*.py' 'template.yaml'
   ```
   Read the SAM template to find new or modified API Gateway event sources.

2. **RESTful design**
   - Resource names are plural nouns (`/users`, `/orders`), not verbs (`/getUser`).
   - HTTP methods used correctly: GET (read), POST (create), PUT (full update), PATCH (partial update), DELETE.
   - URL structure is hierarchical for nested resources: `/users/{userId}/orders`.
   - No query parameters for resource identification -- use path parameters.
   - Collection endpoints support filtering via query parameters.

3. **Request/response patterns**
   - POST and PUT requests accept JSON body. Validate with a schema or dataclass.
   - Successful responses return appropriate status codes: 200 (OK), 201 (Created), 204 (No Content for DELETE).
   - Error responses follow the team schema:
     ```json
     {"error": {"code": "NOT_FOUND", "message": "Order not found"}}
     ```
   - Error codes are UPPER_SNAKE_CASE constants, not HTTP status code numbers.

4. **Pagination**
   - Collection endpoints must support pagination.
   - Use cursor-based pagination with `next_token` query parameter. Never offset-based with DynamoDB.
   - Response includes `items` array and optional `next_token`:
     ```json
     {"items": [...], "next_token": "eyJ..."}
     ```
   - Default page size is 20, maximum is 100. Accept `limit` query parameter.

5. **Authentication and rate limiting**
   - API key or IAM auth configured in SAM template for every endpoint.
   - No unauthenticated public endpoints without explicit justification.
   - Usage plans and throttling configured at API Gateway level.

6. **SAM template configuration**
   - Each endpoint has a corresponding `Events` entry with correct `Method` and `Path`.
   - HTTP API v2 (`HttpApi`) used consistently -- no mixing with REST API v1.
   - Lambda timeout set appropriately (default 30s for sync APIs).
   - Lambda memory sized for the workload (minimum 256MB for API handlers).

7. **Documentation**
   - New endpoints documented with request/response examples in the PR description.
   - Access patterns documented in `docs/access-patterns.md` if new DynamoDB queries are introduced.

## Output

Provide a summary organized by category:
- **REST conventions**: Naming, method usage, or URL structure violations.
- **Request/response**: Schema, status code, or error format issues.
- **Pagination**: Missing or incorrect pagination implementation.
- **Auth/security**: Missing authentication or rate limiting.
- **Infrastructure**: SAM template configuration issues.

For each finding, include the file path, line number, the issue, and the recommended fix.
