# DLQ Inspect

Inspects dead-letter queue messages to diagnose processing failures.

## Steps

1. **Find the DLQ URL**
   ```bash
   STACK_NAME=$(grep stack_name samconfig.toml | head -1 | awk -F'"' '{print $2}')
   DLQ_URL=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
     --query 'Stacks[0].Outputs[?OutputKey==`DlqUrl`].OutputValue' --output text)
   echo "DLQ URL: $DLQ_URL"
   ```

2. **Check message count**
   ```bash
   aws sqs get-queue-attributes --queue-url "$DLQ_URL" \
     --attribute-names ApproximateNumberOfMessages --output table
   ```

3. **Peek at messages** (without consuming them)
   ```bash
   aws sqs receive-message --queue-url "$DLQ_URL" \
     --max-number-of-messages 5 \
     --visibility-timeout 0 \
     --output json | python3 -m json.tool
   ```

4. **Analyze failures**
   For each message:
   - Parse the message body to identify the original event.
   - Check CloudWatch Logs for the corresponding Lambda invocation errors.
   - Determine if the failure is transient (retry-worthy) or permanent (bad data).

5. **Recommend action**
   - **Transient failures** (timeout, throttle, downstream unavailable): Re-drive messages back to the source queue.
   - **Permanent failures** (bad data, missing required fields): Log the messages and purge them.
   - **Code bugs**: Identify the fix, then re-drive after deploying the fix.

## Output

Report:
- Number of messages in the DLQ.
- Sample of message bodies and their error patterns.
- Recommended action (re-drive, purge, or fix-then-redrive).
