# SAM Deploy

Deploys the event processor service to AWS.

## Steps

1. **Validate the template**
   ```bash
   sam validate --lint
   python3 -c "import yaml; yaml.safe_load(open('template.yaml'))"
   ```

2. **Build**
   ```bash
   sam build
   ```
   If Python version mismatch: `sam build --use-container`

3. **Run tests**
   ```bash
   pytest tests/unit/ -x -q
   ```
   Do not deploy if tests fail.

4. **Deploy**
   ```bash
   sam deploy
   ```

5. **Verify queues and rules**
   ```bash
   STACK_NAME=$(grep stack_name samconfig.toml | head -1 | awk -F'"' '{print $2}')
   # Check SQS queues
   aws sqs list-queues --queue-name-prefix "$STACK_NAME" --output table
   # Check EventBridge rules
   aws events list-rules --name-prefix "$STACK_NAME" --output table
   ```

6. **Test with a sample message** (if applicable)
   ```bash
   QUEUE_URL=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
     --query 'Stacks[0].Outputs[?OutputKey==`QueueUrl`].OutputValue' --output text)
   aws sqs send-message --queue-url "$QUEUE_URL" --message-body '{"test": true}'
   ```

## Troubleshooting

- **Messages going to DLQ**: Check Lambda logs in CloudWatch. Verify handler raises exceptions on failure (not swallowing them).
- **SQS visibility timeout**: Must be at least 6x the Lambda timeout.
- **First deploy KMS failure**: `sam delete` then redeploy.
