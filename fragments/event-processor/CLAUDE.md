<!-- claude-hub:fragment:begin — This section is managed centrally. Do not edit manually. Run /hub-fragment-update to update. -->
# Event Processor — Toolchain Reference

## Commands

### Build and Deploy
```bash
sam build                          # Build all functions
sam build --use-container          # Build in Docker (correct Python version)
sam validate --lint                # Validate template.yaml
sam deploy                         # Deploy using samconfig.toml
sam delete                         # Tear down the stack
```

### Testing
```bash
pytest                             # All tests
pytest tests/unit/ -x -v           # Unit tests, stop on first failure
pytest tests/integration/ -v       # Integration tests (requires deployed stack)
```

### Queue Operations
```bash
# Check queue depth
aws sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names ApproximateNumberOfMessages

# Send test message
aws sqs send-message --queue-url $QUEUE_URL --message-body '{"key": "value"}'

# Peek at DLQ (without consuming)
aws sqs receive-message --queue-url $DLQ_URL --max-number-of-messages 5 --visibility-timeout 0

# Purge DLQ (destructive)
aws sqs purge-queue --queue-url $DLQ_URL
```

### EventBridge Operations
```bash
# List rules
aws events list-rules --name-prefix $STACK_NAME

# Send test event
aws events put-events --entries '[{"Source":"com.acme.test","DetailType":"TestEvent","Detail":"{\"key\":\"value\"}"}]'
```

## Project Structure

```
.
├── template.yaml              # SAM template (SQS + EventBridge + Lambda + DynamoDB)
├── samconfig.toml             # Deploy configuration
├── src/
│   ├── handlers/              # Lambda handlers (one per event source)
│   │   ├── process_order.py   # SQS-triggered handler
│   │   ├── on_payment.py      # EventBridge-triggered handler
│   │   └── orchestrator.py    # Step Functions task handler
│   ├── models/                # @dataclass models with DynamoDB serialization
│   ├── services/              # Business logic (idempotent processing)
│   └── utils/                 # Logging, idempotency helpers, SQS batch utilities
├── tests/
│   ├── unit/                  # pytest + moto
│   ├── integration/           # Tests against deployed queues
│   └── conftest.py            # Fixtures: SQS queues, DynamoDB tables, event builders
├── events/                    # Sample SQS and EventBridge event payloads
├── state-machines/            # Step Functions ASL definitions (if used)
└── scripts/
    └── seed.sh                # Seed initial data
```

## SQS Handler Pattern

Handlers process batches of SQS messages. Use `ReportBatchItemFailures` to avoid reprocessing successful messages.

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel("INFO")

def lambda_handler(event, context):
    batch_item_failures = []
    for record in event["Records"]:
        try:
            body = json.loads(record["body"])
            logger.info("Processing message: %s", record["messageId"])
            process_message(body)
        except Exception:
            logger.exception("Failed to process message: %s", record["messageId"])
            batch_item_failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": batch_item_failures}
```

## EventBridge Handler Pattern

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel("INFO")

def lambda_handler(event, context):
    detail_type = event["detail-type"]
    source = event["source"]
    detail = event["detail"]
    logger.info("Received %s from %s", detail_type, source)
    try:
        process_event(detail_type, detail)
    except Exception:
        logger.exception("Failed to process event: %s", detail_type)
        raise  # Re-raise so EventBridge retries or routes to DLQ
```

## Idempotency

All async handlers must be idempotent. Use DynamoDB conditional writes:

```python
import time
from botocore.exceptions import ClientError

def ensure_idempotent(table, idempotency_key):
    """Returns True if this is a new message, False if duplicate."""
    try:
        table.put_item(
            Item={"pk": f"IDEMPOTENCY#{idempotency_key}", "ttl": int(time.time()) + 86400},
            ConditionExpression="attribute_not_exists(pk)",
        )
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return False
        raise
```

## SQS Queue Configuration Rules

- Every queue must have a dead-letter queue (DLQ) with `maxReceiveCount=3`.
- Visibility timeout >= 6x the Lambda function timeout.
- Enable `ReportBatchItemFailures` in SAM template:
  ```yaml
  Events:
    SQSEvent:
      Type: SQS
      Properties:
        Queue: !GetAtt MyQueue.Arn
        BatchSize: 10
        FunctionResponseTypes:
          - ReportBatchItemFailures
  ```

## EventBridge Rules

- Events must have a well-defined `source` (`com.acme.<service>`) and `detail-type`.
- Rules must filter on both `source` and `detail-type` at minimum. No catch-all rules.
- Failed deliveries routed to a DLQ.
- Document event schemas in `docs/events.md`.

## DynamoDB Patterns

- `ExpressionAttributeNames` with `#placeholder` for reserved words.
- Conditional writes for idempotency.
- Always paginate: loop until `LastEvaluatedKey` is absent.
- TTL: Unix epoch integer for automatic cleanup of idempotency records.
- DynamoDB Streams + Lambda for change data capture when needed.

## Concurrency and Throttling

- Set reserved concurrency per Lambda to protect downstream services.
- SQS batch size and concurrency must consider DynamoDB write capacity.
- Use `botocore.config.Config(max_pool_connections=25)` with ThreadPoolExecutor.

## Key Pitfalls

- SQS retry + Lambda timeout limits total processing time. With `maxReceiveCount=3` and 300s timeout, only ~900s before DLQ.
- Lambda must raise exceptions on failure so SQS retries. Never swallow errors in SQS handlers.
- `sam build` needs exact Python version. Use `--use-container` if mismatch.
- First deploy may fail (KMS race). Delete stack and redeploy.
- EventBridge has at-least-once delivery. Always implement idempotency.
<!-- claude-hub:fragment:end — Add your project-specific content below this line. -->

# Project Notes

<!-- Add project-specific guidance: event schemas, processing pipelines, retry strategies, monitoring. -->
