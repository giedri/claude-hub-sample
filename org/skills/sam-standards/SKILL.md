# SAM Standards Review

Checks AWS SAM templates and deployment configuration against organizational standards.

## Steps

1. **Identify changed files**
   Determine the scope of SAM/CloudFormation changes:
   ```bash
   git diff --name-only main...HEAD -- 'template.yaml' 'template.yml' 'samconfig.toml'
   ```

2. **Validate the template**
   ```bash
   sam validate
   python3 -c "import yaml; yaml.safe_load(open('template.yaml'))"
   ```
   Check for duplicate YAML keys which are silently ignored by parsers.

3. **Naming and stack isolation**
   - All dynamic naming must use `AWS::StackName` -- pass it as a `STACK_NAME` environment variable to Lambda functions.
   - SSM parameter names must be scoped to the stack: `!Sub "/${AWS::StackName}/param-name"`.
   - Never hardcode a prefix like `/my-app/` -- use `!Sub` with `AWS::StackName`.
   - `!Sub` cannot be used as a CloudFormation Parameter default. Inline `!Sub` directly in Environment Variables and IAM Resource fields.

4. **API Gateway configuration**
   - Never define explicit `AWS::Serverless::Api` when the implicit API suffices.
   - Never reference `ServerlessRestApi` or `ServerlessHttpApi` in function environment variables -- this creates circular dependencies.
   - Use `HttpApi` event type for API Gateway v2, `Api` for v1. Do not mix them in the same function.
   - The implicit REST API stage name is `Prod` (capital P), not `prod`.
   - HTTP API v2 has a hard 30-second integration timeout. Use async patterns (SQS, EventBridge) for long-running operations.

5. **IAM policies**
   - Follow least-privilege: scope IAM policies to specific resources using `!Sub` with stack name.
   - Use SAM policy templates (e.g., `DynamoDBCrudPolicy`) where they fit. Fall back to explicit `Statement` blocks for complex permissions.
   - Never use `SSMParameterReadPolicy` with `/`-prefixed parameter names. Use a direct IAM Statement:
     ```yaml
     - Statement:
         - Effect: Allow
           Action: [ssm:GetParameter, ssm:GetParameters]
           Resource: !Sub "arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/${AWS::StackName}/*"
     ```
   - For Bedrock cross-region inference, use wildcard region in ARNs: `arn:aws:bedrock:*:${AWS::AccountId}:inference-profile/*`.

6. **Deployment configuration**
   - `samconfig.toml` must set `confirm_changeset = false` for non-production environments.
   - Use `--use-container` for `sam build` when the local Python version doesn't match the Lambda runtime.
   - If first deploy fails with `InvalidArnException` on a DynamoDB table (KMS/CreateGrant race), delete the stack and redeploy.

7. **Lambda layer configuration**
   - SAM `BuildMethod` adds a `python/` prefix -- source at `layers/my-layer/my_package/` deploys as `python/my_package/`. Do NOT nest source under `python/`.

## Output

Provide a summary organized by category:
- **Template validation**: YAML errors, duplicate keys, or SAM validation failures.
- **Naming/isolation**: Stack name scoping violations.
- **API Gateway**: Circular dependencies, mixed API types, or missing async patterns.
- **IAM**: Overly permissive policies or incorrect policy templates.
- **Deployment config**: `samconfig.toml` issues or build configuration problems.

For each finding, include the file path, line number, the issue, and the recommended fix.
