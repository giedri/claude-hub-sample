---
name: infra-review
description: |
  Review infrastructure-as-code changes (CloudFormation, SAM, CDK, Terraform)
  for security, cost, reliability, and best practices. Use when reviewing PRs
  that touch IaC templates or infrastructure configuration.
---

# Infrastructure Review

Reviews infrastructure-as-code changes for security risks, cost implications, reliability concerns, and adherence to platform team standards.

## Steps

1. **Identify IaC files in scope**
   Find changed infrastructure files:
   ```bash
   git diff --name-only main...HEAD | grep -E '\.(yaml|yml|json|tf|hcl)$'
   ```
   Focus on: CloudFormation/SAM templates, Terraform configs, CDK output, Dockerfiles, CI/CD pipeline definitions.

2. **Security review**
   - IAM policies: flag `*` wildcards in Action or Resource. Verify least-privilege.
   - No secrets, API keys, or passwords hardcoded in templates. Must use Secrets Manager or SSM Parameter Store.
   - Security groups: flag `0.0.0.0/0` ingress rules except on public ALBs (port 80/443 only).
   - Encryption: verify `EncryptionConfiguration` or `SSESpecification` on DynamoDB tables, S3 buckets, SQS queues, SNS topics.
   - Public access: flag any S3 bucket without `PublicAccessBlockConfiguration` set to block all.
   - Lambda: verify functions are in a VPC if they access internal resources. Check that `ReservedConcurrentExecutions` is set to prevent runaway scaling.

3. **Cost review**
   - DynamoDB: prefer `PAY_PER_REQUEST` billing for new tables unless traffic is predictable. Flag provisioned capacity without auto-scaling.
   - Lambda: check memory size is appropriate (not default 128MB for compute-heavy, not 3GB for simple handlers). Flag timeout > 60s for API-triggered functions.
   - NAT Gateway: flag new NAT Gateways (expensive). Suggest VPC endpoints for S3/DynamoDB access instead.
   - RDS: verify Multi-AZ is intentional (doubles cost). Check instance sizing is justified.
   - Flag any resource without a `DeletionPolicy` that should have one (databases, S3 buckets with data).

4. **Reliability review**
   - DLQ: every SQS queue and Lambda event source mapping should have a dead-letter queue configured.
   - Alarms: new resources should have corresponding CloudWatch alarms (error rate, throttling, latency).
   - Retry configuration: verify `maxReceiveCount` on SQS queues and retry settings on Step Functions.
   - Multi-AZ: databases and critical services should span availability zones.
   - Backup: verify `PointInTimeRecoverySpecification` is enabled on DynamoDB tables.

5. **Standards compliance**
   - Resource naming follows `{team}-{service}-{resource}` convention.
   - All resources tagged with: `Team`, `Service`, `Environment`, `CostCenter`.
   - Outputs export values needed by dependent stacks using `!Sub "${AWS::StackName}-{OutputName}"`.
   - Parameters have `Description`, `Type`, and `AllowedValues`/`AllowedPattern` where applicable.
   - Use shared infrastructure modules from `acme-ci-templates` where available.

6. **SAM/CloudFormation-specific checks**
   - No explicit `AWS::Serverless::Api` when implicit API suffices.
   - SSM parameter names scoped to stack: `!Sub "/${AWS::StackName}/..."`.
   - No `!Sub` in Parameter defaults (invalid at deploy time).
   - No circular references between API Gateway and Lambda environment variables.
   - Lambda layers use correct `BuildMethod` (avoids double-nesting `python/python/`).

## Output

Organize findings by severity:

- **Blockers**: Security vulnerabilities, data loss risks, or standards violations that must be fixed before merge.
- **Warnings**: Cost concerns, missing best practices, or reliability gaps that should be addressed.
- **Suggestions**: Improvements that would be nice to have but are not blocking.

For each finding, include the file path, line number or resource logical ID, the issue, and the recommended fix.
