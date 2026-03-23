<!-- claude-hub:fragment:begin — This section is managed centrally. Do not edit manually. Run /hub-fragment-update to update. -->
# Python Lambda / SAM — Toolchain Reference

## Commands

### Build and Deploy
```bash
sam build                          # Build all functions and layers
sam build --use-container          # Build in Docker (ensures correct Python version)
sam validate --lint                # Validate template.yaml
sam deploy                         # Deploy using samconfig.toml defaults
sam deploy --guided                # Interactive deploy (first time)
sam delete                         # Tear down the stack
```

### Local Development
```bash
sam local invoke FunctionName -e events/event.json   # Invoke a single function
sam local start-api                                   # Start local API Gateway
sam local generate-event apigateway http-api-proxy    # Generate test events
```

### Testing
```bash
pytest                             # Run all tests
pytest tests/unit/                 # Unit tests only
pytest tests/integration/          # Integration tests (requires deployed stack)
pytest -x -v                       # Stop on first failure, verbose
pytest --tb=short -q               # Compact output
```

## Project Structure

```
.
├── template.yaml              # SAM/CloudFormation template
├── samconfig.toml             # Deploy configuration
├── src/
│   ├── handlers/              # Lambda handler modules (one per function)
│   │   └── my_function/
│   │       ├── __init__.py
│   │       └── app.py
│   ├── models/                # @dataclass models with DynamoDB serialization
│   ├── services/              # Business logic (decoupled from event shape)
│   └── utils/                 # Shared helpers (logging, AWS client factories)
├── layers/                    # Lambda layers (source root, no python/ nesting)
├── tests/
│   ├── unit/                  # Fast tests with moto mocks
│   ├── integration/           # Tests against deployed stack
│   └── conftest.py            # Shared fixtures and event builders
├── events/                    # Sample event payloads for local invoke
└── scripts/                   # Seed data, deployment utilities
```

## Lambda Handler Pattern

Handlers must be thin: parse event, call service, return response.

```python
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

def lambda_handler(event, context):
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

## DynamoDB Patterns

- Use `ExpressionAttributeNames` with `#placeholder` for reserved words (`status`, `name`, `type`, `data`, `key`, `value`, `count`, `size`, `url`).
- Conditional writes for idempotency: `ConditionExpression="attribute_not_exists(pk)"`.
- Always paginate: loop until `LastEvaluatedKey` is absent.
- TTL values must be Unix epoch timestamps (number), not ISO strings.
- Atomic counters: `UpdateExpression="ADD #count :inc"` with `:inc = 1`.

## Testing with pytest and moto

- Use `mock_aws` context manager (not legacy `mock_dynamodb`).
- Create DynamoDB tables in fixtures matching `template.yaml` exactly (all GSIs, key schemas, attribute definitions).
- Provide `make_api_event()` in `conftest.py` for API Gateway proxy events.
- Reset module-level caches between tests.
- Accept optional boto3 clients via constructor for dependency injection.
- Use Hypothesis for property-based testing of serialization round-trips.

## Environment Variables

Configure in `template.yaml`, read via `os.environ` in handlers:

| Variable | Source | Purpose |
|----------|--------|---------|
| `STACK_NAME` | `!Ref AWS::StackName` | Stack identification in logs and user-visible strings |
| `TABLE_NAME` | `!Ref MyTable` | DynamoDB table name |
| `LOG_LEVEL` | Hardcoded or SSM | Logging verbosity |

## Key Pitfalls

- `sam build` requires the exact Python version matching the runtime on PATH. Use `--use-container` if unavailable.
- SAM layer `BuildMethod` adds `python/` prefix automatically. Do NOT nest source under `python/`.
- HTTP API v2 has a hard 30-second integration timeout. Use async patterns (SQS, EventBridge) for long operations.
- Never reference `ServerlessRestApi`/`ServerlessHttpApi` in function environment variables (circular dependency).
- `!Sub` cannot be used as a CloudFormation Parameter default. Inline `!Sub` directly.
- First deploy may fail with KMS/CreateGrant race condition. Delete the failed stack and redeploy.
- Never use `SSMParameterReadPolicy` with `/`-prefixed parameter names. Use a direct IAM Statement.
<!-- claude-hub:fragment:end — Add your project-specific content below this line. -->

# Project Notes

<!-- Add project-specific guidance here: architecture decisions, conventions, deployment notes, lessons learned. -->
