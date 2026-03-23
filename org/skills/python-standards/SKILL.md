# Python Standards Review

Checks Python code against organizational standards for Lambda handlers, logging, error handling, and general patterns.

## Steps

1. **Identify changed files**
   Determine the scope of Python changes to review:
   ```bash
   git diff --name-only main...HEAD -- '*.py'
   ```

2. **General standards**
   - Target Python 3.12+ syntax. Type hints on all function signatures.
   - Use `@dataclass` for domain models. Include `to_dynamodb_item()` and `from_dynamodb_item()` class methods for serialization.
   - Prefer `httpx` over `requests` for HTTP calls. Always set `follow_redirects=True`.
   - Never use `.format()` on strings containing literal JSON braces -- use `.replace()` or f-strings with escaped braces.

3. **Lambda handler patterns**
   - Handlers must be thin: parse the event, call a service function, return a response.
   - Distinguish API Gateway events from scheduled/direct invocations by checking for `"requestContext"` in the event.
   - Return proper API Gateway response dicts with `statusCode`, `headers`, and `body` (JSON-serialized).
   - Log the event at DEBUG level and key business actions at INFO level.

   Example of a correct handler:
   ```python
   import json
   import logging

   logger = logging.getLogger()
   logger.setLevel(logging.INFO)

   def handler(event, context):
       logger.debug("Received event: %s", json.dumps(event))
       try:
           result = some_service.process(event)
           return {"statusCode": 200, "body": json.dumps(result)}
       except ValueError as e:
           logger.warning("Validation error: %s", e)
           return {"statusCode": 400, "body": json.dumps({"error": str(e)})}
       except Exception:
           logger.exception("Unhandled error")
           return {"statusCode": 500, "body": json.dumps({"error": "Internal server error"})}
   ```

4. **Logging standards**
   - Use `logging` module, never `print()`.
   - Use `logger.exception()` in except blocks -- it captures the traceback automatically.
   - Never swallow exceptions silently. If you catch and continue, log a warning at minimum.
   - Include correlation IDs (`context.aws_request_id`) in structured log output.

5. **Error handling patterns**
   - Validate input at the handler boundary. Trust internal service code.
   - Use specific exception types -- do not catch bare `Exception` except as a top-level fallback in the handler.
   - Return meaningful HTTP status codes: 400 for bad input, 404 for missing resources, 409 for conflicts, 500 for unexpected errors.

## Output

Provide a summary organized by category:
- **General**: Style, type hint, or pattern violations.
- **Handler structure**: Issues with Lambda handler patterns.
- **Logging**: Missing or incorrect logging.
- **Error handling**: Improper error handling patterns.

For each finding, include the file path, line number, the issue, and the recommended fix.
