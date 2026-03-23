# Async Workflow Review

Reviews asynchronous processing patterns (SQS, EventBridge, Step Functions) against backend team standards for reliability and idempotency.

## Steps

1. **Identify async components**
   ```bash
   git diff --name-only main...HEAD -- 'src/**/*.py' 'template.yaml'
   ```
   Look for SQS queue definitions, EventBridge rules, Step Functions state machines, and Lambda functions triggered by non-API events.

2. **SQS queue configuration**
   - Every SQS queue must have a dead-letter queue (DLQ) with `maxReceiveCount=3`.
   - DLQ must have a CloudWatch alarm or monitoring for message count > 0.
   - Visibility timeout must be at least 6x the Lambda function timeout.
   - Message retention period set appropriately (default 4 days, max 14 days).
   - FIFO queues used only when strict ordering is required (they have lower throughput).

3. **Idempotency**
   - All async handlers must be idempotent -- processing the same message twice must produce the same result.
   - Idempotency keys stored in DynamoDB with TTL for automatic cleanup.
   - Check for idempotency key before processing:
     ```python
     try:
         table.put_item(
             Item={"pk": idempotency_key, "ttl": int(time.time()) + 86400},
             ConditionExpression="attribute_not_exists(pk)",
         )
     except ClientError as e:
         if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
             logger.info("Duplicate message, skipping: %s", idempotency_key)
             return
         raise
     ```

4. **EventBridge patterns**
   - Events published with a well-defined `source` (e.g., `com.acme.orders`) and `detail-type`.
   - Event schema documented in `docs/events.md`.
   - Rules use specific patterns, not catch-all. Filter on `source` and `detail-type` at minimum.
   - Failed event deliveries routed to a DLQ.

5. **Step Functions**
   - Use Step Functions for multi-step orchestration instead of chaining Lambdas.
   - Each state must have error handling with `Catch` and `Retry` blocks.
   - Use `ResultPath` to preserve original input alongside step output.
   - Timeouts set on every Task state.

6. **Error handling and retries**
   - Lambda functions processing SQS messages must raise exceptions on failure (not swallow them) so SQS can retry.
   - Partial batch failure handling enabled (`FunctionResponseTypes: [ReportBatchItemFailures]`) for SQS-triggered Lambdas.
   - Exponential backoff configured in Step Functions retry policies.

7. **Lambda concurrency**
   - Reserved concurrency set per function to prevent noisy-neighbor throttling.
   - Concurrency limit considers downstream service capacity (DynamoDB write throughput, external API rate limits).

## Output

Provide a summary organized by category:
- **Queue configuration**: Missing DLQs, incorrect visibility timeouts, or retention issues.
- **Idempotency**: Missing or incorrect deduplication logic.
- **Event patterns**: Poorly defined EventBridge rules or missing schemas.
- **Error handling**: Swallowed exceptions, missing retries, or incorrect batch failure handling.
- **Concurrency**: Missing or misconfigured concurrency limits.

For each finding, include the file path, line number, the issue, and the recommended fix.
